-- TODO: Remove these lines after migrating everything to lua
vim.cmd('source ~/.config/nvim/_init.vim')
vim.cmd('source ~/.vim/rc/move.vimrc')
vim.cmd('source ~/.vim/rc/lsp.vim')

vim.api.nvim_set_keymap('n', ';r', ':<C-u>QuickRun<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', ';v', ':<C-u>OpenGithubFile<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('v', ';v', ":<C-u>'<,'>OpenGithubFile<CR>", { noremap = true, silent = true })

local custom = {
  -- basic
  number = true,
  swapfile = false,
  clipboard = 'unnamed',

  -- tabs
  tabstop = 2,
  shiftwidth = 2,
  softtabstop = 2,
  expandtab = true,

  -- search
  ignorecase = true,
  smartcase = true,
}

for k,v in pairs(custom) do vim.opt[k] = v end

vim.cmd [[
try
  colorscheme molokai
catch /^Vim\%((\a\+)\)\=:E185/
  colorscheme default
  set background=dark
endtry
]]

require('plugins')
