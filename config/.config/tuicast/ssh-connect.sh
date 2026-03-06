#!/usr/bin/env bash
# Connect to an SSH host, handling the tmux detach-and-reconnect pattern.
set -eu

host="$1"

if [ -n "${TMUX:-}" ]; then
  # Inside tmux: write host to temp file, then detach.
  # zshrc picks this up and runs ssh after detach.
  echo "$host" >/tmp/sesh-ssh-pending
  tmux detach-client
else
  exec ssh "$host"
fi
