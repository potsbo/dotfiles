#!/usr/bin/env bash
# Connect directly to a tmux session on a remote SSH host.
# Usage: ssh-session-connect.sh <host> <session...>
#
# Mirrors ssh-connect.sh's detach-and-reconnect pattern, but also carries the
# target session so .zshrc's _check_pending_ssh can attach to it after detach.
# The pending file is two lines: host, then session (session line is empty for
# the plain host-only ssh-connect.sh path).
set -eu

host="$1"
shift
session="$*"

if [ -n "${TMUX:-}" ]; then
  # Inside tmux: stash host + session, then detach. zshrc picks this up after
  # the client detaches and runs ssh.
  {
    printf '%s\n' "$host"
    printf '%s\n' "$session"
  } >/tmp/sesh-ssh-pending
  tmux detach-client
else
  exec ssh -t "$host" "tmux new-session -A -s \"$session\""
fi
