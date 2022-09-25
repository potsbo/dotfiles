" vim-plug
call plug#begin()
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

Plug 'editorconfig/editorconfig-vim'
Plug 'prettier/vim-prettier', {
  \ 'do': 'yarn install --frozen-lockfile --production',
  \ 'on': ['PrettierAsync'] }
call plug#end()

nnoremap <silent> ;r :<C-u>QuickRun<CR>
nnoremap <silent> ;v :<C-u>OpenGithubFile<CR>
vnoremap <silent> ;v :<C-u>'<,'>OpenGithubFile<CR>

autocmd BufNewFile,BufRead *.jbuilder set filetype=ruby

" Source
source ~/.vim/rc/move.vimrc
source ~/.vim/rc/lsp.vim
source ~/.vim/rc/fzf.vim

" Shift-Option-F
noremap Ï :LspDocumentFormat<CR>
autocmd BufNewFile,BufRead *.ts,*.tsx :noremap Ï :PrettierAsync<CR>
