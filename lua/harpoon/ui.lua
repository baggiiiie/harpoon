local Buffer = require("harpoon.buffer")
local Logger = require("harpoon.logger")
local Extensions = require("harpoon.extensions")

---@class HarpoonToggleOptions
---@field border? any this value is directly passed to nvim_open_win
---@field title_pos? any this value is directly passed to nvim_open_win
---@field title? string this value is directly passed to nvim_open_win
---@field ui_fallback_width? number used if we can't get the current window
---@field ui_width_ratio? number this is the ratio of the editor window to use
---@field ui_max_width? number this is the max width the window can be
---@field height_in_lines? number this is the max height in lines that the window can be

---@return HarpoonToggleOptions
local function toggle_config(config)
    return vim.tbl_extend("force", {
        ui_fallback_width = 69,
        ui_width_ratio = 0.62569,
    }, config or {})
end

---@class HarpoonUI
---@field win_id number
---@field bufnr number
---@field settings HarpoonSettings
---@field active_list HarpoonList
---@field width number
---@field height number
---@field auto_closed boolean
---@field restore_on_win_close boolean
---@field initial_win_config table
local HarpoonUI = {}

---@param list HarpoonList
---@return string
local function list_name(list)
    return list and list.name or "nil"
end

---@param settings HarpoonSettings
---@return string
local function get_effective_ui_style(settings)
    local ui_style = settings.ui_style or "auto"

    if ui_style == "auto" then
        local threshold = settings.ui_auto_threshold or 120
        local columns = vim.o.columns

        -- If window is wide enough, use sidebar, otherwise use popup
        if columns >= threshold then
            return "sidebar"
        else
            return "popup"
        end
    end

    return ui_style
end

HarpoonUI.__index = HarpoonUI

---@param settings HarpoonSettings
---@return HarpoonUI
function HarpoonUI:new(settings)
    return setmetatable({
        win_id = nil,
        bufnr = nil,
        active_list = nil,
        settings = settings,
        auto_closed = false,
        restore_on_win_close = false,
        initial_win_config = nil,
        width = nil,
        height = nil,
    }, self)
end

---@param auto_close? boolean
function HarpoonUI:close_menu(auto_close)
    if self.closing then
        return
    end

    self.closing = true

    -- Track if this was an auto-close
    if auto_close then
        self.auto_closed = true
        self.restore_on_win_close = true
    end

    Logger:log(
        "ui#close_menu name: ",
        list_name(self.active_list),
        "win and bufnr",
        {
            win = self.win_id,
            bufnr = self.bufnr,
            auto_close = auto_close,
        }
    )

    -- Remove window management autocommands
    pcall(vim.api.nvim_del_augroup_by_name, "HarpoonWindowManagement")

    if self.bufnr ~= nil and vim.api.nvim_buf_is_valid(self.bufnr) then
        -- vim.api.nvim_buf_call(self.bufnr, function()
        --     vim.cmd("w")
        -- end)
        vim.api.nvim_buf_delete(self.bufnr, { force = true })
    end

    if self.win_id ~= nil and vim.api.nvim_win_is_valid(self.win_id) then
        vim.api.nvim_win_close(self.win_id, true)
    end

    if not auto_close then
        self.active_list = nil
        self.auto_closed = false
        self.restore_on_win_close = false
    end

    self.win_id = nil
    self.bufnr = nil
    self.initial_win_config = nil

    self.closing = false
end

