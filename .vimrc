"
" .vimrc of potsbo
"

set encoding=utf-8
set nocompatible
set fileencodings=utf-8,ucs-bom,iso-2022-jp-3,iso-2022-jp,eucjp-ms,euc-jisx0213,euc-jp,sjis,cp932,utf-8

filetype off "TODO
filetype plugin on
filetype indent on
nohlsearch
syntax on

set number 		"line number"
set incsearch 	"incremental search
set hlsearch 	"highlightsearch"
set wrap 		"all letters insite"
" set showmatch
set whichwrap=b,s,h,l "move to the p/n line with l/r keys"
" set wrapscan  "move to the p/n spelling mistake"
set ignorecase
set smartcase
set hidden "TODO"
set history=5000
set autoindent
setlocal tabstop=2 shiftwidth=2 softtabstop=2 expandtab"タブ幅の設定です
set helplang=en
set laststatus=2
" set cursorline
" set cursorcolumn
set splitright
set vb
set timeoutlen=200 ttimeoutlen=0
set mouse=a
set ambiwidth=double

source ~/.dotfiles/move.vimrc

autocmd BufNewFile * silent! 0r $VIMHOME/templates/%:e.tpl
autocmd BufNewFile,BufReadPost *.md set filetype=markdown
autocmd BufNewFile,BufRead *.cap set filetype=ruby
autocmd BufNewFile,BufRead *.plot set filetype=gnuplot

nnoremap <silent> <Space>sp :<C-u>setlocal spell! spelllang=en_us<CR>:setlocal spell?<CR>

source ~/.dotfiles/neobundle.vimrc
source ~/.dotfiles/quickrun.vimrc
source ~/.dotfiles/pathogen.vimrc
source ~/.dotfiles/neocomplecache.vimrc
source ~/.dotfiles/lightline.vimrc
source ~/.dotfiles/latex.vimrc
source ~/.dotfiles/syntastic.vimrc
source ~/.dotfiles/vim-plugin-viewdoc.vimrc

highlight OverLength ctermbg=red ctermfg=white guibg=#592929
match OverLength /\%81v.\+/
hi Visual ctermbg=White guibg=White
let g:jsx_ext_required = 0
let g:go_version_warning = 0

colorscheme molokai
