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
set cursorline
set cursorcolumn
set splitright
set vb
set timeoutlen=200 ttimeoutlen=0
set mouse=a

source ~/.dotfiles/move.vimrc

autocmd BufNewFile * silent! 0r $VIMHOME/templates/%:e.tpl
" autocmd BufRead,BufNewFile *.mkd  setfiletype mkd
" autocmd BufRead,BufNewFile *.md  setfiletype mkd
autocmd BufNewFile,BufReadPost *.md set filetype=markdown

nnoremap <silent> <Space>sp :<C-u>setlocal spell! spelllang=en_us<CR>:setlocal spell?<CR>

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

source ~/.dotfiles/quickrun.vimrc

call pathogen#infect()
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 1

"""NeoComplCache""""
"Disable AutoComplPop.
let g:acp_enableAtStartup = 0
"
" Use neocomplcache.
let g:neocomplcache_enable_at_startup = 1
let g:NeoComplCache_EnableAutoSelect = 1
" Use smartcase.
let g:neocomplcache_enable_smart_case = 1
" Set minimum syntax keyword length.
let g:neocomplcache_min_syntax_length = 3
"let g:neocomplcache_lock_buffer_name_pattern = '\*ku\*'
"let g:NeoComplCache_IgnoreCase=1
"
"" Define dictionary.
"let g:neocomplcache_dictionary_filetype_lists = {
"			\ 'default' : ''
"			\ }
"
"" Plugin key-mappings.
"inoremap <expr><C-g>     neocomplcache#undo_completion()
"inoremap <expr><C-l>     neocomplcache#complete_common_string()
"
"" Recommended key-mappings.
"" <CR>: close popup and save indent.
"inoremap <silent> <CR> <C-r>=<SID>my_cr_function()<CR>
"function! s:my_cr_function()
"	return neocomplcache#smart_close_popup() . "\<CR>"
"endfunction
" <TAB>: completion.
inoremap <expr><TAB>  pumvisible() ? "\<C-n>" : "\<TAB>"
"" <C-h>, <BS>: close popup and delete backword char.
"inoremap <expr><C-h> neocomplcache#smart_close_popup()."\<C-h>"
""   inoremap <expr><BS> neocomplcache#smart_close_popup().""


"let g:hi_insert = 'highlight StatusLine guifg=darkblue guibg=darkyellow gui=none ctermfg=blue ctermbg=yellow cterm=none'


"
" "mru,reg,buf
noremap :um :Unite file_mru -buffer-name=file_mru
noremap :ur :Unite register -buffer-name=register
noremap :ub :Unite buffer -buffer-name=buffer
"
"file current_dir
noremap :ufc :Unite file -buffer-name=file
noremap :ufcr :Unite file_rec -buffer-name=file_rec
"
" "file file_current_dir
noremap :uff :UniteWithBufferDir file -buffer-name=file
noremap :uffr :UniteWithBufferDir file_rec -buffer-name=file_rec
"
" " c-jはescとする
au FileType unite nnoremap    
"
noremap :um :Unite file_mru -buffer-name=file_mru

" change size
" call submode#enter_with('bufmove', 'n', '', 'ze', '<C-w>>')
" call submode#enter_with('bufmove', 'n', '', 'za', '<C-w><')
" call submode#enter_with('bufmove', 'n', '', 'zv', '<C-w>+')
" call submode#enter_with('bufmove', 'n', '', 'z-', '<C-w>-')
" call submode#map('bufmove', 'n', '', 'e', '<C-w>>')
" call submode#map('bufmove', 'n', '', 'a', '<C-w><')
" call submode#map('bufmove', 'n', '', '+', '<C-w>+')
" call submode#map('bufmove', 'n', '', '+', '<C-w>-')
" call submode#enter_with('movepane', 'n', '', 'zh', '<C-w>j')
" call submode#enter_with('movepane', 'n', '', 'zt', '<C-w>k')
" call submode#enter_with('movepane', 'n', '', 'zd', '<C-w>h')
" call submode#enter_with('movepane', 'n', '', 'zn', '<C-w>l')
" call submode#map('movepane', 'n', '', 'h', '<C-w>j')
" call submode#map('movepane', 'n', '', 't', '<C-w>k')
" call submode#map('movepane', 'n', '', 'd', '<C-w>h')
" call submode#map('movepane', 'n', '', 'n', '<C-w>l')
" call submode#leave_with('movepane', 'n', '', 'z,<ESC>')
let g:submode_timeout = 0

