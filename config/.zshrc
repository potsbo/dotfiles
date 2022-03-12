# export
export LANG=en_US.UTF-8
export TERM="screen-256color"
export EDITOR=nvim
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

# PATH
export PATH=~/.anyenv/bin
export PATH=$PATH:$GOPATH/bin
export PATH=$PATH:$WANTEDLY_HOME/bin
export PATH=$PATH:/bin
export PATH=$PATH:/usr
export PATH=$PATH:/usr/bin
export PATH=$PATH:/usr/sbin
export PATH=$PATH:/usr/local/sbin
export PATH=$PATH:/usr/texbin
export PATH=$PATH:/sbin
export PATH=$PATH:/opt/X11/bin
export PATH=$PATH:/Library/TeX/texbin
export PATH=/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH
export PATH=/Library/Internet\ Plug-Ins/JavaAppletPlugin.plugin/Contents/Home/bin:$PATH
export PATH=$HOME/.cargo/bin:$PATH
export PATH=$HOME/.poetry/bin:$PATH
export PATH=$HOME/libexec:$PATH
export PATH=$HOME/bin:$PATH

ARCH=$(arch)
if [ "$ARCH" = "arm64" ]; then
	export PATH=/opt/homebrew/bin:$PATH
	export RUSTUP_HOME=$HOME/arm64/.rustup
	export CARGO_HOME=$HOME/arm64/.cargo
	source /Users/potsbo/arm64/.cargo/env
else
	export PATH=$PATH:/usr/local/bin
fi

# M1 Mac で amd64 の docker image を動かすため
export DOCKER_DEFAULT_PLATFORM=linux/amd64

bindkey -e
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
alias vimrc='vim ~/.vimrc'

### Utility function
function sedall() { ag -l $1 $3 | xargs sed -Ei '' s/$1/$2/g }

# tmux
if [ ! -z "`which tmux`" ]; then
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
function cam { git commit -am "$*" }
function com { git commit -m "$*" }
function CAM { git add -A && git commit -am "$*" }
function be { bundle exec "$*" }
function pr { pipenv run "$*" }

alias vim='nvim'
alias s='cd $(ghq list -p | peco)'
alias -g LB="\`git for-each-ref --sort=-committerdate refs/heads/ --format=\"%(committerdate:relative) %09 %(refname:short) %09 %(contents:subject)\" | peco --prompt 'GIT BRANCH>' --on-cancel error | cut -d$'\t' -f2\`"
alias -g RB="\`git for-each-ref --sort=-committerdate --format=\"%(committerdate:relative) %09 %(refname:short) %09 %(contents:subject)\" | peco --query 'origin/ ' --prompt 'GIT REMOTE BRANCH>' --on-cancel error| cut -d$'\t' -f2 | sed 's/origin\///' \`"

autoload -U compinit && compinit

#  Anyenv
#-----------------------------------------------
if [ -d $HOME/.anyenv ]; then
  eval "$(anyenv init -)"
fi
eval "$(direnv hook zsh)"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/potsbo/Downloads/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/potsbo/Downloads/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/potsbo/Downloads/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/potsbo/Downloads/google-cloud-sdk/completion.zsh.inc'; fi

autoload -Uz add-zsh-hook

