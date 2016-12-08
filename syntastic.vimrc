
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 1

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
