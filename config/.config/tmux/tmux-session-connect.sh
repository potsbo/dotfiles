#!/usr/bin/env bash
# Create (if needed) and connect to a tmux session with consistent naming.
# This is the ONLY entry point for creating tmux sessions.
#
# Usage: tmux-session-connect.sh <working-directory>
set -eu

dir="$1"
session_name=$(~/.config/tmux/session-name.sh "$dir")

if ! tmux has-session -t "=$session_name" 2>/dev/null; then
  tmux new-session -d -c "$dir" -s "$session_name"
fi

if [ -n "${TMUX:-}" ]; then
  tmux switch-client -t "=$session_name"
else
  tmux attach-session -t "=$session_name"
fi
