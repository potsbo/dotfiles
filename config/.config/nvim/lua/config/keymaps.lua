-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- allow remap to use lsp-hover with conventional configuration
vim.keymap.set("n", "T", "K", { remap = true })

vim.keymap.set("n", "<Esc><Esc>", ":nohlsearch<CR>", { noremap = true })
vim.keymap.set("c", "<Esc><Esc>", ":nohlsearch<CR>", { noremap = true })

-- emacs keybind in command mode
vim.keymap.set("c", "<C-a>", "<Home>", { noremap = true })
vim.keymap.set("c", "<C-e>", "<End>", { noremap = true })
vim.keymap.set("i", "<C-a>", "<Home>", { noremap = true })
vim.keymap.set("i", "<C-e>", "<End>", { noremap = true })

-- https://superuser.com/questions/846854/in-vim-how-do-you-delete-to-end-of-line-while-in-command-mode
vim.keymap.set("c", "<C-k>", "<C-\\>estrpart(getcmdline(),0,getcmdpos()-1)<CR>", { noremap = true })
