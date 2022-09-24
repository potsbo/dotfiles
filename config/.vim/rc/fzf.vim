if system("git rev-parse --is-inside-work-tree 2> /dev/null ; echo $?") == 0
  command CommandShiftP GFiles --cached --others --exclude-standard
else
  command CommandShiftP Files
endif

command CommandShiftF Ag
