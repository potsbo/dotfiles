#!/usr/bin/env bash
# Connect to the "space" for a working directory: a herdr workspace when we are
# running inside herdr, otherwise a tmux session. Single entry point used by the
# worktree-creation flows (git tree, worktree-new.sh, tuicast) so the same
# command Does The Right Thing under either multiplexer.
#
# Usage: space-connect.sh <working-directory>
set -eu

dir="$1"

if [ -n "${HERDR_PANE_ID:-}" ]; then
  exec ~/.local/bin/herdr-space-connect "$dir"
else
  exec ~/.config/tmux/tmux-session-connect.sh "$dir"
fi
