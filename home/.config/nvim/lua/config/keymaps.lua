-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- ⌘S で保存 (docs/keymap.md A12)。端末が kitty keyboard protocol で <D-s> として
-- 渡してくるのを受ける。端末側で ESC:w⏎ を打ち込む方式 (旧 ghostty) は、Rex では
-- 前面が vim かを判定できず (bash -c 経由だと親プロセス名が返る) 使わない。
-- 形は LazyVim の <C-s> に揃える。
vim.keymap.set({ "i", "x", "n", "s" }, "<D-s>", "<cmd>w<cr><esc>", { desc = "Save File" })

-- move for dvorak
vim.keymap.set("n", "d", "h", { noremap = true })
vim.keymap.set("v", "d", "h", { noremap = true })
vim.keymap.set("n", "h", "gj", { noremap = true })
vim.keymap.set("v", "h", "gj", { noremap = true })
vim.keymap.set("n", "t", "gk", { noremap = true })
vim.keymap.set("v", "t", "gk", { noremap = true })
vim.keymap.set("n", "n", "l", { noremap = true })
vim.keymap.set("v", "n", "l", { noremap = true })
vim.keymap.set("n", "<Space>d", "^", { noremap = true })
vim.keymap.set("v", "<Space>d", "^", { noremap = true })
vim.keymap.set("n", "<Space>h", "G", { noremap = true })
vim.keymap.set("v", "<Space>h", "G", { noremap = true })
vim.keymap.set("n", "<Space>t", "gg", { noremap = true })
vim.keymap.set("v", "<Space>t", "gg", { noremap = true })
vim.keymap.set("n", "<Space>n", "$", { noremap = true })
vim.keymap.set("v", "<Space>n", "$", { noremap = true })
vim.keymap.set("n", "j", "d", { noremap = true })
vim.keymap.set("o", "j", "d", { noremap = true })
vim.keymap.set("v", "j", "d", { noremap = true })
vim.keymap.set("n", "k", "t", { noremap = true })
vim.keymap.set("v", "k", "t", { noremap = true })
vim.keymap.set("n", "l", "n", { noremap = true })
vim.keymap.set("v", "l", "n", { noremap = true })
vim.keymap.set("n", "L", "N", { noremap = true })
vim.keymap.set("v", "L", "N", { noremap = true })
vim.keymap.set("n", "D", ",", { noremap = true })
vim.keymap.set("v", "D", ",", { noremap = true })
vim.keymap.set("n", "H", "J", { noremap = true })
vim.keymap.set("v", "H", "J", { noremap = true })

-- allow remap to use lsp-hover with conventional configuration
vim.keymap.set("n", "T", "K", { remap = true })
vim.keymap.set("n", "N", ";", { noremap = true })
vim.keymap.set("v", "D", ",", { noremap = true })
vim.keymap.set("v", "H", "J", { noremap = true })

-- allow remap to use lsp-hover with conventional configuration
vim.keymap.set("v", "T", "K", { remap = true })
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

-- emacs keybind in command mode
vim.keymap.set("c", "<C-a>", "<Home>", { noremap = true })
vim.keymap.set("c", "<C-e>", "<End>", { noremap = true })
vim.keymap.set("i", "<C-a>", "<Home>", { noremap = true })
vim.keymap.set("i", "<C-e>", "<End>", { noremap = true })

-- https://superuser.com/questions/846854/in-vim-how-do-you-delete-to-end-of-line-while-in-command-mode
vim.keymap.set("c", "<C-k>", "<C-\\>estrpart(getcmdline(),0,getcmdpos()-1)<CR>", { noremap = true })
-- imap <C-k> <C-r>=<SID>kill()<CR>

-- Command-F に相当する操作を find にする
vim.keymap.set("n", "<C-f>", "/", { noremap = true })
