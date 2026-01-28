-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Use copilot.lua inline ghost text instead of blink-copilot popup
vim.g.ai_cmp = false
vim.api.nvim_create_user_command("CommandShiftF", function()
  require("conform").format({ async = true, lsp_format = "fallback" })
end, { range = true })
vim.api.nvim_create_user_command("CommandP", "Telescope find_files", {})

-- https://stackoverflow.com/questions/75548458/copy-into-system-clipboard-from-neovim
if vim.fn.has("wsl") == 1 then
  if vim.fn.executable("wl-copy") == 0 then
    print("wl-clipboard not found, clipboard integration won't work")
  else
    vim.g.clipboard = {
      name = "wl-clipboard (wsl)",
      copy = {
        ["+"] = "wl-copy --foreground --type text/plain",
        ["*"] = "wl-copy --foreground --primary --type text/plain",
      },
      paste = {
        ["+"] = function()
          return vim.fn.systemlist('wl-paste --no-newline|sed -e "s/\r$//"', { "" }, 1) -- '1' keeps empty lines
        end,
        ["*"] = function()
          return vim.fn.systemlist('wl-paste --primary --no-newline|sed -e "s/\r$//"', { "" }, 1)
        end,
      },
      cache_enabled = true,
    }
  end
end
