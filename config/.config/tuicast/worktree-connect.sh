#!/usr/bin/env bash
# Connect to the herdr space for a worktree path — the tuicast worktree view's
# run target, and the one place where herdr-inside/outside behavior forks:
#
#   inside herdr : focus the workspace rooted at the path (create it if needed)
#   outside      : same, but prepare it server-side and then attach; if no
#                  herdr server is up yet, start herdr from that directory
set -eu

dir="$1"

if [ -n "${HERDR_PANE_ID:-}" ]; then
  exec ~/.local/bin/herdr-space-connect "$dir"
fi

if ~/.local/bin/herdr-space-connect "$dir" 2>/dev/null; then
  exec herdr
else
  # herdr server がまだ無い: その dir から起動して最初の workspace にする
  cd "$dir"
  exec herdr
fi
