-- TODO: Remove this line after migrating everything to lua
vim.cmd('source ~/.config/nvim/_init.vim')

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
