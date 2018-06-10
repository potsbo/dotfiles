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
" noremap K T " save for VimManDoc
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
nnoremap & <C-x>

noremap <C-.> <C-v>

nnoremap ;c  :<C-u>Commentary<CR>
vnoremap ;c  :<C-u>'<,'>Commentary<CR>

" panes
let mapleader = "z"
" move to anther pane
nnoremap <Leader>h <C-w>j
nnoremap <Leader>t <C-w>k
nnoremap <Leader>n <C-w>l
nnoremap <Leader>d <C-w>h
nnoremap ZH <C-w>J
nnoremap ZT <C-w>K
nnoremap ZN <C-w>L
nnoremap ZD <C-w>H
" create a pane
nnoremap <Leader>s :<C-u>sp<CR>
nnoremap <Leader>v :<C-u>vs<CR>
