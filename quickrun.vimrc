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
let g:quickrun_config['scala'] = { 'command': 'scala', 'cmdopt': ''}
let g:quickrun_config.tex  = {
			\ 'command': 'platex',
			\ 'exec': ['%c %s', 'dvipdfmx %s:r.dvi', 'open %s:r.pdf -a Preview']
			\ }
let g:quickrun_config.js = { 'command': 'node' }
			
"   }
"""end quickrun""""

