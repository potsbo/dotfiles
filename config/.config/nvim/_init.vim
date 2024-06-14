autocmd BufNewFile,BufRead *.jbuilder,Podfile set filetype=ruby
autocmd BufNewFile,BufRead *.ejs set filetype=html

" Shift-Option-F
noremap Ï :LspDocumentFormat<CR>
autocmd BufNewFile,BufRead *.hs :noremap Ï :Hindent<CR>

if system("git rev-parse --is-inside-work-tree 2> /dev/null ; echo $?") == 0
  command CommandP GFiles --cached --others --exclude-standard
else
  command CommandP Files
endif

command CommandShiftF Rg
