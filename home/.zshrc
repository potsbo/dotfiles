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
# brew は「設定済み」と判断して何も出力せず、空のキャッシュができる。マルチプレクサの
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
# HISTFILE / SAVEHIST / HISTSIZE はここで設定する: システムの /etc/zshrc (NixOS /
# nix-darwin の生成物) が user .zshenv の後・この .zshrc の前に HISTFILE=$HOME/.zsh_history と
# SAVEHIST=HISTSIZE=2000 を代入してくるため、zshenv では負ける。
export HISTFILE="$XDG_STATE_HOME/zsh/history"
SAVEHIST=100000
HISTSIZE=100000
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
# clear(1) は macOS で -x でも履歴を消すため、画面だけ消す制御列を送る。
# 画面を片付けたあとに完了 activity だけ残らないよう、pane 内の状態も消す。
clear() {
  if [[ -t 1 ]]; then
    printf '\033[H\033[2J\033]7501;state=clear\033\\'
  fi
}

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
if type rex &> /dev/null; then _lazy_load_completion rex 'eval "$(rex completion zsh)"'; fi
if type uv &> /dev/null; then _lazy_load_completion uv 'eval "$(uv generate-shell-completion zsh)"'; fi
if type uvx &> /dev/null; then _lazy_load_completion uvx 'eval "$(uvx --generate-shell-completion zsh)"'; fi
if type rg &> /dev/null; then _lazy_load_completion rg 'eval "$(rg --generate complete-zsh)"'; fi
if type fd &> /dev/null; then _lazy_load_completion fd 'eval "$(fd --gen-completions zsh)"'; fi
# bat の出力は autoload 用の関数本体 (_bat を定義しない) なので、自分で _bat に包む。
if type bat &> /dev/null; then _lazy_load_completion bat 'eval "_bat() { $(bat --completion zsh) }"'; fi
if type yq &> /dev/null; then _lazy_load_completion yq 'eval "$(yq completion zsh)"'; fi
if type codex &> /dev/null; then _lazy_load_completion codex 'eval "$(codex completion zsh)"'; fi
if type copilot &> /dev/null; then _lazy_load_completion copilot 'eval "$(copilot completion zsh)"'; fi
if type hunk &> /dev/null; then _lazy_load_completion hunk 'eval "$(hunk completion zsh)"'; fi
if type fnm &> /dev/null; then _lazy_load_completion fnm 'eval "$(fnm completions --shell zsh)"'; fi
if type git-lfs &> /dev/null; then _lazy_load_completion git-lfs 'eval "$(git-lfs completion zsh)"'; fi
# cascp は scp のサブセットなので、zsh 同梱の scp の補完 (ssh 越しのリモートパスを含む) を
# そのまま使う。scp にしか無いオプションも候補に出るが、自前の補完を持つほどではない。
compdef cascp=scp

# fzf に host 色の外枠と host 名のラベルは付けない。以前は付けていたが、装飾が多いわりに、
# どの host かはシェルのプロンプトで足りる。

# starship (cache のみ、プロンプト表示に必要なので defer 不可)
_evalcache starship init zsh

# C-] で ghq の repo (worktree 含む) を選んで cd する。
# cd を widget の中で直接せず BUFFER に積んで accept-line するのは、precmd
# (direnv / starship) を通常のコマンドと同じく走らせるため。
# 表示は ~/src/github.com/ を GitHub アイコン (nf-cod-github, U+EA84) に、他の $HOME 配下を
# ~ に縮める。fzf には「表示 \t 実パス」を渡して表示列だけで検索させ、実パスを返させる。
# アイコンは locale に依らないようバイト列で書く。
_cd_repo() {
  local dir
  dir=$(ghq list --full-path | awk -v h="$HOME" -v gh=$'\356\252\204' '{
    l = $0
    if (index(l, h "/src/github.com/") == 1) l = gh " " substr(l, length(h "/src/github.com/") + 1)
    else if (index(l, h "/") == 1) l = "~" substr(l, length(h) + 1)
    print l "\t" $0
  }' | fzf --prompt 'cd> ' --delimiter '\t' --with-nth 1 --accept-nth 2) || { zle reset-prompt; return }
  BUFFER="cd ${(q)dir}"
  zle accept-line
}
zle -N _cd_repo
bindkey -M emacs "^]" _cd_repo

# VSCode で emacs キーバインドを使うため
bindkey -e

# Rex (iOS) は Ctrl+I を Tab (^I) でなく CSI u (ESC [105;5u) で送る。Tab と同じく補完にする
bindkey -M emacs "^[[105;5u" expand-or-complete

# ZLE の既定 clear-screen は clear 関数を通らないので、画面と activity の消去を共有する。
_clear_screen_and_activity() {
  clear
  zle .redisplay
}
zle -N clear-screen _clear_screen_and_activity

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
if ! command -v open &> /dev/null && command -v xdg-open &> /dev/null; then; alias open='xdg-open'; fi

# nvim を neorex に alias しない: neorex (v0.1) の中では、少なくとも ssh 先で
# yank が clipboard に入らず、ctrl-z で bg に回せない。同じ環境の素の nvim では
# どちらも動く。neorex を使うときは名前で呼ぶ。

# aqua: prompt 毎にパッケージをインストール（~50ms, バックグラウンド実行）
_aqua_install() {
  aqua install --all --only-link &>/dev/null &!
}
# precmd_functions+=() だと source ~/.zshrc のたびに重複登録されるので、
# 重複を弾く add-zsh-hook を使う。
autoload -Uz add-zsh-hook
add-zsh-hook precmd _aqua_install

rdp() {
  xfreerdp /v:"$1" /u:Administrator /p:"$(op read "op://Engineering/$1/password")" /f /bpp:32 /gfx:RFX /network:lan
}
