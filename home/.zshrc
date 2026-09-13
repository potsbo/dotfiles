# ~/.zshrc - 対話シェル用設定

# zsh-defer と evalcache で起動高速化 (home-manager が ghq 規約のパスに配置)
source ~/src/github.com/romkatv/zsh-defer/zsh-defer.plugin.zsh
source ~/src/github.com/mroth/evalcache/evalcache.plugin.zsh

# PATH / FPATH の重複除去。/etc/zprofile の path_helper と下の brew shellenv が
# 同じ entry を二重に積む。PATH のほうは path_helper 自身が潰すが、FPATH は
# 誰も潰さず 26 件のうち半分が重複していた。
typeset -U path fpath

# brew
# `brew shellenv` を毎回呼ぶと 84ms かかる (brew 本体が bash の大きなスクリプトで、
# さらに出力の中で /usr/libexec/path_helper を fork する)。出力をキャッシュする。
#
# 素の evalcache ではキャッシュが古くなっても気づけない。キャッシュキーがコマンド
# 文字列だけなので、Homebrew 側が出力を変えても無効化されない。そこで出力を決める
# ファイルの mtime を引数に混ぜてキーにする。evalcache は NAME=VALUE も含めて
# ハッシュを取るので、Homebrew が更新されればキーが変わって勝手に取り直す。
# 一度手で展開した値を置く案もあったが、ずれを doctor で人が確認する形になるので
# やめた (25ms の差より、同期が自動で保たれるほうを取る)。
#
# PATH= を前置するのは brew の no-op 対策。PATH の先頭が既に homebrew だと
# brew は「設定済み」と判断して何も出力せず、空のキャッシュができる。herdr の
# pane のように親から環境を継いだシェルで実際に起きる。
if [ -d "/opt/homebrew" ]; then
  zmodload -F zsh/stat b:zstat
  # zstat は + オプションを 1 つしか取らないので mtime だけ。更新されれば必ず動く。
  zstat -A _brew_key +mtime /opt/homebrew/Library/Homebrew/cmd/shellenv.sh /opt/homebrew/etc/paths
  _evalcache BREW_SHELLENV="${(j:-:)_brew_key}" PATH=/usr/bin:/bin /opt/homebrew/bin/brew shellenv zsh
  unset _brew_key
fi

# zsh が書き込む XDG ディレクトリ（history / zcompdump の親）を用意
mkdir -p "$XDG_STATE_HOME/zsh" "$XDG_CACHE_HOME/zsh"

# compinit: zsh 補完システムの初期化
# -C: キャッシュを使用し compaudit をスキップ（0.4秒→0.02秒）
# -d: zcompdump を XDG_CACHE_HOME 配下へ（$HOME を汚さない）
# 新しい補完を追加した時は `compinit` を手動実行してキャッシュ再生成
autoload -Uz compinit && compinit -C -d "$XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION"
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
# HISTFILE はここで設定する: システムの /etc/zshrc が user .zshenv の後・この
# .zshrc の前に HISTFILE=$HOME/.zsh_history を代入してくるため、zshenv では負ける。
export HISTFILE="$XDG_STATE_HOME/zsh/history"
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
alias -g LB="\`git for-each-ref --sort=-committerdate refs/heads/ --format=\"%(committerdate:relative) %09 %(refname:short) %09 %(contents:subject)\" | fzf --prompt 'GIT BRANCH>' | cut -d$'\t' -f2\`"
alias -g RB="\`git for-each-ref --sort=-committerdate --format=\"%(committerdate:relative) %09 %(refname:short) %09 %(contents:subject)\" | fzf --query 'origin/ ' --prompt 'GIT REMOTE BRANCH>'| cut -d$'\t' -f2 | sed 's/origin\///' \`"

# direnv (defer + cache)
zsh-defer _evalcache direnv hook zsh

# fzf (defer + cache)
if type fzf &> /dev/null; then
  zsh-defer _evalcache fzf --zsh
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
if type aqua &> /dev/null; then _lazy_load_completion aqua 'eval "$(aqua completion zsh)"'; fi
if type herdr &> /dev/null; then _lazy_load_completion herdr 'eval "$(herdr completion zsh)"'; fi

# host-colored frame so any fzf shows which host it runs on.
# hostname(1) ではなく $HOST を使う。zsh が起動時に持っている値で同じ文字列になり、
# fork が 1 回 (host-color) で済む (hostname の fork は 1 回 9ms かかっていた)。
thm_main=$(host-color "$HOST")
export FZF_DEFAULT_OPTS="--border --border-label \" $HOST \" --color=border:${thm_main},label:${thm_main}"

# color setting like %{${fg[red]}%}
autoload -Uz colors && colors

# starship (cache のみ、プロンプト表示に必要なので defer 不可)
_evalcache starship init zsh

# C-] で tuicast (worktree / ssh ピッカー)。herdr ペイン内では herdr 側の
# ctrl+] keybind が同じ tuicast を起動するので、内外どちらでも同じ体験になる
_tuicast_connect() {
  BUFFER="tuicast"
  zle accept-line
}
zle -N _tuicast_connect
bindkey -M emacs "^]" _tuicast_connect

# VSCode で emacs キーバインドを使うため
bindkey -e

# 古い macOS (HFS+) 由来のファイル名は NFD (分解形) で、濁点・半濁点が結合文字
# (U+3099/U+309A) として分離されている。例: 「パ」= U+30D1 (NFC) → U+30CF U+309A。
# これが 2 つの問題になる:
#   1. 補完後のファイル名で結合文字が分離表示される (テ<3099>ータ) → COMBINING_CHARS で解決
#   2. zsh の補完で NFC 入力 (「デ」) が NFD ファイル名にマッチしない → 未対応
#
# 2 は Tab 押下時に LBUFFER を NFD 化する widget で潰していたが、やめた。入力側を
# 曲げる対策は、NFD でないファイル名 (= 日常のほぼ全部) を巻き添えにする。実際、
# CIFS 経由の Windows 共有 (/srv/<VM>/<drive>) は NFC なので、「ド」を打った瞬間に
# ト+U+3099 へ変換されて 1 件もマッチしなくなっていた。しかも濁点のない文字だけなら
# 素通りするので、「たまに効く」形で原因が見えにくい。
#
# NFD が実際に出てくるのは Mac ローカルの古いファイルなので、必要になったら
# そちら側で狭く直す。
setopt COMBINING_CHARS

if ! command -v tailscale &> /dev/null; then; alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"; fi
if ! command -v pbcopy &> /dev/null && command -v wl-copy &> /dev/null; then; alias pbcopy='wl-copy'; fi
if ! command -v pbpaste &> /dev/null && command -v wl-paste &> /dev/null; then; alias pbpaste='wl-paste'; fi

# chafa は端末の正体を TERM から判定するが、ssh 越しだと xterm-256color に
# 落ちるため、ピクセルを送れる端末でも文字アート (symbols) に退避してしまい
# 荒い絵になる。使う端末はどれも kitty graphics を解するので明示する。
# 自動判定に任せたいときは chafa をそのまま呼べばよい。
alias img="chafa -f kitty"

# aqua: prompt 毎にパッケージをインストール（~50ms, バックグラウンド実行）
_aqua_install() {
  aqua install --all --only-link &>/dev/null &!
}
precmd_functions+=(_aqua_install)

rdp() {
  xfreerdp /v:"$1" /u:Administrator /p:"$(op read "op://Engineering/$1/password")" /f /bpp:32 /gfx:RFX /network:lan
}
