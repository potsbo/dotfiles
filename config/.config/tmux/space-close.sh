#!/usr/bin/env bash
# Close the "space" for a working directory and move to another directory's
# space. Counterpart of space-connect.sh: same single entry point that Does The
# Right Thing under herdr or tmux. Used by the worktree-teardown flow (git close).
#
# Usage: space-close.sh <directory-to-close> <directory-to-move-to>
set -eu

dir="$1"
fallback="$2"

if [ -n "${HERDR_PANE_ID:-}" ]; then
  workspace=$(herdr pane list | jq -r --arg p "$dir" \
    'first(.result.panes[] | select(.cwd == $p) | .workspace_id) // empty')
  ~/.local/bin/herdr-space-connect "$fallback"
  if [ -n "$workspace" ]; then
    herdr workspace close "$workspace"
  fi
  exit 0
fi

# tmux の外にいるなら閉じるべき space は無い
if [ -z "${TMUX:-}" ]; then
  exit 0
fi

session=$(~/.config/tmux/dirmux/path-to-name.sh "$dir")
~/.config/tmux/tmux-session-connect.sh "$fallback"
# 自分が属する session を kill するのでこれが最後の行
tmux kill-session -t "=$session"
