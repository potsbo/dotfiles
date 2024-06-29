-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.cmd("source ~/.vim/rc/move.vimrc")

vim.api.nvim_create_user_command("CommandP", "Telescope find_files", {})
