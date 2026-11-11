#!/usr/bin/env bash
# Connect to an SSH host from the tuicast ssh view.
#
# Rex 内では 1 ホスト = 1 Rex ウィンドウにする。外では今の端末でそのまま繋ぐ。
set -eu

host="$1"

if [ -n "${REX_SESSION:-}" ]; then
  exec ~/.config/tuicast/rex-window.sh "$host" "$HOME" ~/.config/tuicast/ssh-reconnect.sh "$host"
fi

exec ~/.config/tuicast/ssh-reconnect.sh "$host"
