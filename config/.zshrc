if [ -f "/opt/homebrew/bin/brew" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# compinit: zsh 補完システムの初期化
# -C: キャッシュ (~/.zcompdump) を使用し compaudit をスキップ（0.4秒→0.02秒）
# 新しい補完を追加した時は `compinit` を手動実行してキャッシュ再生成
autoload -Uz compinit && compinit -C
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

# ls just after cd
function chpwd() { ls }

### Utility alias
alias zshrc='nvim ~/.zshrc'
alias vimrc='nvim ~/.config/nvim/init.lua'

alias -g LB="\`git for-each-ref --sort=-committerdate refs/heads/ --format=\"%(committerdate:relative) %09 %(refname:short) %09 %(contents:subject)\" | fzf --prompt 'GIT BRANCH>' | cut -d$'\t' -f2\`"
alias -g RB="\`git for-each-ref --sort=-committerdate --format=\"%(committerdate:relative) %09 %(refname:short) %09 %(contents:subject)\" | fzf --query 'origin/ ' --prompt 'GIT REMOTE BRANCH>'| cut -d$'\t' -f2 | sed 's/origin\///' \`"

eval "$(direnv hook zsh)"

if type fzf &> /dev/null; then
  eval "$(fzf --zsh)"
fi

# 補完の遅延ロード: 初回 Tab 時に eval される（起動時間短縮のため）
# 各コマンドの補完関数を空で定義し、呼ばれた時に本物をロード
_lazy_load_completion() {
  local cmd=$1; shift
  eval "_${cmd}() { unfunction _${cmd}; $@; _${cmd} \"\$@\" }"
  compdef _${cmd} ${cmd}
}
if type deno &> /dev/null; then _lazy_load_completion deno 'eval "$(deno completions zsh)"'; fi
if type task &> /dev/null; then _lazy_load_completion task 'eval "$(task --completion zsh)"'; fi
if type gh &> /dev/null; then _lazy_load_completion gh 'eval "$(gh completion --shell zsh)"'; fi
if type git-wt &> /dev/null; then _lazy_load_completion git-wt 'eval "$(git wt --init zsh)"'; fi

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

_register_keycommand() {
  zle -N $2
  # mode を明示的に指定しないと C-] が tmux 環境で動かなかった
  bindkey -M emacs "$1" $2
}

_sesh_connect() {
  BUFFER="~/.config/tmux/sesh-connect.sh"
  zle accept-line
}

_register_keycommand "^]" _sesh_connect

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

# tmux detach 後に pending SSH があれば実行
_check_pending_ssh() {
  if [ -z "$TMUX" ] && [ -f /tmp/sesh-ssh-pending ]; then
    local host
    host=$(cat /tmp/sesh-ssh-pending)
    rm -f /tmp/sesh-ssh-pending
    if [ -n "$host" ]; then
      ssh "$host"
      # SSH 終了後、再度 sesh-connect.sh を呼ぶ
      if command -v sesh &> /dev/null; then
        ~/.config/tmux/sesh-connect.sh
      fi
    fi
  fi
}
precmd_functions+=(_check_pending_ssh)