--- TODO: Toggle_opts should be where we get extra style and border options
--- and we should create a nice minimum window
---@param toggle_opts HarpoonToggleOptions
---@return number,number
function HarpoonUI:_create_window(toggle_opts)
    -- NOTE: setting second option to true makes it a scratch buffer
    -- so neovim won't prompt to save it
    local bufnr = vim.api.nvim_create_buf(false, true)
    self.bufnr = bufnr

    local win_id
    local ui_style = get_effective_ui_style(self.settings)

    if ui_style == "popup" then
        -- Original popup implementation
        local win = vim.api.nvim_list_uis()
        local width = toggle_opts.ui_fallback_width

        if #win > 0 then
            width = math.floor(win[1].width * toggle_opts.ui_width_ratio)
        end

        if toggle_opts.ui_max_width and width > toggle_opts.ui_max_width then
            width = toggle_opts.ui_max_width
        end

        local height = toggle_opts.height_in_lines or 8

        -- Store initial dimensions
        self.width = width
        self.height = height

        local win_config = {
            relative = "editor",
            title = toggle_opts.title or "Harpoon",
            title_pos = toggle_opts.title_pos or "left",
            row = math.floor(((vim.o.lines - height) / 2) - 1),
            col = math.floor((vim.o.columns - width) / 2),
            width = width,
            height = height,
            style = "minimal",
            border = toggle_opts.border or "single",
        }

        win_id = vim.api.nvim_open_win(bufnr, true, win_config)

        -- Store the initial window configuration
        self.initial_win_config = win_config

        vim.api.nvim_set_option_value("number", true, {
            win = win_id,
        })
    else
        -- New sidebar implementation
        local width = math.min(math.floor(vim.o.columns * 0.2), 50)
        width = math.max(width, 20)
        self.width = width

        win_id = vim.api.nvim_open_win(bufnr, true, {
            split = "left",
            win = -1,
            width = width,
            style = "minimal",
        })

        vim.api.nvim_set_option_value("number", true, {
            win = win_id,
        })
    end

    if win_id == 0 then
        Logger:log(
            "ui#_create_window failed to create window, win_id returned 0"
        )
        self:close_menu()
        error("Failed to create window")
    end

    Buffer.setup_autocmds_and_keymaps(bufnr, ui_style)

    self.win_id = win_id

    -- Setup window management autocommands to handle editor window changes
    self:_setup_window_management()

    return win_id, bufnr
end

--- Helper function to count non-harpoon editor windows
---@return number
function HarpoonUI:_count_editor_windows()
    local count = 0
    local wins = vim.api.nvim_list_wins()

    for _, win in ipairs(wins) do
        if vim.api.nvim_win_is_valid(win) then
            local buf = vim.api.nvim_win_get_buf(win)
            local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
            local filetype = vim.api.nvim_get_option_value("filetype", { buf = buf })

            -- Count only regular editor windows (not harpoon, not special buffers)
            if buftype == "" and filetype ~= "harpoon" and win ~= self.win_id then
                count = count + 1
            end
        end
    end

    return count
end

--- Setup autocommands for window management
function HarpoonUI:_setup_window_management()
    local ui_style = get_effective_ui_style(self.settings)

    -- Create autocommand group for window management
    local group = vim.api.nvim_create_augroup("HarpoonWindowManagement", { clear = true })

    -- Prevent window resize
    vim.api.nvim_create_autocmd({ "WinResized", "VimResized" }, {
        group = group,
        callback = function()
            if not self.win_id or not vim.api.nvim_win_is_valid(self.win_id) then
                return
            end

            if ui_style == "popup" and self.initial_win_config then
                -- Restore original size and position for popup
                pcall(vim.api.nvim_win_set_config, self.win_id, {
                    relative = "editor",
                    row = math.floor(((vim.o.lines - self.height) / 2) - 1),
                    col = math.floor((vim.o.columns - self.width) / 2),
                    width = self.width,
                    height = self.height,
                })
            else
                -- Restore original width for sidebar
                pcall(vim.api.nvim_win_set_width, self.win_id, self.width)
            end
        end,
    })

    -- Prevent WinScrolled from changing window size
    vim.api.nvim_create_autocmd({ "WinScrolled" }, {
        group = group,
        callback = function()
            if not self.win_id or not vim.api.nvim_win_is_valid(self.win_id) then
                return
            end

            -- Ensure width doesn't change
            local current_width = vim.api.nvim_win_get_width(self.win_id)
            if current_width ~= self.width then
                pcall(vim.api.nvim_win_set_width, self.win_id, self.width)
            end

            -- For popup, also ensure height doesn't change
            if ui_style == "popup" then
                local current_height = vim.api.nvim_win_get_height(self.win_id)
                if current_height ~= self.height then
                    pcall(vim.api.nvim_win_set_height, self.win_id, self.height)
                end
            end
        end,
    })

    -- Lock window options to prevent accidental resizing
    if self.win_id and vim.api.nvim_win_is_valid(self.win_id) then
        pcall(vim.api.nvim_set_option_value, "winfixwidth", true, { win = self.win_id })
        if ui_style == "popup" then
            pcall(vim.api.nvim_set_option_value, "winfixheight", true, { win = self.win_id })
        end
    end

    -- Auto-close/reopen on window open/close
    vim.api.nvim_create_autocmd({ "WinNew", "WinClosed" }, {
        group = group,
        callback = function(ev)
            if not self.win_id or not vim.api.nvim_win_is_valid(self.win_id) then
                return
            end

            -- Defer to allow window state to stabilize
            vim.schedule(function()
                local editor_count = self:_count_editor_windows()

                Logger:log(
                    "ui#window_management event:",
                    ev.event,
                    "editor_windows:",
                    editor_count,
                    "auto_closed:",
                    self.auto_closed
                )

                if ev.event == "WinNew" then
                    -- Another window opened - auto-close harpoon if not already auto-closed
                    if editor_count > 0 and not self.auto_closed then
                        self:close_menu(true)
                    end
                elseif ev.event == "WinClosed" then
                    -- Window closed - reopen harpoon if it was auto-closed
                    if editor_count == 0 and self.restore_on_win_close and self.active_list then
                        -- Reset flags first
                        self.auto_closed = false
                        self.restore_on_win_close = false

                        -- Reopen the menu
                        local opts = toggle_config()
                        local win_id, bufnr = self:_create_window(opts)

                        self.win_id = win_id
                        self.bufnr = bufnr

                        local contents = self.active_list:display()
                        vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, contents)

                        Extensions.extensions:emit(Extensions.event_names.UI_CREATE, {
                            win_id = win_id,
                            bufnr = bufnr,
                            current_file = vim.api.nvim_buf_get_name(0),
                            contents = contents,
                        })
                    end
                end
            end)
        end,
    })
