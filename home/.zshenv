# ~/.zshenv - 常に読まれる環境変数（非対話シェル、スクリプトでも）

# Locale
# https://www.gnu.org/software/gettext/manual/html_node/Locale-Environment-Variables.html
export LANG=C # default に寄せる
unset LC_ALL # LC_* が override されるのを防ぐ

# 日本語表示には C 以外が必要, ja_JP.UTF-8 vs en_US.UTF-8 は真剣に考えてない
export LC_CTYPE=en_US.UTF-8
# 英語系で Y->M->D の順に並ぶおそらく唯一の format
export LC_TIME=en_CA.UTF-8

if [ "$OSTYPE" = "linux-gnu" ]; then
  export LC_CTYPE=en_US.utf8
  export LC_TIME=en_CA.utf8
fi

export LC_NUMERIC=C
export LC_COLLATE=C # en_US.UTF-8 だと日本語が文字数以外全て同一視された。default に寄せる
export LC_MONETARY=C
export LC_MESSAGES=C

export EDITOR=nvim
export TERM=xterm-256color
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"
# XDG: $HOME に散らばる生成物を XDG 配下へ寄せる。
# 移動先は xdg-ninja (github.com/b3nj5m1n/xdg-ninja) が示すデファクトに従う。
# 各ツールとも $HOME 直下を決め打ちしており、下記変数が正規の変更手段。
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
export AWS_CONFIG_FILE="$XDG_CONFIG_HOME/aws/config"
export AWS_SHARED_CREDENTIALS_FILE="$XDG_CONFIG_HOME/aws/credentials"
# NPM_CONFIG_CACHE は home-manager (home.sessionVariables) に集約。
# 背景プロセス(npx製MCP等)にも継承させるため。詳細は nix/home.nix 参照。
export DOCKER_CONFIG="$XDG_CONFIG_HOME/docker"
export NODE_REPL_HISTORY="$XDG_STATE_HOME/node_repl_history"
export PYTHON_HISTORY="$XDG_STATE_HOME/python_history" # 効くのは Python 3.13+
export ZSH_EVALCACHE_DIR="$XDG_CACHE_HOME/zsh/evalcache"

# PATH
export PATH=$HOME/.local/state/nix/profiles/home-manager/home-path/bin:$PATH
export PATH=$HOME/bin:$PATH
## Build
# prepend: 自作の open/xdg-open ラッパーが system の xdg-open (nix) に勝つ必要がある
export PATH=$HOME/.local/bin:$PATH
if [ -n "$PIPX_BIN_DIR" ]; then; export PATH=$PATH:$PIPX_BIN_DIR; fi # poetry in codespaces
export PATH=$PATH:$HOME/go/bin
## System
export PATH=$PATH:/bin               # cat, cp, ...
export PATH=$PATH:/sbin              # ping, ifconfig, ...
export PATH=$PATH:/usr/bin           # arch, top, ...
export PATH=$PATH:/usr/sbin          # chown, chroot, ...
export PATH=$PATH:/Applications/Docker.app/Contents/Resources/bin/
export RIPGREP_CONFIG_PATH=$HOME/.config/ripgrep/rc

# M1 Mac で amd64 の docker image を動かすため
export DOCKER_DEFAULT_PLATFORM=linux/amd64

export PATH="${AQUA_ROOT_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/aquaproj-aqua}/bin:$PATH"
export AQUA_GLOBAL_CONFIG=${AQUA_GLOBAL_CONFIG:-}:${XDG_CONFIG_HOME:-$HOME/.config}/aquaproj-aqua/aqua.yaml
# Required to allow the `local` registry (e.g. macmon). After first checkout, run once:
#   aqua policy allow "$AQUA_POLICY_CONFIG"
export AQUA_POLICY_CONFIG=${XDG_CONFIG_HOME:-$HOME/.config}/aquaproj-aqua/aqua-policy.yaml

export CARGO_NET_GIT_FETCH_WITH_CLI=true

# https://github.com/golang/go/issues/42700
export GODEBUG=asyncpreemptoff=1

# for `go test -race ...`
export CGO_ENABLED=1

# HISTFILE は .zshrc で設定（/etc/zshrc の上書きに勝つため）
export SAVEHIST=100000
export HISTSIZE=100000

