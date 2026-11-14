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
# cascp は scp のサブセットなので、zsh 同梱の scp の補完 (ssh 越しのリモートパスを含む) を
# そのまま使う。scp にしか無いオプションも候補に出るが、自前の補完を持つほどではない。
compdef cascp=scp

# host-colored frame so any fzf shows which host it runs on.
# hostname(1) ではなく $HOST を使う。zsh が起動時に持っている値で同じ文字列になり、
# fork が 1 回 (host-color) で済む (hostname の fork は 1 回 9ms かかっていた)。
thm_main=$(host-color "$HOST")
export FZF_DEFAULT_OPTS="--border --border-label \" $HOST \" --color=border:${thm_main},label:${thm_main}"

# color setting like %{${fg[red]}%}
autoload -Uz colors && colors

# starship (cache のみ、プロンプト表示に必要なので defer 不可)
_evalcache starship init zsh

# worktree を選んだら今のシェルで cd する。受け渡しは worktree-connect.sh 参照。
#
# Rex の中では floating pane に出し、選んだアプリ (lazygit, nvim 等) もその中で
# 動かす。herdr の popup と違って選択結果は session 切替ではなくこのシェルの cd
# なので、このシェルは pane が閉じるまで待つ (アプリを使っている間もブロック)。
# pane は Rex サーバーの環境 + login profile で起動するため、このシェルで export
# したもの (direnv / nix develop / venv) は中のアプリに引き継がれない。
# 選択だけ floating でやって実行はこのシェルに戻す案もあったが、まず全部 floating
# で試している。
tuicast() {
  if [[ -n ${REX_SESSION:-} && -n ${REX_BLOCK:-} && -x ${REX_BIN_DIR:-}/rex ]]; then
    _tuicast_cd _tuicast_float "$@"
  else
    _tuicast_cd _tuicast_inline "$@"
  fi
}

# tuicast からは今どこにいるかが見えないので、cwd を fzf の ghost (未入力時の薄い文字) に
# 出す。header / 枠ラベル / prompt も試したが、ghost は行を増やさず、打ち始めたら消えて
# 検索の邪魔をしない。prompt と同じ行を取り合うので prompt は既定の短いままにしておく。
# FZF_DEFAULT_OPTS は zshrc 時点の値で固定なので、cwd は起動のたびに足す。
# 表記は worktree 一覧の行と同じ path-label にして、一覧と見比べられるようにする。
_tuicast_fzf_opts() {
  local p
  p=$(~/.local/bin/path-label "$PWD")
  print -r -- "$FZF_DEFAULT_OPTS --ghost=${(qq)p}"
}

_tuicast_inline() {
  local f=$1; shift
  TUICAST_CD_FILE=$f FZF_DEFAULT_OPTS=$(_tuicast_fzf_opts) command tuicast "$@"
}

# $1 の runner に受け口のファイルを渡し、書かれた dir へこのシェルで cd する。
_tuicast_cd() {
  local runner=$1 f dir; shift
  f=$(mktemp) || return
  "$runner" "$f" "$@"
  dir=$(<"$f")
  rm -f "$f"
  [[ -n $dir ]] && cd "$dir"
}

