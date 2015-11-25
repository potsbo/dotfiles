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
colorscheme molokai

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
set helplang=en
set laststatus=2
set cursorline
set cursorcolumn
set splitright
set vb
set timeoutlen=200 ttimeoutlen=0

hi Visual ctermbg=152 guibg=#CCC

" save and quit (like emacs)
noremap <silent><C-x><C-s> :<C-u>w<CR>
noremap <silent><C-x><C-w> :<C-u>w<Space>
noremap <silent><C-x><C-c> :<C-u>quit<CR>

nnoremap <Space>/ *<C-o>
nnoremap g<Space>/ g*<C-o>

nnoremap <expr> - <SID>search_forward_p() ? 'nzv' : 'Nzv'
nnoremap <expr> _ <SID>search_forward_p() ? 'Nzv' : 'nzv'
vnoremap <expr> - <SID>search_forward_p() ? 'nzv' : 'Nzv'
vnoremap <expr> _ <SID>search_forward_p() ? 'Nzv' : 'nzv'

function! s:search_forward_p()
	  return exists('v:searchforward') ? v:searchforward : 1
endfunction

nnoremap <Space>o  :<C-u>for i in range(v:count1) \| call append(line('.'), '') \| endfor<CR>
nnoremap <Space>O  :<C-u>for i in range(v:count1) \| call append(line('.')-1, '') \| endfor<CR>

nnoremap <silent> <Esc><Esc> :<C-u>nohlsearch<CR>

onoremap aa  a>
onoremap ia  i>
onoremap ao  a]
onoremap io  i]
onoremap ae  a)
onoremap ie  i)
onoremap ad  a"
onoremap id  i"

vnoremap aa  a>
vnoremap ia  i>
vnoremap ao  a]
vnoremap io  i]
vnoremap ae  a)
vnoremap ie  i)
vnoremap ad  a"
vnoremap id  i"


"move for dvorak
noremap d h
noremap h gj
noremap t gk
noremap n l
noremap <Space>d  ^
noremap <Space>h  G
noremap <Space>t  gg
noremap <Space>n  $
noremap j d
noremap k t
noremap K T
noremap l n
noremap L N 
nnoremap D ,
nnoremap H }
nnoremap T {
nnoremap N ;
vnoremap D ,
vnoremap H }
vnoremap T {
vnoremap N ;

nnoremap # <C-a>
nnoremap ! <C-x>

noremap <C-.> <C-v>

nnoremap ;c  :<C-u>Commentary<CR>
vnoremap ;c  :<C-u>'<,'>Commentary<CR>

" end of for dvorak

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
NeoBundle 'Shougo/unite.vim'
NeoBundle 'Shougo/vimproc.vim'
NeoBundle 'vim-perl/vim-perl'
NeoBundle 'itchyny/lightline.vim'
NeoBundle 'itchyny/dictionary.vim'
NeoBundle 'thinca/vim-quickrun'
NeoBundle 'tpope/vim-surround'
NeoBundle 'tpope/vim-fugitive'
NeoBundle 'tpope/vim-markdown'
NeoBundle 'tpope/vim-commentary'
NeoBundle 'tpope/vim-pathogen'
NeoBundle 'scrooloose/syntastic'
NeoBundle 'kana/vim-smartinput'
NeoBundle 'othree/html5.vim' 			"syntax for HTML5 
NeoBundle 'airblade/vim-gitgutter'
NeoBundle 'hail2u/vim-css3-syntax'
NeoBundle 'kchmck/vim-coffee-script'
NeoBundleCheck
call neobundle#end()
"""End of Neobundle""""

call pathogen#infect()
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0
augroup AutoSyntasticAll
	autocmd!
	autocmd BufWritePost * call s:syntastic()
augroup END

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

" panes
let mapleader = "z"
" move to anther pane
nnoremap zh <C-w>j
nnoremap zt <C-w>k
nnoremap zn <C-w>l
nnoremap zd <C-w>h
nnoremap ZH <C-w>J
nnoremap ZT <C-w>K
nnoremap ZN <C-w>L
nnoremap ZD <C-w>H
" create a pane
nnoremap <Leader>s :<C-u>sp<CR>
nnoremap <Leader>v :<C-u>vs<CR>
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
	\ 	'colorscheme': 'wombatme',
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
let g:syntastic_mode_map = { 'mode': 'passive' }
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


"""Evervim""""
let g:evervim_devtoken='S=s40:U=41c9cb:E=14e14e623a0:C=146bd34f558:P=1cd:A=en-devtoken:V=2:H=2e17ab396f7b0d3a777a64b7d80de30d'
"""End of Evervim""""


"""Calendar.vim""""
let g:calendar_locale= "uk"
let g:calendar_google_calendar = 1
let g:calendar_google_task = 1
let g:calendar_date_endian ="litte"
let g:calendar_date_separator = "-"
let g:calendar_date_month_name = 1
"""End of Calender.vim""""

"""quickrun"""
let g:quickrun_config = {'*': {'hook/time/enable': '1'},}
" let g:quickrun_config={'*': {'split': ''}}
let g:quickrun_config._={ 'runner':'vimproc',
			\       "runner/vimproc/updatetime" : 10,
			\       "outputter/buffer/close_on_empty" : 1,
			\ }
nnoremap <silent> <space>r :<C-u>QuickRun<CR>
nnoremap <silent> <space>w :<C-u>w<CR>
nnoremap <silent> <space>q :<C-u>q<CR>
let g:quickrun_config['html'] = { 'command' : 'open', 'exec' : '%c %s', 'outputter': 'browser' }
let g:quickrun_config.cpp = { 'command': 'g++','cmdopt': '-std=c++11'}
let g:quickrun_config['swift'] = { 'command': 'swift', 'cmdopt': '', 'exec': '%c %o %s',}
"   }
"""end quickrun""""

" nnoremap <space>s :<C-u>SplitjoinSplit<cr>
" nnoremap <space>j :<C-u>SplitjoinJoin<cr>


noremap :sudow :<C-u>w !sudo tee %
noremap :chrome :<C-u>open -a Google\ Chrome %<CR><CR>

let g:viewdoc_open = "open"
let g:no_viewdoc_maps = 1

let g:syntastic_cpp_compiler = 'clang++'
let g:syntastic_cpp_compiler_options = ' -std=c++11 -stdlib=libc++'

set mouse=a

