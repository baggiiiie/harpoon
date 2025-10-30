<div align="center">

# Harpoon

##### Getting you where you want with the fewest keystrokes

[![Lua](https://img.shields.io/badge/Lua-blue.svg?style=for-the-badge&logo=lua)](http://www.lua.org)
[![Neovim](https://img.shields.io/badge/Neovim%200.8+-green.svg?style=for-the-badge&logo=neovim)](https://neovim.io)

</div>

## `no-neck-harpoon` IS NOT DEAD! IT'S IN DEVELOPMENT AND BEING ACTIVELY MAINTAINED

## PRs ARE WELCOME

## ⇁ TOC

- [The Problems](#-the-problems)
- [The Solutions](#-the-solutions)
- [Installation](#-installation)
- [Getting Started](#-getting-started)
  - [Basic Setup](#basic-setup)
  - [Notes](#notes)
- [Others](#others)

## ⇁ The Problems

### ThePrimeagen's pitch

1. You're working on a codebase. Medium, large, tiny, whatever. You find
   yourself frequenting a small set of files and you are tired of using a fuzzy
   finder, `:bnext` & `:bprev` are getting too repetitive, alternate file doesn't
   quite cut it, etc etc.
1. You want to execute some project specific commands, have any number of
   persistent terminals that can be easily navigated to, send commands to other
   tmux windows, or dream up your own custom action and execute with a single
   key

### My Pitch

1. With [ThePrimeagen/harpoon](https://github.com/ThePrimeagen/harpoon), you
   open a popup menu, select the file you want, and boom you're there. **But what
   if you want to persistent the menu on screen because you can't remember
   which file is at which harpoon index?**
1. At the same time, you want no more neck pain from looking at your screen at
   a 45 degree angle to write codes for hours. So you have yet another plugin
   to solve this issue.

## ⇁ The BIGGER Problems

- You LOVE harpoon as a user, and you daily wish some features were added to it.
- You LOVE harpoon as a dev and you love contributing to open source, but your
  pull requests could not be merged but ThePrimeagen has not updated anything for
  harpoon for months. committed to his project for months.
- You LOVE harpoon, you simply wish it wasn't DEAD.

## ⇁ The Solutions

1. With inspiration from [shortcuts/no-neck-pain.nvim: ☕ Dead simple yet super
   extensible zen mode plugin to protect your
   neck.](https://github.com/shortcuts/no-neck-pain.nvim) (hence the branch name),
   Harpoon menu has a sidebar mode, which acts as a padding window that persists
   on the screen and shift your main screen to the center and save your neck.
1. For smaller screens/windows (you define what is "small"), Harpoon will
   fallback to the original popup implementation to ensure usability.
1. **To tackle the original harpoon being dead, we fork it!**

## ⇁ Installation

- neovim 0.8.0+ required
- install using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "baggiiiie/harpoon",
    branch = "no-neck-harpoon",
    dependencies = { "nvim-lua/plenary.nvim" }
}
```

## ⇁ Getting Started

### Setup and Configs

Here is my basic setup

```lua
local harpoon = require("harpoon")
harpoon:setup({
    settings = {
        ui_style = "auto", -- "auto" (default), "sidebar", or "popup"
        ui_auto_threshold = 120, -- minimum window width for sidebar in auto mode (default: 120)
    }
})
-- REQUIRED

vim.keymap.set("n", "<leader>H", function()
    harpoon.ui:toggle_quick_menu(harpoon:list())
end, { desc = "Open harpoon menu" })
vim.keymap.set("n", "<leader>ha", function()
    harpoon:list():add()
end, { desc = "Add current buffer to harpoon" })

vim.keymap.set("n", "<leader>hd", function()
    harpoon:list():remove()
end, { desc = "Remove current buffer from harpoon" })
-- Toggle previous & next buffers stored within Harpoon list
vim.keymap.set("n", "<C-P>", function() harpoon:list():prev() end)
vim.keymap.set("n", "<C-N>", function() harpoon:list():next() end)
```

For `ui_style`:

- `"auto"` (default): Automatically detects window size and uses sidebar for
  wide windows (≥120 columns) or popup for narrow windows
- `"sidebar"`: Always shows harpoon menu as a persistent left-side buffer that
  acts as padding and centers your main screen
- `"popup"`: Always shows original popup window that appears in the center and
  closes when you select a file

### Notes

- In a harpoon menu
  - `q` to close the menu
  - `<esc>` to return to the previous window

## Others

- Regarding other configs, see [ThePrimeagen/harpoon](https://github.com/ThePrimeagen/harpoon)
- The repo has broken unit tests, to be fixed..
- More features to come
  - e.g., truncate long file names in the harpoon menu (sidebar mode), so filenames won't be multilines etc.
