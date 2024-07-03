-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- move for dvorak
vim.keymap.set("n", "d", "h")
vim.keymap.set("n", "h", "gj")
vim.keymap.set("n", "t", "gk")
vim.keymap.set("n", "n", "l")
vim.keymap.set("n", "<Space>d", "^")
vim.keymap.set("n", "<Space>h", "G")
vim.keymap.set("n", "<Space>t", "gg")
vim.keymap.set("n", "<Space>n", "$")
vim.keymap.set("n", "j", "d")
vim.keymap.set("n", "k", "t")
vim.keymap.set("n", "l", "n")
vim.keymap.set("n", "L", "N")
vim.keymap.set("n", "D", ",")
vim.keymap.set("n", "H", "J")

-- allow remap to use lsp-hover with conventional configuration
vim.keymap.set("n", "T", "K")
vim.keymap.set("n", "N", ";")
vim.keymap.set("v", "D", ",")
vim.keymap.set("v", "H", "J")

-- allow remap to use lsp-hover with conventional configuration
vim.keymap.set("v", "T", "K")
vim.keymap.set("v", "N", ";")
vim.keymap.set("n", "<Esc><Esc>", ":nohlsearch<CR>")
vim.keymap.set("c", "<Esc><Esc>", ":nohlsearch<CR>")
vim.keymap.set("n", "zh", "<C-w>j")
vim.keymap.set("n", "zt", "<C-w>k")
vim.keymap.set("n", "zn", "<C-w>l")
vim.keymap.set("n", "zd", "<C-w>h")
vim.keymap.set("n", "ZH", "<C-w>J")
vim.keymap.set("n", "ZT", "<C-w>K")
vim.keymap.set("n", "ZN", "<C-w>L")
vim.keymap.set("n", "ZD", "<C-w>H")
vim.keymap.set("n", "zs", ":sp<CR>")
vim.keymap.set("n", "zv", ":vs<CR>")
