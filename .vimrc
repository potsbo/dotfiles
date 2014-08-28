"
" .vimrc of potsbo
"

set encoding=utf-8
set nocompatible
set fileencodings=utf-8,ucs-bom,iso-2022-jp-3,iso-2022-jp,eucjp-ms,euc-jisx0213,euc-jp,sjis,cp932,utf-8

filetype off "TODO
nohlsearch
filetype plugin on
filetype indent on
syntax on
colorscheme molokai

set number 		"line number"
set incsearch 	"incremental search
set hlsearch 	"highlightsearch"
set wrap 		"all letters insite"
" set showmatch
set whichwrap=b,s,h,l "move to the p/n line with l/r keys"
set wrapscan  "move to the p/n spelling mistake"
set ignorecase
set smartcase
set hidden "TODO"
set history=2000
set autoindent
set tabstop=4
set shiftwidth=4
set helplang=en
set laststatus=2
set cursorline
set cursorcolumn
set splitright
set vb

" highlight CursorLine ctermbg=Black
" highlight CursorColumn ctermbg=Black
hi Visual ctermbg=152 guibg=#CCC
nnoremap <Space>,  :<C-u>w<CR>
nnoremap <Space>'  :<C-u>q<CR>
nnoremap <Space>'''  :<C-u>q!<CR>

nnoremap ;  :
nnoremap :  ;
vnoremap ;  :
vnoremap :  ;

nnoremap <Space>h  ^
nnoremap <Space>l  $

nnoremap k   gk
nnoremap j   gj
vnoremap k   gk
vnoremap j   gj
nnoremap gk  k
nnoremap gj  j
vnoremap gk  k
vnoremap gj  j


nnoremap <Space>/ *<C-o>
nnoremap g<Space>/ g*<C-o>

nnoremap <expr> n <SID>search_forward_p() ? 'nzv' : 'Nzv'
nnoremap <expr> N <SID>search_forward_p() ? 'Nzv' : 'nzv'
vnoremap <expr> n <SID>search_forward_p() ? 'nzv' : 'Nzv'
vnoremap <expr> N <SID>search_forward_p() ? 'Nzv' : 'nzv'

function! s:search_forward_p()
	  return exists('v:searchforward') ? v:searchforward : 1
endfunction

nnoremap <Space>o  :<C-u>for i in range(v:count1) \| call append(line('.'), '') \| endfor<CR>
nnoremap <Space>O  :<C-u>for i in range(v:count1) \| call append(line('.')-1, '') \| endfor<CR>

nnoremap <silent> tt  :<C-u>tabe<CR>
nnoremap <C-p>  gT
nnoremap <C-n>  gt

nnoremap <silent> <Esc><Esc> :<C-u>nohlsearch<CR>

onoremap aa  a>
onoremap ia  i>
onoremap ar  a]
onoremap ir  i]
onoremap ad  a"
onoremap id  i"

autocmd BufNewFile * silent! 0r $VIMHOME/templates/%:e.tpl
autocmd BufRead,BufNewFile *.mkd  setfiletype mkd
autocmd BufRead,BufNewFile *.md  setfiletype mkd

nnoremap <silent> <Space>sp :<C-u>setlocal spell! spelllang=en_us<CR>:setlocal spell?<CR>

"""Neobundle""""
if has('vim_starting')
	filetype plugin off
	filetype indent off
	execute 'set runtimepath+=' . expand('~/.vim/bundle/neobundle.vim')
endif
"
call neobundle#rc(expand('~/.vim/bundle'))
"
NeoBundle 'Shougo/neobundle.vim'	
NeoBundle 'Shougo/neocomplcache.vim' 	"neo-completion with cache
NeoBundle 'Shougo/unite.vim'
NeoBundle 'Shougo/vimproc.vim'
NeoBundle 'itchyny/lightline.vim'
NeoBundle 'itchyny/thumbnail.vim'
NeoBundle 'itchyny/calendar.vim'
NeoBundle 'itchyny/dictionary.vim'
NeoBundle 'thinca/vim-quickrun'
NeoBundle 'tpope/vim-surround'
NeoBundle 'tpope/vim-fugitive'
NeoBundle 'tpope/vim-markdown'
NeoBundle 'scrooloose/nerdtree'
NeoBundle 'scrooloose/syntastic'
NeoBundle 'kana/vim-smartinput'
NeoBundle 'kana/vim-submode'
NeoBundle 'kien/ctrlp.vim'
NeoBundle 'tomtom/tcomment_vim'
NeoBundle 'fuenor/qfixhowm'
NeoBundle 'vimtaku/vim-mlh'
NeoBundle 'osyo-manga/vim-over'
NeoBundle 'yegappan/mru'
NeoBundle 'othree/html5.vim' 			"syntax for HTML5 
NeoBundle 'kakkyz81/evervim'  			"Evernote for vim:
NeoBundle 'deris/vim-fitcolumn' 		"for coding rule
NeoBundle 'git://git.code.sf.net/p/vim-latex/vim-latex'
NeoBundle 'airblade/vim-gitgutter'
NeoBundle 'tyru/open-browser.vim'
NeoBundleCheck
"""End of Neobundle""""



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

nnoremap + <C-a>
nnoremap - <C-x>

nnoremap s <Nop>
nnoremap sj <C-w>j
nnoremap sk <C-w>k
nnoremap sl <C-w>l
nnoremap sh <C-w>h
nnoremap sJ <C-w>J
nnoremap sK <C-w>K
nnoremap sL <C-w>L
nnoremap sH <C-w>H
nnoremap sn gt
nnoremap sp gT
nnoremap sr <C-w>r
nnoremap s= <C-w>=
nnoremap sw <C-w>w
nnoremap so <C-w>_<C-w>|
nnoremap sO <C-w>=
nnoremap sN :<C-u>bn<CR>
nnoremap sP :<C-u>bp<CR>
nnoremap st :<C-u>tabnew<CR>
nnoremap sT :<C-u>Unite tab<CR>
nnoremap ss :<C-u>sp<CR>
nnoremap sv :<C-u>vs<CR>
nnoremap sq :<C-u>q<CR>
nnoremap sQ :<C-u>bd<CR>
nnoremap sb :<C-u>Unite buffer_tab -buffer-name=file<CR>
nnoremap sB :<C-u>Unite buffer -buffer-name=file<CR>

call submode#enter_with('bufmove', 'n', '', 's>', '<C-w>>')
call submode#enter_with('bufmove', 'n', '', 's<', '<C-w><')
call submode#enter_with('bufmove', 'n', '', 's+', '<C-w>+')
call submode#enter_with('bufmove', 'n', '', 's-', '<C-w>-')
call submode#map('bufmove', 'n', '', '>', '<C-w>>')
call submode#map('bufmove', 'n', '', '<', '<C-w><')
call submode#map('bufmove', 'n', '', '+', '<C-w>+')

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
"
" noremap <space>ll \ll
"""End of Vim-LaTeX"""


"""Evervim""""
let g:evervim_devtoken='S=s40:U=41c9cb:E=14e14e623a0:C=146bd34f558:P=1cd:A=en-devtoken:V=2:H=2e17ab396f7b0d3a777a64b7d80de30d'
"""End of Evervim""""


"""Calendar.vim""""
let g:calendar_locale= "jp"
let g:calendar_google_calendar = 1
let g:calendar_google_task = 1
let g:calendar_date_endian ="litte"
let g:calendar_date_separator = "-"
let g:calendar_date_month_name = 1
"""End of Calender.vim""""

"""quickrun"""
let g:quickrun_config = {'*': {'hook/time/enable': '1'},}
nnoremap <silent> <space>r :<C-u>QuickRun<CR>
nnoremap <silent> <space>w :<C-u>w<CR>
nnoremap <silent> <space>q :<C-u>q<CR>
let g:quickrun_config['html'] = { 'command' : 'open', 'exec' : '%c %s', 'outputter': 'browser' }
"""end quickrun""""

" nnoremap <space>s :<C-u>SplitjoinSplit<cr>
" nnoremap <space>j :<C-u>SplitjoinJoin<cr>


noremap :sudow :<C-u>w !sudo tee %
noremap :chrome :<C-u>open -a Google\ Chrome %<CR><CR>
