nnoremap <silent> ;r :<C-u>QuickRun<CR>
nnoremap <silent> ;v :<C-u>OpenGithubFile<CR>
vnoremap <silent> ;v :<C-u>'<,'>OpenGithubFile<CR>

autocmd BufNewFile,BufRead *.jbuilder set filetype=ruby

" Source
source ~/.vim/rc/move.vimrc
source ~/.vim/rc/lsp.vim
source ~/.vim/rc/fzf.vim

" Shift-Option-F
noremap Ï :LspDocumentFormat<CR>
autocmd BufNewFile,BufRead *.ts,*.tsx :noremap Ï :PrettierAsync<CR>
