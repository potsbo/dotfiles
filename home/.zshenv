# ~/.zshenv - 常に読まれる環境変数（非対話シェル、スクリプトでも）

# Locale
# https://www.gnu.org/software/gettext/manual/html_node/Locale-Environment-Variables.html
export LANG=C # default に寄せる
unset LC_ALL # LC_* が override されるのを防ぐ

# 日本語表示には C 以外が必要, ja_JP.UTF-8 vs en_US.UTF-8 は真剣に考えてない
export LC_CTYPE=en_US.UTF-8
# 英語系で Y->M->D の順に並ぶおそらく唯一の format
export LC_TIME=en_CA.UTF-8

# LANG=C なので下は書かなくても C になるが、親プロセスから LC_* を継いだときに負けないよう明示する。
export LC_NUMERIC=C
export LC_COLLATE=C # en_US.UTF-8 だと日本語が文字数以外全て同一視された。default に寄せる
export LC_MONETARY=C
export LC_MESSAGES=C

export EDITOR=nvim
# home-manager の session vars は以下のどれよりも先に読む。XDG_*_HOME は home-manager
# (xdg.enable) が持ち、このファイルの残りはそれを前提に組む。
# hm-session-vars.sh の include guard には手を入れない。guard は process tree で一度しか
# 読ませないので、guard を継いだ長寿命プロセスの下では ./install 後も古い値が残る。
# 実際に継ぐのは Linux のデスクトップホストだけで、セッション起動 (niri-session、Hyprland の
# dbus-update-activation-environment --all) が guard ごと環境を systemd の user 環境に流す
# (2026-11-28 に phoenix で確認。Mac と非デスクトップの Linux では Rex server の環境に無い)。
# 以前は generation を見て guard を外し読み直していたが、反映が再ログイン待ちになるのは
# デスクトップの環境変数として普通の挙動なので、guard の内部の名前に依存する仕組みを捨てた。
# Rex の pane だけは古いままだと気づきにくいので、rex.service 側で guard を落としている
# (modules/home-manager/rex.nix)。
# 2 つとも在るホストでは先の方だけを読む。
for _hm_vars in /etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh $HOME/.nix-profile/etc/profile.d/hm-session-vars.sh; do
  [ -e $_hm_vars ] || continue
  . $_hm_vars
  break
done
unset _hm_vars

# XDG: $HOME に散らばる生成物を XDG 配下へ寄せる。
# 移動先は xdg-ninja (github.com/b3nj5m1n/xdg-ninja) が示すデファクトに従う。
# 各ツールとも $HOME 直下を決め打ちしており、下記変数が正規の変更手段。
export CARGO_HOME="$XDG_DATA_HOME/cargo"
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
# home-manager の profile (/etc/profiles/per-user/$USER/bin と ~/.nix-profile/bin) は
# 足さない。NixOS / nix-darwin が /etc/zshenv で組む PATH に両方とも入っている。
# aqua は ~/.local/bin より後ろ: 手で置いた wrapper がパッケージマネージャの出力に勝つのが原則。
# 以前は aqua が先で、~/.local/bin/claude (native installer の symlink) が aqua の pin を隠していた。
export PATH="$XDG_DATA_HOME/aquaproj-aqua/bin:$PATH"
export PATH=$HOME/.local/bin:$PATH
export PATH=$PATH:$HOME/go/bin
export PATH=$PATH:/Applications/Docker.app/Contents/Resources/bin/
# Rex はペインのシェルを起動する前に REX_BIN_DIR を PATH の先頭に足すが、nix-darwin の
# /etc/zshenv (set-environment) が PATH を丸ごと代入し直すので消える。Rex が意図した状態に戻す。
[[ -n ${REX_BIN_DIR:-} ]] && export PATH="$REX_BIN_DIR:$PATH"
export RIPGREP_CONFIG_PATH=$XDG_CONFIG_HOME/ripgrep/rc

export CARGO_NET_GIT_FETCH_WITH_CLI=true

# HISTFILE / SAVEHIST / HISTSIZE は .zshrc で設定（/etc/zshrc の上書きに勝つため）

# macOS (multi-user nix)。インストーラに /etc/zshrc を書かせていないので、ここで読む。
# nix-darwin が /etc/zshenv で環境を組んだあとは読まない。nix-daemon.sh は installer が
# default profile に入れた nix (以後だれも更新しない) を PATH の先頭に足すので、
# nix-darwin が nixpkgs から入れて lock とともに上がる /run/current-system/sw/bin/nix が隠れる。
# 必要なのは Mac で nix-darwin を入れる前の初回 bootstrap だけ。
# single-user nix の ~/.nix-profile/etc/profile.d/nix.sh は読まない: install は --daemon で入れ、
# NixOS も nix-darwin も single-user ではない。
if [ -z "${__NIX_DARWIN_SET_ENVIRONMENT_DONE-}" ] && [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh; fi
