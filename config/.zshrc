# Basic Config
export LANG=en_US.UTF-8 # kitty 上での日本語の表示のため
export LC_ALL=$LANG
export EDITOR=nvim
export TERM=xterm-256color
export XDG_CONFIG_HOME="$HOME/.config"

# PATH
export PATH=$HOME/bin:$PATH
## Build
export PATH=$PATH:$HOME/.local/bin # Created by `pipx`
if [ -n "$PIPX_BIN_DIR" ]; then; export PATH=$PATH:$PIPX_BIN_DIR; fi # poetry in codespaces
export PATH=$PATH:$HOME/go/bin
export PATH=$PATH:$HOME/.cargo/bin
## System
export PATH=$PATH:/bin               # cat, cp, ...
export PATH=$PATH:/sbin              # ping, ifconfig, ...
export PATH=$PATH:/usr/bin           # arch, top, ...
export PATH=$PATH:/usr/sbin          # chown, chroot, ...
export PATH=$PATH:/Applications/Docker.app/Contents/Resources/bin/
export RIPGREP_CONFIG_PATH=$HOME/.config/ripgrep/rc

if [ -f "/opt/homebrew/bin/brew" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
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

# history
setopt append_history
setopt share_history
setopt inc_append_history
setopt inc_append_history_time
setopt hist_ignore_all_dups
unsetopt hist_no_store
unsetopt hist_ignore_dups
unsetopt hist_find_no_dups

export HISTFILE="${HOME}/.zsh_history"
export SAVEHIST=100000
export HISTSIZE=100000


## ls
if command -v gls &> /dev/null
then
	alias ls='gls --color --hyperlink=auto --classify'
fi

# ls just after cd
function chpwd() { ls }

### Utility alias
alias zshrc='nvim ~/.zshrc'
alias vimrc='nvim ~/.config/nvim/init.lua'

alias -g LB="\`git for-each-ref --sort=-committerdate refs/heads/ --format=\"%(committerdate:relative) %09 %(refname:short) %09 %(contents:subject)\" | fzf --prompt 'GIT BRANCH>' | cut -d$'\t' -f2\`"
alias -g RB="\`git for-each-ref --sort=-committerdate --format=\"%(committerdate:relative) %09 %(refname:short) %09 %(contents:subject)\" | fzf --query 'origin/ ' --prompt 'GIT REMOTE BRANCH>'| cut -d$'\t' -f2 | sed 's/origin\///' \`"

export PATH="${AQUA_ROOT_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/aquaproj-aqua}/bin:$PATH"
export AQUA_GLOBAL_CONFIG=~/aqua.yaml

eval "$(direnv hook zsh)"

if type fzf &> /dev/null; then
  eval "$(fzf --zsh)"
fi

if type deno &> /dev/null; then
  eval "$(deno completions zsh)"
fi

if type task &> /dev/null; then
  eval "$(task --completion zsh)"
fi

if type gh &> /dev/null; then
  eval "$(gh completion --shell zsh)"
fi


case $(hostname) in
"tigerlake")
thm_main=yellow
;;
"raptorlake")
thm_main=white
;;
"staten.local")
thm_main=blue
;;
*)
thm_main=gray
;;
esac

# color setting like %{${fg[red]}%}
autoload -Uz colors && colors

eval "$(starship init zsh)"

export CARGO_NET_GIT_FETCH_WITH_CLI=true

# https://github.com/golang/go/issues/42700
export GODEBUG=asyncpreemptoff=1

_register_keycommand() {
  zle -N $2
  # mode を明示的に指定しないと C-] が tmux 環境で動かなかった
  bindkey -M emacs "$1" $2
}

_tm() {
  tm
}

_lazygit() {
  lazygit
}

_register_keycommand "^]" _tm
_register_keycommand "^g" _lazygit

# for `go test -race ...`
export CGO_ENABLED=1

if command -v mise &> /dev/null; then
  eval "$(mise activate zsh)"
  eval "$(mise completion zsh)"
  eval "$(mise hook-env -s zsh)"
fi


# VSCode で emacs キーバインドを使うため
bindkey -e

if ! command -v tailscale &> /dev/null; then; alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"; fi
if ! command -v pbcopy &> /dev/null && command -v wl-copy &> /dev/null; then; alias pbcopy='wl-copy'; fi
if ! command -v pbpaste &> /dev/null && command -v wl-paste &> /dev/null; then; alias pbpaste='wl-paste'; fi


if [[ -e /proc/version ]] && grep -qEi "(Microsoft|WSL)" /proc/version; then
  "$(ghq root)/github.com/potsbo/dotfiles/script/fix-wl-copy.sh"
fi

# 自動で tmux に入ったり出たりする
# if TMUX is empty
if [ -z "$TMUX" ] && command -v tm &> /dev/null; then
  tm "$(ghq root)/github.com/potsbo/dotfiles"
fi