" nnoremap q<Space> <C-w>_<C-w>|

nnoremap fr <C-w>r
nnoremap f= <C-w>=
nnoremap fw <C-w>w
nnoremap fO <C-w>=
nnoremap fN :<C-u>bn<CR>
nnoremap fP :<C-u>bp<CR>
nnoremap ft :<C-u>tabnew<CR>
nnoremap fT :<C-u>Unite tab<CR>
nnoremap fb :<C-u>Unite buffer_tab -buffer-name=file<CR>
nnoremap fB :<C-u>Unite buffer -buffer-name=file<CR>

"""lightline""""
let g:lightline = {
	\ 	'colorscheme': 'wombat',
	\	'mode_map': {'c': 'NORMAL'},
	\ 	'active': {
    \   	'left': 	[ [ 'mode', 'paste' ], [ 'fugitive', 'filename' ] ],
	\		'right': [ [ 'lineinfo',  'syntastic' ],
    \              [ 'percent' ],
    \              [ 'fileformat', 'fileencoding', 'filetype' ] ]
    \ 	},
	\ 	'component': { 
	\		'readonly': '%{&readonly?"⭤":""}',
	\		'modified': '%{&filetype=="help"?"":&modified?"+":&modifiable?"":"-"""}'
	\	},
 	\ 	'component_visible_condition': {
    \   	'readonly': '(&filetype!="help"&& &readonly)',
    \   	'modified': '(&filetype!="help"&&(&modified||!&modifiable))'
    \ 	},
	\ 	'separator': { 'left': '⮀', 'right': '⮂' },
    \ 	'subseparator': { 'left': '⮁', 'right': '⮃' },
	\ 	'component_function': {
	\ 		'modified': 'MyModified',
	\ 		'fugitive': 'MyFugitive',
	\ 		'filename': 'MyFilename',
	\ 		'fileformat': 'MyFileformat',
	\ 		'filetype': 'MyFiletype',
	\		'readonly': 'MyReadonly',
	\ 		'fileencoding': 'MyFileencoding',
	\ 		'mode': 'MyMode', 
	\	},
 	\ 	'component_expand': {
    \   	'syntastic': 'SyntasticStatuslineFlag',
    \ 	},
	\ 	'component_type': {
    \   	'syntastic': 'error'
    \ 	}
	\ }
augroup AutoSyntastic
	autocmd!
	autocmd BufWritePost *.c,*.cpp call s:syntastic()
augroup END
function! s:syntastic()
	SyntasticCheck
	call lightline#update()
endfunction

function! MyModified()
	return &ft =~ 'help\|vimfiler\|gundo' ? '' : &modified ? '+' : &modifiable ? '' : '-'
endfunction

function! MyReadonly()
	return &ft !~? 'help\|vimfiler\|gundo' && &readonly ? '⭤' : ''
endfunction

function! MyFilename()
	return ('' != MyReadonly() ? MyReadonly() . ' ' : '') .
				\ (&ft == 'vimfiler' ? vimfiler#get_status_string() :
				\  &ft == 'unite' ? unite#get_status_string() :
				\  &ft == 'vimshell' ? vimshell#get_status_string() :
				\ '' != expand('%:t') ? expand('%:t') : '[No Name]') .
				\ ('' != MyModified() ? ' ' . MyModified() : '')
endfunction

function! MyFugitive()
	try
		if &ft !~? 'vimfiler\|gundo' && exists('*fugitive#head')
			" return fugitive#head()
			let _ = fugitive#head()
			return strlen(_) ? '⭠ '._ : ''
		endif
	catch
	endtry
	return ''
endfunction

function! MyFileformat()
	return winwidth(0) > 70 ? &fileformat : ''
endfunction

function! MyFiletype()
	return winwidth(0) > 70 ? (strlen(&filetype) ? &filetype : 'no ft') : ''
endfunction

function! MyFileencoding()
	return winwidth(0) > 70 ? (strlen(&fenc) ? &fenc : &enc) : ''
endfunction

function! MyMode()
	return winwidth(0) > 60 ? lightline#mode() : ''
