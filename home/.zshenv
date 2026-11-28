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
# 背景プロセス(npx製MCP等)にも継承させるため。詳細は modules/home-manager/home.nix 参照。

# DOCKER_CONFIG は敢えて設定しない。docker の設定は ~/.docker のまま置く。
# Docker Desktop (mac) が ~/.docker を決め打ちで管理するので、この変数を立てると
# GUI が書く credsStore/context と CLI が読む config.json が食い違う。加えて
# .zshenv 経由では systemd unit や GUI ランチャに伝播せず、実際 nixos の
# docker-buildx-oci が ~/.docker/buildx に builder を作ってシェルから見えなくなった。

export NODE_REPL_HISTORY="$XDG_STATE_HOME/node_repl_history"
export PYTHON_HISTORY="$XDG_STATE_HOME/python_history" # 効くのは Python 3.13+
export ZSH_EVALCACHE_DIR="$XDG_CACHE_HOME/zsh/evalcache"

# PATH
# home-manager の profile。manage = system (flake.nix の hosts) なら NixOS / nix-darwin の
# モジュールとして当たるので per-user 配下、manage = home (standalone) なら ~/.nix-profile。
# 同じホストに両方あることは無いので、存在する方だけが効く。
export PATH=/etc/profiles/per-user/$USER/bin:$PATH
export PATH=$HOME/.nix-profile/bin:$PATH
export PATH=$HOME/bin:$PATH
## Build
# aqua は ~/.local/bin より後ろ: 手で置いた wrapper がパッケージマネージャの出力に勝つのが原則。
# 以前は aqua が先で、~/.local/bin/claude (native installer の symlink) が aqua の pin を隠していた。
export PATH="${AQUA_ROOT_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/aquaproj-aqua}/bin:$PATH"
export PATH=$HOME/.local/bin:$PATH
export PATH=$PATH:$HOME/go/bin
## System
export PATH=$PATH:/bin               # cat, cp, ...
export PATH=$PATH:/sbin              # ping, ifconfig, ...
export PATH=$PATH:/usr/bin           # arch, top, ...
export PATH=$PATH:/usr/sbin          # chown, chroot, ...
export PATH=$PATH:/Applications/Docker.app/Contents/Resources/bin/
# Rex はペインのシェルを起動する前に REX_BIN_DIR を PATH の先頭に足すが、nix-darwin の
# /etc/zshenv (set-environment) が PATH を丸ごと代入し直すので消える。Rex が意図した状態に戻す。
[[ -n ${REX_BIN_DIR:-} ]] && export PATH="$REX_BIN_DIR:$PATH"
export RIPGREP_CONFIG_PATH=$HOME/.config/ripgrep/rc

# M1 Mac で amd64 の docker image を動かすため
export DOCKER_DEFAULT_PLATFORM=linux/amd64

# aqua が読むのは repo の作業ツリーではなく store のコピー (modules/home-manager/aqua.nix)。
# 実体を編集したら rebuild するまで効かない。conflict した aqua.yaml で aqua 管理の
# コマンドが全部死ぬのを避けるため、意図的にそうしてある。
# 継ぎ足さずに代入する。継ぎ足すと、値がこの行の変更前から生きているプロセス
# (長生きの terminal や tmux) の下では古いパスが残り続け、aqua がそちら (作業ツリー側の
# aqua.yaml) からも install しようとする。policy の `path: registry.yaml` は policy
# ファイルの隣を指すので、作業ツリー側の local registry は許可されず install が落ちる。
# 入れ子の shell で同じパスが際限なく増えるのも防げる。
export AQUA_GLOBAL_CONFIG=${XDG_DATA_HOME:-$HOME/.local/share}/aqua-config/aqua.yaml
# Required to allow the `local` registry (e.g. macmon). After first checkout, run once:
#   aqua policy allow "$AQUA_POLICY_CONFIG"
export AQUA_POLICY_CONFIG=${XDG_DATA_HOME:-$HOME/.local/share}/aqua-config/aqua-policy.yaml

export CARGO_NET_GIT_FETCH_WITH_CLI=true

# https://github.com/golang/go/issues/42700
export GODEBUG=asyncpreemptoff=1

# for `go test -race ...`
export CGO_ENABLED=1

# HISTFILE / SAVEHIST / HISTSIZE は .zshrc で設定（/etc/zshrc の上書きに勝つため）

# macOS (multi-user nix)。インストーラに /etc/zshrc を書かせていないので、ここで読む。
# nix-darwin が /etc/zshenv で環境を組んだあとは読まない。nix-daemon.sh は installer が
# default profile に入れた nix (以後だれも更新しない) を PATH の先頭に足すので、
# nix-darwin が nixpkgs から入れて lock とともに上がる /run/current-system/sw/bin/nix が隠れる。
# 必要なのは nix-darwin を入れる前の初回 bootstrap と、nix-darwin の無い Linux (CI) だけ。
if [ -z "${__NIX_DARWIN_SET_ENVIRONMENT_DONE-}" ] && [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh; fi
if [ -e $HOME/.nix-profile/etc/profile.d/nix.sh ]; then . $HOME/.nix-profile/etc/profile.d/nix.sh; fi
# hm-session-vars.sh 冒頭の include guard (__HM_SESS_VARS_SOURCED) は「この process tree で
# 一度読んだ」しか見ない。マルチプレクサの server のような長寿命プロセスが起動時のガードを抱えていると、
# その下の新しい pane は ./install 後も古い値のままになる。そこでガードを「どの generation を
# 読んだか」に置き換え、実体の store path (中身が変われば変わる) が前回と違うときだけガードを
# 外して読み直す。
# - __HM_SESS_VARS_SOURCED は home-manager の非公開の名前。改名されたら unset が空振りして
#   元の「一度だけ」に戻るだけで、壊れはしない。
# - 読み直しで重なるのは追記型の変数 (XCURSOR_PATH) だけで、generation が変わるたびに 1 回。
# - server を systemd / launchd から起動してガードを持たせない案は、OS ごとに分かれるうえ、
#   remote-client-bridge が ssh 先で server を起動する経路まで塞ぐ必要があるので取らなかった。
# - 2 つとも在るホストでは先の方だけを読む (元のガード下でも後の方は読まれなかった)。
for _hm_vars in /etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh $HOME/.nix-profile/etc/profile.d/hm-session-vars.sh; do
  [ -e $_hm_vars ] || continue
  if [ "${__HM_SESS_VARS_GEN-}" != "${_hm_vars:A}" ]; then
    unset __HM_SESS_VARS_SOURCED
    . $_hm_vars
    export __HM_SESS_VARS_GEN=${_hm_vars:A}
  fi
  break
done
unset _hm_vars