_tuicast_float() {
  local f=$1; shift
  local rex=$REX_BIN_DIR/rex win req block typeahead tty_state
  # floating pane にフォーカスが移るまで (C-] 直後) に打った文字は、この pane の tty に
  # 溜まってエコーされ、tuicast の検索語に入らない。エコーを止めて非 canonical にして
  # おき、pane ができたら届いた分を送り直す。起動を速くしても Rex の API 往復と
  # フォーカス移動の間は必ず残るので、速度ではなく転送で塞ぐ。
  tty_state=$(stty -g 2>/dev/null)
  [[ -n $tty_state ]] && stty -echo -icanon min 0 time 0 2>/dev/null
  {
    win=$("$rex" block inspect -s "$REX_SESSION" "$REX_BLOCK" --json | jq -er '.block.window_id') || return
    # quick_exit_threshold_ms=0: Rex は即失敗した pane を開いたままにするが、tuicast
    # 自身が失敗時に画面を残すので二重になる。Esc での即キャンセルでも閉じたい。
    # floating の pane は Rex サーバーの環境で起動し、このシェルの FZF_DEFAULT_OPTS が
    # 届かないので、command の env で明示的に渡す。
    req=$(jq -n --arg s "$REX_SESSION" --arg w "$win" --arg cwd "$PWD" --arg f "$f" \
      --arg fzf "$(_tuicast_fzf_opts)" '{
      session_id: $s, window_id: $w, bounds: [0.05, 0.05, 0.9, 0.9], focus: true,
      layout: {block: {flavor: "com.superlogical.terminal.shell", label: "tuicast", options: {
        cwd: $cwd,
        command: (["env", "TUICAST_CD_FILE=\($f)", "FZF_DEFAULT_OPTS=\($fzf)", "tuicast"] + $ARGS.positional),
        exit: {quick_exit_threshold_ms: 0}
      }}}}' --args "$@") || return
    block=$("$rex" api call -s "$REX_SESSION" session.new_layer "$req" | jq -er '.block_ids[0]') || return
    {
      setopt local_options no_monitor no_notify
      "$rex" wait -s "$REX_SESSION" "$block" >/dev/null 2>&1 &
      local waiter=$! i
      if [[ -n $tty_state ]]; then
        # API が返っても、クライアントが打鍵の宛先を切り替えるのはフォーカス変更の
        # イベントが届いてから。その間の文字は読み出しの後にもこちらへ来るので、
        # 一度読んで終わりではなく、最初の 2 秒は来たぶんを送り続ける。それ以降も
        # 続けると、元の pane に戻って打った文字まで floating に飛ぶので止める。
        stty min 0 time 1 2>/dev/null # dd を最大 0.1 秒で返す
        for i in {1..20}; do
          kill -0 $waiter 2>/dev/null || break
          # 末尾の x は $(...) に末尾改行を削らせないため。
          typeahead=$(dd bs=4096 count=1 2>/dev/null; print -n x)
          typeahead=${typeahead%x}
          [[ -n $typeahead ]] && print -rn -- "$typeahead" | "$rex" send -s "$REX_SESSION" -b "$block" >/dev/null 2>&1
        done
      fi
      wait $waiter
    } always {
      # 待っている側を Ctrl-C したら floating も畳む (cd 先を返す相手がいなくなるため)。
      # 正常終了ならもう閉じていて失敗するだけなので、条件を付けずに呼ぶ。
      "$rex" block close -s "$REX_SESSION" "$block" >/dev/null 2>&1
    }
  } always {
    [[ -n $tty_state ]] && stty "$tty_state" 2>/dev/null
  }
}

# C-] で tuicast (worktree / ssh ピッカー)
_tuicast_connect() {
  BUFFER="tuicast"
  zle accept-line
}
zle -N _tuicast_connect
bindkey -M emacs "^]" _tuicast_connect

# VSCode で emacs キーバインドを使うため
bindkey -e

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

# chafa は端末の正体を TERM から判定するが、ssh 越しだと xterm-256color に
# 落ちるため、ピクセルを送れる端末でも文字アート (symbols) に退避してしまい
# 荒い絵になる。使う端末はどれも kitty graphics を解するので明示する。
# 自動判定に任せたいときは chafa をそのまま呼べばよい。
# 名前は kitty 公式 (`alias icat="kitten icat"`) に合わせる。
alias icat="chafa -f kitty"

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

# Rex で新しく開いた端末 (tab / 分割 / floating) では最初に tuicast を出す。Esc で
# 素のシェルになる。Rex の外は .zprofile が出す。ここでは floating に重ねず pane の中で
# 開く: 開いたばかりの pane の上にさらに pane を出す意味がなく、選んだ dir にこの
# シェルで cd できる。login に限るのは、worktree-connect.sh の exec zsh や手で打った
# zsh で再び出さないため (Rex は pane のシェルを login で起動する)。
if [[ -n ${REX_SESSION:-} ]] && [[ -o login ]] && [[ -o interactive ]] && [[ -t 0 ]] && (( $+commands[tuicast] )); then
  _tuicast_cd _tuicast_inline
fi
