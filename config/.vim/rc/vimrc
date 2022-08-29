augroup MyAutoCmd
  autocmd!
augroup END

" vim-plug
call plug#begin('~/.vim/plug')
" LSP
Plug 'prabirshrestha/async.vim'
Plug 'prabirshrestha/asyncomplete.vim'
Plug 'prabirshrestha/asyncomplete-lsp.vim'
Plug 'prabirshrestha/vim-lsp'
Plug 'mattn/vim-lsp-settings'
Plug 'mattn/vim-lsp-icons'

Plug 'itchyny/lightline.vim'
Plug 'airblade/vim-gitgutter'
Plug 'flazz/vim-colorschemes'
Plug 'tpope/vim-commentary', { 'on': 'Commentary' }
Plug 'cohama/lexima.vim'
Plug 'tpope/vim-fugitive', { 'on': ['Git'] }
Plug 'thinca/vim-quickrun', { 'on': ['QuickRun'] }
Plug 'tyru/open-browser.vim'
Plug 'tyru/open-browser-github.vim', { 'on': ['OpenGithubFile'] }

Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" TOML
Plug 'cespare/vim-toml', { 'for': 'toml' }

" Protocol Buffers
Plug 'uber/prototool', { 'for': 'proto', 'rtp': 'vim/prototool' }

" Golang
Plug 'mattn/vim-goimports', { 'for': 'go' }

" TypeScript
Plug 'leafgarland/typescript-vim', { 'for': 'typescript' }
Plug 'peitalin/vim-jsx-typescript', { 'for': 'typescript' }

" Coffee
Plug 'kchmck/vim-coffee-script', { 'for': 'coffee' }

" Re:View
Plug 'tokorom/vim-review', { 'for': 're' }

" Swift
Plug 'keith/swift.vim', { 'for': 'swift' }

" Kotlin
Plug 'udalov/kotlin-vim', { 'for': 'kotolin' }

" Terraform
Plug 'hashivim/vim-terraform', { 'for': 'tf' }

" Ocaml
Plug 'ocaml/vim-ocaml', { 'for': 'ocaml' }

Plug 'rizzatti/dash.vim'

Plug 'chr4/nginx.vim', { 'for': 'nginx' }
Plug 'chrismaher/vim-lookml'

Plug 'jparise/vim-graphql', { 'for': 'graphql' }

Plug 'rust-lang/rust.vim', { 'for': 'rust' }

call plug#end()

" Editor
set clipboard=unnamed
syntax enable
set number
set tabstop=2 shiftwidth=2 softtabstop=2
set ignorecase
set smartcase

" Color
colorscheme molokai
" Swap fg and bg
highlight MatchParen ctermfg=208 ctermbg=none cterm=bold

" Config
set noswapfile

nnoremap <silent> ;r :<C-u>QuickRun<CR>
nnoremap <silent> ;v :<C-u>OpenGithubFile<CR>
vnoremap <silent> ;v :<C-u>'<,'>OpenGithubFile<CR>

" let g:syntastic_check_on_open = 1
" let g:syntastic_python_checkers = ['flake8', 'pep257', 'mypy']
" let g:syntastic_python_flake8_args = '--max-line-length=120'
" let g:syntastic_python_mypy_args = '--ignore-missing-imports'

function! OcamlFmt()
  silent execute "!ocamlformat --enable-outside-detected-project --module-item-spacing=preserve --inplace %"
  edit!
endfunction

command! OcamlFmt call OcamlFmt()
augroup ocaml_autocmd
  autocmd BufWritePost *.ml OcamlFmt
  autocmd BufWritePost *.mli OcamlFmt
augroup END


autocmd BufNewFile,BufRead *.jbuilder set filetype=ruby

" Source
source ~/.vim/rc/move.vimrc
source ~/.vim/rc/lightline.vimrc
source ~/.vim/rc/lsp.vim
source ~/.vim/rc/fzf.vim

let g:rustfmt_autosave = 1
let g:lsp_preview_max_width = 80
set wildmode=longest:full

" Shift-Option-F
noremap Ï :LspDocumentFormat<CR>

cnoremap <C-A> <Home>
inoremap <c-k> <c-o>D
cnoremap <c-k> <c-\>e getcmdpos() == 1 ? '' : getcmdline()[:getcmdpos()-2]<CR>
