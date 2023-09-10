nnoremap <silent> ;r :<C-u>QuickRun<CR>
nnoremap <silent> ;v :<C-u>OpenGithubFile<CR>
vnoremap <silent> ;v :<C-u>'<,'>OpenGithubFile<CR>

autocmd BufNewFile,BufRead *.jbuilder set filetype=ruby

" Source
source ~/.vim/rc/move.vimrc
source ~/.vim/rc/lsp.vim

" Shift-Option-F
noremap Ï :LspDocumentFormat<CR>
autocmd BufNewFile,BufRead *.ts,*.tsx :noremap Ï :PrettierAsync<CR>
autocmd BufNewFile,BufRead *.hs :noremap Ï :Hindent<CR>

if system("git rev-parse --is-inside-work-tree 2> /dev/null ; echo $?") == 0
  command CommandP GFiles --cached --others --exclude-standard
else
  command CommandP Files
endif

command CommandShiftF Rg
