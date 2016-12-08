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
