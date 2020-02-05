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
noremap l n
noremap L N 
nnoremap D ,
nnoremap H J
nnoremap T K
nnoremap N ;
vnoremap D ,
vnoremap H J
vnoremap T K
vnoremap N ;

nnoremap <silent> <Esc><Esc> :<C-u>nohlsearch<CR>

nnoremap ;c  :<C-u>Commentary<CR>
vnoremap ;c  :<C-u>'<,'>Commentary<CR>

" panes
let g:mapleader = 'z'
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
