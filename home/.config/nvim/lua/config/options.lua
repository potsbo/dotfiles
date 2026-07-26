-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Cursor 的な体験を再現するための設定:
--   1. インライン ghost text が表示され、Tab で accept できる (Cursor の inline completion)
--   2. sidekick.nvim (lazyvim.plugins.extras.ai.sidekick) で、編集後に Tab で次の修正箇所へジャンプできる (Cursor の Next Edit Suggestions)
--
-- ai_cmp = false にすると copilot.lua のインライン suggestion が有効になり、
-- blink-copilot (ポップアップ補完) が無効になる。
-- folke は本来 lazyvim.plugins.extras.ai.copilot-native (Neovim 0.12+) でこの体験を提供する予定。
-- Neovim 0.12 がリリースされたら copilot → copilot-native に切り替え、この行を削除すること。
vim.g.ai_cmp = false

vim.api.nvim_create_user_command("CommandShiftF", function()
  require("conform").format({ async = true, lsp_format = "fallback" })
end, { range = true })
vim.api.nvim_create_user_command("CommandP", "Telescope find_files", {})
-- OSC 52 の copy(書き込み)は端末に一方的に送るだけなので動くが、
-- paste(読み出し)は端末にクリップボード内容を問い合わせて応答を待つ。
-- herdr など多くのターミナル/マルチプレクサは OSC 52 の読み出し応答に
-- 対応しておらず、`unnamedplus` 経由の p が
--   "Waiting for OSC 52 response from the terminal..."
-- で固まる。そこで paste は端末に問い合わせず nvim 内部レジスタから返す。
-- (yank 内容は nvim 内で保持されるので nvim 内コピペは問題なし。
--  外部からの貼り付けはターミナル自身の Cmd+V を使う。)
local function paste_from_register()
  return {
    vim.fn.split(vim.fn.getreg(""), "\n"),
    vim.fn.getregtype(""),
  }
end
vim.g.clipboard = {
  name = "OSC52",
  copy = {
    ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
    ["*"] = require("vim.ui.clipboard.osc52").copy("+"),
  },
  paste = {
    ["+"] = paste_from_register,
    ["*"] = paste_from_register,
  },
}

vim.opt.clipboard = "unnamedplus"

-- ステータスライン（一番下の行）を完全に非表示にする
vim.opt.showmode = false
vim.opt.laststatus = 0

-- コマンドラインの高さを0にする（noice.nvim がフローティングで表示する）
vim.opt.cmdheight = 0


-- winbar（ウィンドウ上部のファイル名表示）を非表示にする
vim.opt.winbar = ""

-- tabline（上部のバッファ/タブリスト）を非表示にする
vim.opt.showtabline = 0

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
