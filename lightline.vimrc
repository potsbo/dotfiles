"""lightline""""
let g:lightline = {
  \   'colorscheme': 'wombat',
  \  'mode_map': {'c': 'NORMAL'},
  \   'active': {
    \     'left':   [ [ 'mode', 'paste' ], [ 'fugitive', 'filename' ] ],
  \    'right': [ [ 'lineinfo',  'syntastic' ],
    \              [ 'percent' ],
    \              [ 'fileformat', 'fileencoding', 'filetype' ] ]
    \   },
  \   'component': { 
  \    'readonly': '%{&readonly?"⭤":""}',
  \    'modified': '%{&filetype=="help"?"":&modified?"+":&modifiable?"":"-"""}'
  \  },
   \   'component_visible_condition': {
    \     'readonly': '(&filetype!="help"&& &readonly)',
    \     'modified': '(&filetype!="help"&&(&modified||!&modifiable))'
    \   },
  \   'separator': { 'left': '⮀', 'right': '⮂' },
    \   'subseparator': { 'left': '⮁', 'right': '⮃' },
  \   'component_function': {
  \     'modified': 'MyModified',
  \     'fugitive': 'MyFugitive',
  \     'filename': 'MyFilename',
  \     'fileformat': 'MyFileformat',
  \     'filetype': 'MyFiletype',
  \    'readonly': 'MyReadonly',
  \     'fileencoding': 'MyFileencoding',
  \     'mode': 'MyMode', 
  \  },
   \   'component_expand': {
    \     'syntastic': 'SyntasticStatuslineFlag',
    \   },
  \   'component_type': {
    \     'syntastic': 'error'
    \   }
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
