#!/usr/bin/env bash
# Keep an SSH window pinned to its target: "<host>" or "<host>:<session>".
#
# Two problems this solves when a window is "one task = one ssh":
#   1. After a disconnect you forget what the window was for.
#   2. A flaky network / moving around drops you back to the picker.
#
# So we:
#   - Set the terminal title to the target, re-asserting it on every disconnect,
#     so even a disconnected window still shows what it was for.
#   - Auto-reconnect when ssh drops on a *network* error. ssh reserves exit 255
#     for connection-level failures; an intentional logout / remote `tmux detach`
#     exits 0 (or the shell's own code). So: 255 -> wait + reconnect, anything
#     else -> the user meant to leave, return to the caller.
#   - Let Ctrl-C during the reconnect wait bail out to the caller.
#
# Usage: ssh-reconnect.sh <host> [session]
set -u

host="${1:?usage: ssh-reconnect.sh <host> [session]}"
session="${2:-}"

if [ -n "$session" ]; then
  label="${host}:${session}"
else
  label="$host"
fi

# OSC 0 sets both the icon name and window/tab title; BEL-terminated for the
# widest terminal support. The remote shell/tmux overwrites this while we are
# connected (which is what we want — live remote context); we re-assert our own
# label whenever the connection is gone.
set_title() { printf '\033]0;%s\007' "$1"; }

# Ctrl-C while we are waiting to reconnect: restore the plain label and leave.
trap 'set_title "$label"; printf "\n"; exit 0' INT

run_ssh() {
  if [ -n "$session" ]; then
    ssh -t "$host" "tmux new-session -A -s \"$session\""
  else
    ssh -t "$host"
  fi
}

set_title "$label"
while true; do
  run_ssh
  code=$?
  # 0 or any non-255 code => the user logged out / detached on purpose.
  [ "$code" -eq 255 ] || break

  set_title "$label · reconnecting…"
  printf '\033[33m[%s] disconnected (network). reconnecting… (Ctrl-C to stop)\033[0m\n' "$label"
  sleep 2
done

set_title "$label"