end

---@param list? HarpoonList
---TODO: @param opts? HarpoonToggleOptions
function HarpoonUI:toggle_quick_menu(list, opts)
    opts = toggle_config(opts)
    if list == nil or self.win_id ~= nil then
        Logger:log("ui#toggle_quick_menu#closing", list and list.name)
        if self.settings.save_on_toggle then
            self:save()
        end
        self:close_menu()
        return
    end

    -- grab the current file before opening the quick menu
    local current_file = vim.api.nvim_buf_get_name(0)

    Logger:log("ui#toggle_quick_menu#opening", list and list.name)
    local win_id, bufnr = self:_create_window(opts)

    self.win_id = win_id
    self.bufnr = bufnr
    self.active_list = list

    local contents = self.active_list:display()

    vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, contents)

    Extensions.extensions:emit(Extensions.event_names.UI_CREATE, {
        win_id = win_id,
        bufnr = bufnr,
        current_file = current_file,
        contents = contents,
    })
end

function HarpoonUI:_get_processed_ui_contents()
    local list = Buffer.get_contents(self.bufnr)
    local length = #list
    return list, length
end

---@param options? any
function HarpoonUI:select_menu_item(options)
    local idx = vim.fn.line(".")

    -- must first save any updates potentially made to the list before
    -- navigating
    local list, length = self:_get_processed_ui_contents()
    self.active_list:resolve_displayed(list, length)

    Logger:log(
        "ui#select_menu_item selecting item",
        idx,
        "from",
        list,
        "options",
        options
    )

    list = self.active_list
    local ui_style = get_effective_ui_style(self.settings)

    if ui_style == "popup" then
        self:close_menu()
    else
        vim.cmd("wincmd p")
    end

    list:select(idx, options)
end

function HarpoonUI:save()
    local list, length = self:_get_processed_ui_contents()

    Logger:log("ui#save", list)
    self.active_list:resolve_displayed(list, length)
    if self.settings.sync_on_ui_close then
        require("harpoon"):sync()
    end
end

---@param settings HarpoonSettings
function HarpoonUI:configure(settings)
    self.settings = settings
end

---@param contents string[]
function HarpoonUI:refresh(contents)
    if self.bufnr == nil or not vim.api.nvim_buf_is_valid(self.bufnr) then
        return
    end
    vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, true, contents)
end

-- ---@param contents string[]
-- ---@return string[]
-- function HarpoonUI:truncate_content(contents)
--     -- TODO: when selecting from Harpoon menu, it reads the line in the buffer
--     -- if we wanna show truncated lines, we need to separate display from actual
--     -- see HarpoonUI:select_menu_item
--     local function truncate_left(str, width)
--         if string.len(str) <= width then
--             return str
--         end
--         -- Use a single-character ellipsis to indicate truncation.
--         local ellipsis = ".."
--         local tail = str:sub(-(width - 20))
--         return ellipsis .. tail
--     end
--
--     local win_width = require("harpoon").ui.width
--     local adjusted = {}
--     for i = 1, #contents do
--         adjusted[i] = truncate_left(contents[i], win_width)
--     end
--     return adjusted
-- end
--
return HarpoonUI
