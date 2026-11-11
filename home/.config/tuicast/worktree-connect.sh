#!/usr/bin/env bash
# Open a worktree path — the tuicast worktree view's run target:
#
#   from zsh  : hand the path back to cd into (TUICAST_CD_FILE, set by the
#               tuicast function in .zshrc)
#   otherwise : start a shell in the path (the .zprofile login picker)
set -eu

dir="$1"

# tuicast は子プロセスなので親シェルを cd できない。呼び出し元が受け口を
# 用意していればそこへ書き、cd は zsh 側でやる (サブシェルを積まない)。
# Rex の中でも session は作らず cd だけにする。
if [ -n "${TUICAST_CD_FILE:-}" ]; then
  printf '%s' "$dir" >"$TUICAST_CD_FILE"
  exit 0
fi

cd "$dir"
exec "${SHELL:-zsh}"
