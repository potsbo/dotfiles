# Basic Config
export LANG=en_US.UTF-8 # kitty 上での日本語の表示のため
export LC_ALL=$LANG
export EDITOR=nvim

# PATH Base
export WANTEDLY_HOME=$HOME/.wantedly
export GOPATH=$HOME/.go


# PATH
export PATH=$HOME/bin:$PATH
## Build
export PATH=$PATH:$HOME/.local/bin # Created by `pipx`
if [ -n "$PIPX_BIN_DIR" ]; then; export PATH=$PATH:$PIPX_BIN_DIR; fi # poetry in codespaces
export PATH=$PATH:$GOPATH/bin
export PATH=$PATH:$HOME/.cargo/bin
## System
export PATH=$PATH:/bin               # cat, cp, ...
export PATH=$PATH:/sbin              # ping, ifconfig, ...
export PATH=$PATH:/usr/bin           # arch, top, ...
export PATH=$PATH:/usr/sbin          # chown, chroot, ...
export PATH=$PATH:/Applications/Docker.app/Contents/Resources/bin/
export RIPGREP_CONFIG_PATH=$HOME/.config/ripgrep/rc


ARCH=$(arch)
if [ "$ARCH" = "arm64" ]; then
  export PATH=/opt/homebrew/bin:$PATH
  export RUSTUP_HOME=$HOME/arm64/.rustup
  export CARGO_HOME=$HOME/arm64/.cargo
  if [ -f /Users/potsbo/arm64/.cargo/env ]; then
    source /Users/potsbo/arm64/.cargo/env
  fi
  export PATH=$CARGO_HOME/bin:$PATH
else
	export PATH=$PATH:/usr/local/bin
fi

# M1 Mac で amd64 の docker image を動かすため
export DOCKER_DEFAULT_PLATFORM=linux/amd64

autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}' # ignore case 
zstyle ':completion:*' ignore-parents parent pwd .. # don't complete current directory after ../
zstyle ':completion:*:sudo:*' command-path /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin /usr/X11R6/bin # complete commands after sudo
zstyle ':completion:*:processes' command 'ps x -o pid,s,args' # complete processes when using ps command

# Spell check
setopt correct
setopt dvorak

###setting
setopt no_beep
setopt interactive_comments
setopt share_history

## ls
if command -v gls &> /dev/null
then
	alias ls='gls --color --hyperlink=auto --classify'
fi
alias la='ls -A'
alias ll='ls -l'
alias lla='ls -lA'

# ls just after cd
function chpwd() { ls }

### Utility alias
alias zshrc='vim ~/.zshrc'
alias vimrc='vim ~/.config/nvim/init.lua'

# Git
function cam { git commit -am "$*" }
function com { git commit -m "$*" }
function CAM { git add -A && git commit -am "$*" }

alias vim='nvim'
alias -g LB="\`git for-each-ref --sort=-committerdate refs/heads/ --format=\"%(committerdate:relative) %09 %(refname:short) %09 %(contents:subject)\" | fzf --prompt 'GIT BRANCH>' | cut -d$'\t' -f2\`"
alias -g RB="\`git for-each-ref --sort=-committerdate --format=\"%(committerdate:relative) %09 %(refname:short) %09 %(contents:subject)\" | fzf --query 'origin/ ' --prompt 'GIT REMOTE BRANCH>'| cut -d$'\t' -f2 | sed 's/origin\///' \`"

export PATH="${AQUA_ROOT_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/aquaproj-aqua}/bin:$PATH"

if [ -d $HOME/.rbenv ]; then
	eval "$(rbenv init - zsh)"
fi
if [ -d $HOME/.nodenv ]; then
	eval "$(nodenv init -)"
fi
if [ -d $HOME/.pyenv ]; then
	eval "$(pyenv init -)"
fi
eval "$(direnv hook zsh)"

if type fzf &> /dev/null; then
  eval "$(fzf --zsh)"
fi

if type deno &> /dev/null; then
  eval "$(deno completions zsh)"
fi

# color setting like %{${fg[red]}%}
autoload -Uz colors && colors
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

	line_2="%(?.%{$fg[green]%}:).%{$fg[red]%}:()%{$reset_color%} %# "

	PROMPT=$'\n'${line_1}$'\n'${line_2}
}

autoload -Uz add-zsh-hook && add-zsh-hook precmd _update_prompt


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

_register_keycommand() {
  zle -N $2
  bindkey "$1" $2
}

_ghq_fzf() {
  local repo=$(ghq list | fzf --query="$LBUFFER")
  [ -z "$repo" ] && return

  BUFFER="cd $(ghq root)/$repo"
  zle accept-line
  zle reset-prompt
}

_register_keycommand "^]" _ghq_fzf

# for `go test -race ...`
export CGO_ENABLED=1

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/potsbo/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/potsbo/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/potsbo/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/potsbo/google-cloud-sdk/completion.zsh.inc'; fi

export PATH="$HOME/.ghcup/bin:$PATH"
export PATH="$HOME/.cabal/bin:$PATH"
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"
# export PATH="/opt/homebrew/anaconda3/bin:$PATH"  # commented out by conda initialize

# VSCode で emacs キーバインドを使うため
bindkey -e

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/opt/homebrew/anaconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/homebrew/anaconda3/etc/profile.d/conda.sh" ]; then
        . "/opt/homebrew/anaconda3/etc/profile.d/conda.sh"
    else
        export PATH="/opt/homebrew/anaconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

