if &compatible
  set nocompatible               " Be iMproved
endif

let s:cache_home = empty($XDG_CACHE_HOME) ? expand('~/.cache') : $XDG_CACHE_HOME
let s:dein_dir = s:cache_home . '/dein'
let s:dein_repo_dir = s:dein_dir . '/repos/github.com/Shougo/dein.vim'
if !isdirectory(s:dein_repo_dir)
  call system('git clone https://github.com/Shougo/dein.vim ' . shellescape(s:dein_repo_dir))
endif

let &runtimepath = s:dein_repo_dir .",". &runtimepath

if dein#load_state(s:dein_dir)
  call dein#begin(s:dein_dir)
  call dein#add(s:dein_repo_dir)
  call dein#load_toml(expand('$HOME') . '/.dein.toml', {'lazy': 0})
  call dein#load_toml(expand('$HOME') . '/.dein.lazy.toml', {'lazy': 1})

  call dein#end()
  call dein#save_state()
endif

syntax enable
" If you want to install not installed plugins on startup.
if dein#check_install()
  call dein#install()
endif

colorscheme molokai
set clipboard=unnamed
set encoding=utf-8
set nocompatible
set fileencodings=utf-8,ucs-bom,iso-2022-jp-3,iso-2022-jp,eucjp-ms,euc-jisx0213,euc-jp,sjis,cp932,utf-8

filetype off "TODO
filetype plugin on
filetype indent on
nohlsearch
syntax on

set number
set incsearch
set hlsearch
set wrap
" set showmatch
set whichwrap=b,s,h,l "move to the p/n line with l/r keys"
" set wrapscan  "move to the p/n spelling mistake"
set ignorecase
set smartcase
set hidden "TODO"
set history=5000
set autoindent
set tabstop=2 shiftwidth=2 softtabstop=2 expandtab"タブ幅の設定です
set helplang=en
set laststatus=2
" set cursorline
" set cursorcolumn
set splitright
set vb
set timeoutlen=200 ttimeoutlen=0
set mouse=a
set ambiwidth=double
let g:go_fmt_command = "goimports"
let g:deoplete#enable_at_startup = 1
let g:go_auto_sameids = 1
set completeopt-=preview

" For Japanese input https://hori-ryota.com/blog/neovim-fix-input-broken-ttimeout/
set ttimeout
set ttimeoutlen=20

source ~/.dotfiles/move.vimrc
source ~/.dotfiles/quickrun.vimrc
source ~/.dotfiles/lightline.vimrc
source ~/.dotfiles/latex.vimrc
source ~/.dotfiles/neomake.vimrc
source ~/.dotfiles/vim-plugin-viewdoc.vimrc