if [ -e $HOME/.nix-profile/etc/profile.d/nix.sh ]; then . $HOME/.nix-profile/etc/profile.d/nix.sh; fi
if [ -e $HOME/.nix-profile/etc/profile.d/hm-session-vars.sh ]; then . $HOME/.nix-profile/etc/profile.d/hm-session-vars.sh; fi

# --- forwarded ssh-agent: keep keys on the origin host, usable across herdr ---
# We ssh in with agent forwarding (ForwardAgent), so no private key lives here.
# But every ssh connection gets its own forwarded socket, and long-lived herdr
# panes keep the one they first saw — so after a reconnect their $SSH_AUTH_SOCK
# is stale and the agent looks gone. Fix: point a stable, machine-local symlink
# at a live socket and have every shell use that link. Every new shell repoints
# it (not just the login shell), so already-open herdr panes get a working agent
# again without touching their env.
# The link lives under $XDG_RUNTIME_DIR (per-machine, tmpfs) — never under ~/.ssh,
# which is a symlink into the shared dotfiles repo.
#
# ソケットの存在は生存を意味しない。接続が異常終了しても sshd 側のプロセスが
# 残っている間はソケットも残り、connect() は通るのに応答だけ返らない。これを
# 掴むと ssh-add も ssh も無期限に待つ (nixos-anywhere が内部の ssh-copy-id で
# 固まったのがこれ)。しかも張り替えた直後の「最新の」ソケットがこの状態のこと
# もある (クライアント側の TCP が片側だけ死んだとき) ので、張り替えのタイミング
# だけを直しても足りない。なので採用前に必ず一度問い合わせて確かめる。
# 生きた agent が一つも無ければ link を消して SSH_AUTH_SOCK も外す。固まるより
# 「agent が無い」で即失敗した方が、ForwardAgent 無しの ssh などに落とせる。
if [ -n "$SSH_CONNECTION" ]; then
  _stable_sock="${XDG_RUNTIME_DIR:-/tmp}/ssh-auth-sock"

  # 応答すれば 0。timeout が無い環境 (coreutils を入れていない素の macOS) では
  # 判定を諦めて採用する — 無応答を待たされる方がましで、無条件に鍵を失うより
  # 害が小さい。ssh-add の終了コードは 0=鍵あり 1=鍵ゼロ (どちらも生きている)、
  # 2=接続不可、124=timeout に殺された (=無応答)。
  _ssh_agent_alive() {
    local rc
    command -v timeout >/dev/null 2>&1 || return 0
    SSH_AUTH_SOCK=$1 timeout 1 ssh-add -l >/dev/null 2>&1
    rc=$?
    [ $rc -eq 0 ] || [ $rc -eq 1 ]
  }

  # 候補: 自分の接続のソケット → 今 link が指しているもの → 他の接続のソケット
  # (新しい順)。最後のものは、自分の接続の agent チャネルだけが死んで別セッション
  # のものは生きている、という実際に起きた状態からの復帰用。新しい方が生きている
  # 見込みは高いだけで確実ではない (前日のセッションだけが生きていた例がある)
  # ので、打ち切りは 8 個と広めに取る。応答しないソケットだけが 1 秒待たされ、
  # 相手のいない残骸は connect が即失敗するので、実際の待ち時間はほぼ増えない。
  # OpenSSH 10 は転送ソケットを ~/.ssh/agent に置く (それ以前は /tmp/ssh-*)。
  # 存在しなければ nullglob で候補が減るだけなので、古い OpenSSH でも壊れない。
  _live_sock=
  _tried=()
  for _cand in "$SSH_AUTH_SOCK" "$_stable_sock" ~/.ssh/agent/*(N=om[1,8]); do
    [ -S "$_cand" ] || continue
    # link とその実体は同じソケット。無応答なものを二度待たないよう解決して弾く。
    _real=${_cand:A}
    (( ${_tried[(Ie)$_real]} )) && continue
    _tried+=$_real
    _ssh_agent_alive "$_cand" || continue
    _live_sock=$_cand
    break
  done

  if [ -n "$_live_sock" ]; then
    [ "$_live_sock" = "$_stable_sock" ] || ln -sf "$_live_sock" "$_stable_sock"
    export SSH_AUTH_SOCK="$_stable_sock"
  else
    rm -f "$_stable_sock"
    unset SSH_AUTH_SOCK
  fi

  unset _stable_sock _live_sock _cand _tried _real
  unfunction _ssh_agent_alive
fi
