" Layout
let g:fzf_layout = { 'window': 'call FloatingFZF()' }

function! FloatingFZF()
  let buf = nvim_create_buf(v:false, v:true)
  call setbufvar(buf, '&signcolumn', 'no')

  let height = float2nr(&lines * 0.6)
  let width = float2nr(&columns - (&columns * 2 / 10))
  let row = float2nr(&lines * 0.2)
  let col = float2nr((&columns - width) / 2)

  let opts = {
        \ 'relative': 'editor',
        \ 'row': row,
        \ 'col': col,
        \ 'width': width,
        \ 'height': height
        \ }

  call nvim_open_win(buf, v:true, opts)
endfunction

if system("git rev-parse --is-inside-work-tree 2> /dev/null ; echo $?") == 0
  command CommandP GFiles --cached --others --exclude-standard
else
  command CommandP Files
endif

command CommandShiftF Ag