_prompt_git_info() {
	# ref: https://joshdick.net/2017/06/08/my_git_prompt_for_zsh_revisited.html

	# Exit if not inside a Git repository
	! git rev-parse --is-inside-work-tree > /dev/null 2>&1 && return

	# Git branch/tag, or name-rev if on detached head
	local GIT_LOCATION=${$(git symbolic-ref -q HEAD || git name-rev --name-only --no-undefined --always HEAD)#(refs/heads/|tags/)}

	local AHEAD="%{$fg[red]%}⇡NUM%{$reset_color%}"
	local BEHIND="%{$fg[cyan]%}⇣NUM%{$reset_color%}"
	local MERGING="%{$fg[magenta]%}✖ %{$reset_color%}"
	local UNTRACKED="%{$fg[red]%}… %{$reset_color%}"
	local MODIFIED="%{$fg[yellow]%}✚ %{$reset_color%}"
	local STAGED="%{$fg[green]%}● %{$reset_color%}"
	local STASHED="%{$fg[cyan]%}⚑ %{$reset_color%}"

	local -a DIVERGENCES
	local -a FLAGS

	local NUM_AHEAD="$(git log --oneline @{u}.. 2> /dev/null | wc -l | tr -d ' ')"
	if [ "$NUM_AHEAD" -gt 0 ]; then
		DIVERGENCES+=( "${AHEAD//NUM/$NUM_AHEAD}" )
	fi

	local NUM_BEHIND="$(git log --oneline ..@{u} 2> /dev/null | wc -l | tr -d ' ')"
	if [ "$NUM_BEHIND" -gt 0 ]; then
		DIVERGENCES+=( "${BEHIND//NUM/$NUM_BEHIND}" )
	fi

	local NUM_STASHED="$(git stash list 2> /dev/null | wc -l | tr -d ' ')"
	if [ "$NUM_STASHED" -gt 0 ]; then
		FLAGS+=( "$STASHED" )
	fi

	if ! git diff --cached --quiet 2> /dev/null; then
		FLAGS+=( "$STAGED" )
	fi

	if ! git diff --quiet 2> /dev/null; then
		FLAGS+=( "$MODIFIED" )
	fi

	if [[ -n $(git ls-files --other --exclude-standard 2> /dev/null) ]]; then
		FLAGS+=( "$UNTRACKED" )
	fi

	local GIT_DIR="$(git rev-parse --git-dir 2> /dev/null)"
	if [ -n $GIT_DIR ] && test -r $GIT_DIR/MERGE_HEAD; then
		FLAGS+=( "$MERGING" )
	fi

	local -a GIT_INFO
	GIT_INFO+=( "%{$fg[grey]%}-" )
	[ -n "$GIT_STATUS" ] && GIT_INFO+=( "$GIT_STATUS" )
	[[ ${#DIVERGENCES[@]} -ne 0 ]] && GIT_INFO+=( "${(j::)DIVERGENCES}" )
	[[ ${#FLAGS[@]} -ne 0 ]] && GIT_INFO+=( "${(j::)FLAGS}" )
	GIT_INFO+=( "%{$fg_bold[cyan]%}$GIT_LOCATION%{$reset_color%}" )
	echo "${(j: :)GIT_INFO}"
}

_update_prompt() {
	local cwd=$(pwd | sed -e "s,^$HOME,~,")
	local gitinfo=$(_prompt_git_info)

	local line_1
	local line_2

	local host=${$(hostname)%".local"}
	line_1="%{$fg_bold[blue]%}${host}:%{$reset_color%}"

	if git rev-parse 2> /dev/null; then
		local repo=$(git rev-parse --show-toplevel | sed -e "s,$(ghq root)/,," | sed -e "s,^github.com/,,")
		local path=$(git rev-parse --show-prefix | sed -e "s,/$,,")
		line_1="${line_1}%{$fg_bold[blue]%}${repo}%{$reset_color%} %{$fg[blue]%}/${path}%{$reset_color%} ${gitinfo} "
	else
		line_1="${line_1}%{$fg[blue]%}${cwd}%{$reset_color%} "
	fi

	if [ -n "$(jobs)" ]; then
		line_1="${line_1}  %(1j,%{$fg[red]%}%j job%(2j,s,)%{$reset_color%},)"
	fi

	# Wantedly
	if [ -n "${KUBE_FORK_TARGET_ENV}" ]; then
		line_1="${line_1}  %{$fg[yellow]%}(fork: ${KUBE_FORK_TARGET_ENV})%{$reset_color%}"
	fi

	line_2="%(?.%{$fg[green]%}:).%{$fg[red]%}:()%{$reset_color%} %# "

	PROMPT=$'\n'${line_1}$'\n'${line_2}
}

add-zsh-hook precmd _update_prompt

# %* Current time of day in 24-hour format, with seconds.
# %D The date in yy-mm-dd format.

RPROMPT='%F{6}%D %*%f'
TMOUT=1
TRAPALRM() { zle -N reset-prompt }

export CARGO_NET_GIT_FETCH_WITH_CLI=true

# https://github.com/golang/go/issues/42700
export GODEBUG=asyncpreemptoff=1
export CGO_ENABLED=0
setopt HIST_IGNORE_ALL_DUPS
export HISTSIZE=100000
if command -v opam &> /dev/null
then
	eval "$(opam env)"
fi
