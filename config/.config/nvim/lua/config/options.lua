-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.api.nvim_create_user_command("CommandShiftF", function()
  require("conform").format({ async = true, lsp_format = "fallback" })
end, { range = true })
vim.api.nvim_create_user_command("CommandP", "Telescope find_files", {})