endfunction'
filetype plugin indent on
"""end lightline""""



"""Vim-LaTeX"""
filetype plugin on
filetype indent on
set shellslash
set grepprg=grep\ -nH\ $*
let g:tex_flavor='latex'
let g:Imap_UsePlaceHolders = 1
let g:Imap_DeleteEmptyPlaceHolders = 1
let g:Imap_StickyPlaceHolders = 0
let g:Tex_DefaultTargetFormat = 'pdf'
let g:Tex_MultipleCompileFormats='dvi,pdf'
"let g:Tex_FormatDependency_pdf = 'pdf'
let g:Tex_FormatDependency_pdf = 'dvi,pdf'
"let g:Tex_FormatDependency_pdf = 'dvi,ps,pdf'
let g:Tex_FormatDependency_ps = 'dvi,ps'
let g:Tex_CompileRule_pdf = '/usr/texbin/ptex2pdf -u -l -ot "-synctex=1 -interaction=nonstopmode -file-line-error-style" $*'
"let g:Tex_CompileRule_pdf = '/usr/texbin/pdflatex -synctex=1 -interaction=nonstopmode -file-line-error-style $*'
"let g:Tex_CompileRule_pdf = '/usr/texbin/lualatex -synctex=1 -interaction=nonstopmode -file-line-error-style $*'
"let g:Tex_CompileRule_pdf = '/usr/texbin/luajitlatex -synctex=1 -interaction=nonstopmode -file-line-error-style $*'
"let g:Tex_CompileRule_pdf = '/usr/texbin/xelatex -synctex=1 -interaction=nonstopmode -file-line-error-style $*'
"let g:Tex_CompileRule_pdf = '/usr/local/bin/ps2pdf $*.ps'
let g:Tex_CompileRule_ps = '/usr/texbin/dvips -Ppdf -o $*.ps $*.dvi'
let g:Tex_CompileRule_dvi = '/usr/texbin/uplatex -synctex=1 -interaction=nonstopmode -file-line-error-style $*'
let g:Tex_BibtexFlavor = '/usr/texbin/upbibtex'
let g:Tex_MakeIndexFlavor = '/usr/texbin/mendex -U $*.idx'
let g:Tex_UseEditorSettingInDVIViewer = 1
" let g:Tex_ViewRule_pdf = '/usr/bin/open -a Skim.app'
let g:Tex_ViewRule_pdf = '/usr/bin/open -a Preview.app'
"let g:Tex_ViewRule_pdf = '/usr/bin/open -a TeXShop.app'
"let g:Tex_ViewRule_pdf = '/usr/bin/open -a TeXworks.app'
"let g:Tex_ViewRule_pdf = '/usr/bin/open -a Firefox.app'
"let g:Tex_ViewRule_pdf = '/usr/bin/open -a "Adobe Reader.app"'
"let g:Tex_ViewRule_pdf = '/usr/bin/open'
nnoremap ;j :execute ":!".Tex_CompileRule_pdf." %"<CR>
nnoremap ;k :execute ":!".Tex_CompileRule_pdf."% && ".Tex_ViewRule_pdf." %<.pdf"<CR>
"""End of Vim-LaTeX"""

" nnoremap <space>s :<C-u>SplitjoinSplit<cr>
" nnoremap <space>j :<C-u>SplitjoinJoin<cr>


noremap :sudow :<C-u>w !sudo tee %
noremap :chrome :<C-u>open -a Google\ Chrome %<CR><CR>

let g:viewdoc_open = "open"
let g:no_viewdoc_maps = 1

let g:syntastic_cpp_compiler = 'g++'
let g:syntastic_cpp_compiler_options = ' -std=c++11 -stdlib=libc++'


let g:cpp_class_scope_highlight = 1
let g:syntastic_html_tidy_ignore_errors = [
	\  '<html> attribute "lang" lacks value',
	\  '<a> attribute "href" lacks value',
	\  'trimming empty <span>',
	\  'trimming empty <h1>',
	\  'trimming empty <i>'
	\ ]

highlight OverLength ctermbg=red ctermfg=white guibg=#592929
match OverLength /\%81v.\+/
colorscheme molokai
hi Visual ctermbg=White guibg=#FFF
au BufNewFile,BufRead *.cap set filetype=ruby

