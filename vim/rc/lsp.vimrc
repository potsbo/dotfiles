if executable('golsp')
    au User lsp_setup call lsp#register_server({
        \ 'name': 'golsp',
        \ 'cmd': {server_info->['golsp', '-mode', 'stdio']},
        \ 'whitelist': ['go'],
        \ })
endif

let g:lsp_async_completion = 1
let g:asyncomplete_smart_completion = 1
let g:asyncomplete_auto_popup = 1
