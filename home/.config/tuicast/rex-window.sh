#!/usr/bin/env bash
# Focus (or create) the Rex window labeled LABEL in the current Rex session —
# Rex's counterpart of herdr-space-connect, used by the tuicast run scripts
# when they run inside a Rex pane.
#
# Rex's block/window listings carry no cwd, so unlike herdr-space-connect the
# window is keyed off its label, not the directory. The lookup is an exact
# match on `window ls --json`: `rex focus LABEL` also accepts ID suffixes and
# block labels, which could land on an unrelated window.
#
# rex is not on PATH inside Rex panes; Rex exports REX_BIN_DIR instead.
#
# Usage: rex-window.sh <label> <cwd> [command...]
set -euo pipefail

label="$1"
dir="$2"
shift 2
rex="$REX_BIN_DIR/rex"

win=$("$rex" window ls -s "$REX_SESSION" --json | jq -r --arg l "$label" \
  'first(.windows[] | select(.label == $l) | .window_id) // empty')

if [ -n "$win" ]; then
  exec "$rex" focus -s "$REX_SESSION" "$win"
fi

if [ $# -eq 0 ]; then
  exec "$rex" window new -s "$REX_SESSION" -c "$dir" "$label" >/dev/null
fi
exec "$rex" window new -s "$REX_SESSION" -c "$dir" "$label" -- "$@" >/dev/null
