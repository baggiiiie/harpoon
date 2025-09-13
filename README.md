<div align="center">

# Harpoon

##### Getting you where you want with the fewest keystrokes

[![Lua](https://img.shields.io/badge/Lua-blue.svg?style=for-the-badge&logo=lua)](http://www.lua.org)
[![Neovim](https://img.shields.io/badge/Neovim%200.8+-green.svg?style=for-the-badge&logo=neovim)](https://neovim.io)

</div>

## ⇁ TOC

- [The Problems](#-the-problems)
- [The Solutions](#-the-solutions)
- [Installation](#-installation)
- [Getting Started](#-getting-started)
- [API](#-api)
  - [Config](#config)
  - [Settings](#settings)
- [Contribution](#-contribution)
- [Social](#-social)
- [Note to legacy Harpoon 1 users](#-note-to-legacy-harpoon-1-users)

## ⇁ The Problems

1. You're working on a codebase. medium, large, tiny, whatever. You find
   yourself frequenting a small set of files and you are tired of using a fuzzy finder,
   `:bnext` & `:bprev` are getting too repetitive, alternate file doesn't quite cut it, etc etc.
1. You want to execute some project specific commands, have any number of
   persistent terminals that can be easily navigated to, send commands to other
   tmux windows, or dream up your own custom action and execute with a single key
1. With [ThePrimeagen/harpoon](https://github.com/ThePrimeagen/harpoon), you
   open a popup menu, select the file you want, and boom you're there. But what
   if you want to keep the popup menu for reference?
1. At the same time, you want no more neck pain from looking at your screen at
   a 45 degree angle to write codes for hours.

## ⇁ The Solutions

1. Specify either by altering a ui or by adding via hot key files
1. Unlimited lists and items within the lists
1. With inspiration from [shortcuts/no-neck-pain.nvim: ☕ Dead simple yet super
   extensible zen mode plugin to protect your
   neck.](https://github.com/shortcuts/no-neck-pain.nvim), Harpoon popup menu is
   shifted to the left side of the screen, so your Harpoon menu acts as a padding
   window that persists on the screen and shift your main screen to the center.

## ⇁ Installation

- neovim 0.8.0+ required
- install using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "baggiiiie/harpoon",
    branch = "my-harpoon",
    dependencies = { "nvim-lua/plenary.nvim" }
}
```

## ⇁ Getting Started

### Basic Setup

Here is my basic setup

```lua
local harpoon = require("harpoon")
harpoon:setup()
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

### Notes

- In a harpoon menu
  - `q` to close the menu
  - `<esc>` to return to the previous window

### Others

Regarding other configs, see [ThePrimeagen/harpoon](https://github.com/ThePrimeagen/harpoon)
