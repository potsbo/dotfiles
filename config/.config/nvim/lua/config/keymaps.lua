-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- move for dvorak
vim.keymap.set("n", "d", "h", { noremap = true })
vim.keymap.set("n", "h", "gj", { noremap = true })
vim.keymap.set("n", "t", "gk", { noremap = true })
vim.keymap.set("n", "n", "l", { noremap = true })
vim.keymap.set("n", "<Space>d", "^", { noremap = true })
vim.keymap.set("n", "<Space>h", "G", { noremap = true })
vim.keymap.set("n", "<Space>t", "gg", { noremap = true })
vim.keymap.set("n", "<Space>n", "$", { noremap = true })
vim.keymap.set("n", "j", "d", { noremap = true })
vim.keymap.set("n", "k", "t", { noremap = true })
vim.keymap.set("n", "l", "n", { noremap = true })
vim.keymap.set("n", "L", "N", { noremap = true })
vim.keymap.set("n", "D", ",", { noremap = true })
vim.keymap.set("n", "H", "J", { noremap = true })

-- allow remap to use lsp-hover with conventional configuration
vim.keymap.set("n", "T", "K", { noremap = true })
vim.keymap.set("n", "N", ";", { noremap = true })
vim.keymap.set("v", "D", ",", { noremap = true })
vim.keymap.set("v", "H", "J", { noremap = true })

-- allow remap to use lsp-hover with conventional configuration
vim.keymap.set("v", "T", "K", { noremap = true })
vim.keymap.set("v", "N", ";", { noremap = true })
vim.keymap.set("n", "<Esc><Esc>", ":nohlsearch<CR>", { noremap = true })
vim.keymap.set("c", "<Esc><Esc>", ":nohlsearch<CR>", { noremap = true })
vim.keymap.set("n", "zh", "<C-w>j", { noremap = true })
vim.keymap.set("n", "zt", "<C-w>k", { noremap = true })
vim.keymap.set("n", "zn", "<C-w>l", { noremap = true })
vim.keymap.set("n", "zd", "<C-w>h", { noremap = true })
vim.keymap.set("n", "ZH", "<C-w>J", { noremap = true })
vim.keymap.set("n", "ZT", "<C-w>K", { noremap = true })
vim.keymap.set("n", "ZN", "<C-w>L", { noremap = true })
vim.keymap.set("n", "ZD", "<C-w>H", { noremap = true })
vim.keymap.set("n", "zs", ":sp<CR>", { noremap = true })
vim.keymap.set("n", "zv", ":vs<CR>", { noremap = true })
