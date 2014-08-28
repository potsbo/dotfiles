export VIMHOME=$HOME/.vim
export LANG=en_UK.UTF-8
export TERM="xterm-256color"
export PATH=$PATH:/usr/texbin
export PATH=/usr/local/bin:$PATH

### completion 
autoload -Uz compinit
compinit
# ignore case
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
# don't complete current directory after ../
zstyle ':completion:*' ignore-parents parent pwd ..
# complete commands after sudo 
zstyle ':completion:*:sudo:*' command-path /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin /usr/X11R6/bin
# complete processes when using ps command
zstyle ':completion:*:processes' command 'ps x -o pid,s,args'
#Spell check
setopt correct

###setting
#changing colors
export LSCOLORS=gxfxcxdxbxegedabagacad
# color setting like %{${fg[red]}%} 
autoload -Uz colors && colors
# support Japanese Letters
setopt print_eight_bit
# no beep
setopt no_beep
# '#' to comment
setopt interactive_comments
# =command is equal to which command
setopt equals
#vim-like
bindkey -v

### Usual Commands
## cd
# directory='cd directory'
setopt auto_cd
# auto push when cd
setopt auto_pushd
# dont push dups
setopt pushd_ignore_dups 
# ls just after cd
function chpwd() { ls -FG }

## ls 
alias ls='ls -FG'
alias no='ls'
alias la='ls -FA'
alias na='la'
alias ll='ls -Fl'
alias nn='ll'
alias lla='ls -FlA'
alias nna='lla'

## mkdir
alias mkdir='mkdir -p'

alias ical='vim -c Calendar'
alias finder='open -a Finder .'

#Vim-Like Prompt
function zle-line-init zle-keymap-select {
  case $KEYMAP in
    vicmd)
    PROMPT="%{$fg[cyan]%}%n%{$reset_color%}@%{$fg[cyan]%}%m%{$fg[red]%}-NOR-%{$fg[cyan]%}%#%{$reset_color%} "
    ;;
    main|viins)
    PROMPT="%{$fg[cyan]%}%n%{$reset_color%}@%{$fg[cyan]%}%m%{$reset_color%}-INS-%{$fg[cyan]%}%#%{$reset_color%} "
    ;;
  esac
  zle reset-prompt
}
zle -N zle-line-init
zle -N zle-keymap-select

#Right Prompt
RPROMPT="%{$fg[cyan]%}[%~]%{$reset_color%}"$WHITE
setopt transient_rprompt

### Utility alias
alias battery="pmset -g ps"
alias stig="cd /etc; sudo tig"
alias wakemate="wakeonlan -i otsbo.com -f ~/.mateHdWrAd"
alias zshrc='vim ~/.zshrc'
alias vimrc='vim ~/.vimrc'
alias keyremap="vim ~/Library/Application\ Support/KeyRemap4MacBook/private.xml"
alias wfstatus='networksetup -getairportpower en0'
alias wfon='networksetup -setairportpower en0 on'
alias wfoff='networksetup -setairportpower en0 off'
alias wfscan='/System/Library/PrivateFrameworks/Apple80211.framework/Versions/A/Resources/airport scan'
alias wfset='networksetup -setairportnetwork en0'
alias wfname='networksetup -getairportnetwork en0'

### Utility function
function rcpost {
	scp ~/.zshrc $1:;
	scp ~/.vimrc $1:;
}
function rcget {
	scp $1:~/.zshrc ~/;
	scp $1:~/.vimrc ~/;
}


### Application alias
#get twitter tl
alias twl="tw -tl"
#matrix
alias mmm="cmatrix -sab -u 10"
#weather for Fukuoka
alias meteo="curl --silent \"http://xml.weather.yahoo.com/forecastrss?p=JAXX0009&u=f\" | grep -E '(Forecast:<b><br />|High)' | sed -e 's/Forecast://' -e 's/<br \/>//' -e 's/<b>//' -e 's/<\/b>//' -e 's/<BR \/>//' -e 's/<description>//' -e 's/<\/description>//'"
alias t="/Users/potsbo/Dropbox/Library/todotxt/todo.sh"
alias me="vim /Users/Shimpei/Dropbox/Library/memex/memex.txt"
alias vimeuc="vim -c 'e ++enc=euc-jp'"
alias toever="open -a Evetnote.app"
# alias vim="/Applications/MacVim.app/Contents/MacOS/Vim"

# ### Application function
# #short wiki 
# function wiki {
# 	dig +short txt "$*".wp.dg.cx
# }
# # Geeknote
# alias gknote="python ~/Dropbox/geeknote/geeknote.py"
# function gkcr {
# 	gknote create -t "$1" -c "$2"
# }
# function togk {
# 	gknote create -t "$1" -c "`echo $1`"
# }
#

alias -s py=python
alias -s {png,jpg,bmp,PNG,JPG,BMP}=eog

alias -s html=chrome
function extract() {
	case $1 in
		*.tar.gz|*.tgz) tar xzvf $1;;
		*.tar.xz) tar Jxvf $1;;
		*.zip) unzip $1;;
		*.lzh) lha e $1;;
		*.tar.bz2|*.tbz) tar xjvf $1;;
		*.tar.Z) tar zxvf $1;;
		*.gz) gzip -d $1;;
		*.bz2) bzip2 -dc $1;;
		*.Z) uncompress $1;;
		*.tar) tar xvf $1;;
		*.arj) unarj $1;;
	esac

}
alias -s {gz,tgz,zip,lzh,bz2,tbz,Z,tar,arj,xz}=extract
function runcpp () { gcc $1; ./a.out $2 $3 $4 $5 $6 $7 $8 $9; }
alias -s {c,cpp}=runcpp

