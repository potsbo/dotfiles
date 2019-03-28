# export
export LANG=en_US.UTF-8
export TERM="screen-256color"
export EDITOR=vim
export PGDATA=/usr/local/var/postgres
export LC_ALL=$LANG
export AWS_REGION=ap-northeast-1

# HOME
export VIMHOME=$HOME/.vim
export MYVIMRC=$HOME/.vimrc
export WANTEDLY_HOME=$HOME/.wantedly
export GOENV_DISABLE_GOROOT=1
export GOENV_DISABLE_GOPATH=1
export GOPATH=$HOME/.go
export ZSH=$HOME/.oh-my-zsh

# PATH
export PATH=~/.anyenv/bin
export PATH=$PATH:$GOPATH/bin
export PATH=$PATH:$WANTEDLY_HOME/bin
export PATH=$PATH:/bin
export PATH=$PATH:/usr
export PATH=$PATH:/usr/bin
export PATH=$PATH:/usr/sbin
export PATH=$PATH:/usr/local/bin
export PATH=$PATH:/usr/local/sbin
export PATH=$PATH:/usr/texbin
export PATH=$PATH:/sbin
export PATH=$PATH:/opt/X11/bin
export PATH=$PATH:/Library/TeX/texbin
export PATH=/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH
export PATH=/Library/Internet\ Plug-Ins/JavaAppletPlugin.plugin/Contents/Home/bin:$PATH
export PATH=$HOME/.cargo/bin:$PATH

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
setopt dvorak

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

setopt share_history

### Usual Commands
## cd
# auto push when cd
setopt auto_pushd
# dont push dups
setopt pushd_ignore_dups 
# ls just after cd
function chpwd() { ls -FG }

## ls 
alias ls='/bin/ls -FG'
alias la='ls -FA'
alias ll='ls -Fl'
alias lla='ls -FlA'
# for dvorak
alias no='ls'
alias na='la'
alias nn='ll'
alias nna='lla'

## mkdir
alias mkdir='mkdir -p'

### Utility alias
alias zshrc='vim ~/.zshrc'
alias sourcerc='source ~/.zshrc'
alias vimrc='vim ~/.vimrc'
alias tmuxrc='vim ~/.tmux.conf'
alias wfstatus='networksetup -getairportpower en0'
alias wfon='networksetup -setairportpower en0 on'
alias wfoff='networksetup -setairportpower en0 off'
alias airport='/System/Library/PrivateFrameworks/Apple80211.framework/Versions/A/Resources/airport'
alias wfscan='airport scan'
alias wfset='networksetup -setairportnetwork en0'
alias wfname='networksetup -getairportnetwork en0'
alias globalip='curl -sL http://httpbin.org/ip | jq -r ".origin"'

function list-all-files {
  if git rev-parse 2> /dev/null; then
    git ls-files
  else
    find . -type f
  fi
}

function list-all-directories {
  find . -type d | grep -v './.git'
}

### Utility function
function man {
	vim -c ViewDocMan\ $1
}

# # extract
# function extract() {
# 	case $1 in
# 		*.tar.gz|*.tgz) tar xzvf $1;;
# 		*.tar.xz) tar Jxvf $1;;
# 		*.zip) unzip $1;;
# 		*.lzh) lha e $1;;
# 		*.tar.bz2|*.tbz) tar xjvf $1;;
# 		*.tar.Z) tar zxvf $1;;
# 		*.gz) gzip -d $1;;
# 		*.bz2) bzip2 -dc $1;;
# 		*.Z) uncompress $1;;
# 		*.tar) tar xvf $1;;
# 		*.arj) unarj $1;;
# 	esac
# }

alias -s {gz,tgz,zip,lzh,bz2,tbz,Z,tar,arj,xz}=extract

# tmux
if [ ! -z `which tmux` ]; then
	if [ $SHLVL = 1 ]; then
		if [ $(( `ps aux | grep tmux | grep $USER | grep -v grep | wc -l` )) != 0 ]; then
			echo -n 'Attach tmux session? [Y/n]'
			read YN
			[[ $YN = '' ]] && YN=y
			[[ $YN = y ]] && tmux attach
		fi
		echo -n 'No tmux session, create new? [Y/n]'
		read YN
		[[ $YN = '' ]] && YN=y
		[[ $YN = y ]] && tmux
	fi
fi

# Git
function git { hub "$@" }
function cam { git commit -am "$*" }
function com { git commit -m "$*" }
function CAM { git add -A && git commit -am "$*" }
function be { bundle exec "$*" }
function pr { pipenv run "$*" }

alias vim='nvim'
alias s='cd $(ghq list -p | peco)'
alias -g B='`git branch -a | peco --prompt "GIT BRANCH>" | head -n 1 | sed -e "s/^\*\s*//g"`'
alias -g LB='`git branch | peco --prompt "GIT BRANCH>" | head -n 1 | sed -e "s/^\*\s*//g"`'
alias -g RB='`git branch -a | peco --query "remotes/ " --prompt "GIT REMOTE BRANCH>" | head -n 1 | sed "s/^\*\s*//" | sed "s/remotes\/[^\/]*\/\(\S*\)//"`'
alias -g F='`list-all-files | peco --prompt "FILES>" | head -n 1 | sed -e "s/^\*\s*//g"`'
alias -g D='`list-all-directories | peco --prompt "DIRECTORIES>" | head -n 1 | sed -e "s/^\*\s*//g"`'

# zsh
ZSH_THEME="oh-my-zsh-custom-xxf/themes/xxf"
plugins=(git zsh-syntax-highlighting zsh-autosuggestions zsh-completions)
source $ZSH/oh-my-zsh.sh
autoload -U compinit && compinit

function peco-history-selection() {
    BUFFER=`fc -ln 0 | tail -r  | awk '!a[$0]++' | peco --query "$LBUFFER" | sed 's/\\n/\n/'`
    CURSOR=$#BUFFER
    zle reset-prompt
}

zle -N peco-history-selection
bindkey '^R' peco-history-selection

#  Anyenv
#-----------------------------------------------
if [ -d $HOME/.anyenv ]; then
  eval "$(anyenv init -)"
fi
eval "$(direnv hook zsh)"

export PATH=$HOME/bin:$PATH
