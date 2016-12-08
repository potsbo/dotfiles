"""Neobundle""""
if has('vim_starting')
	filetype plugin off
	filetype indent off
	execute 'set runtimepath+=' . expand('~/.vim/bundle/neobundle.vim')
endif
"
" call neobundle#rc(expand('~/.vim/bundle'))
"
call neobundle#begin(expand('~/.vim/bundle'))
NeoBundle 'Shougo/neobundle.vim'	
NeoBundle 'Shougo/neocomplcache.vim' 	"neo-completion with cache
" NeoBundle 'Shougo/neocomplete.vim' 	"neo-completion with cache
NeoBundle 'Shougo/unite.vim'
NeoBundle 'Shougo/vimproc.vim'
NeoBundle 'kchmck/vim-coffee-script'
" NeoBundle 'vim-perl/vim-perl'
NeoBundle 'itchyny/lightline.vim'
" NeoBundle 'itchyny/dictionary.vim'
NeoBundle 'thinca/vim-quickrun'
" NeoBundle 'tpope/vim-surround'
" NeoBundle 'tpope/vim-fugitive'
" NeoBundle 'tpope/vim-markdown'
NeoBundle 'tpope/vim-commentary'
NeoBundle 'tpope/vim-pathogen'
NeoBundle 'tpope/vim-endwise' "automatic insertion of end keyword
NeoBundle 'tpope/vim-rails'
NeoBundle 'tpope/vim-bundler'
NeoBundle 'scrooloose/syntastic'
" NeoBundle 'scrooloose/nerdtree'
NeoBundle 'kana/vim-smartinput'
NeoBundle 'othree/html5.vim' 			"syntax for HTML5 
NeoBundle 'airblade/vim-gitgutter'
" NeoBundle 'hail2u/vim-css3-syntax'
" NeoBundle 'kchmck/vim-coffee-script'
" NeoBundle 'osyo-manga/vim-monster'
NeoBundle 'powerman/vim-plugin-viewdoc'
NeoBundle 'derekwyatt/vim-scala'
NeoBundle 'burnettk/vim-angular'
NeoBundle 'wakatime/vim-wakatime'
NeoBundle 'tomasr/molokai'
NeoBundle 'ujihisa/unite-colorscheme'
NeoBundle 'google/vim-ft-go'
NeoBundleCheck
call neobundle#end()
"""End of Neobundle""""
