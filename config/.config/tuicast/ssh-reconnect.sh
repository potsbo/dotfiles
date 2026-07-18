#!/usr/bin/env bash
# Keep an SSH window pinned to its target host.
#
# Two problems this solves when a window is "one task = one ssh":
#   1. After a disconnect you forget what the window was for.
#   2. A flaky network / moving around drops you back to the picker.
#
# So we:
#   - Set the terminal title to the host, re-asserting it on every disconnect,
#     so even a disconnected window still shows what it was for.
#   - Auto-reconnect when ssh drops on a *network* error. ssh reserves exit 255
#     for connection-level failures; an intentional logout / remote detach
#     exits 0 (or the shell's own code). So: 255 -> wait + reconnect, anything
#     else -> the user meant to leave, return to the caller.
#   - Let Ctrl-C during the reconnect wait bail out to the caller.
#
# Usage: ssh-reconnect.sh <host>
set -u

host="${1:?usage: ssh-reconnect.sh <host>}"

# OSC 0 sets both the icon name and window/tab title; BEL-terminated for the
# widest terminal support. The remote shell overwrites this while we are
# connected (which is what we want — live remote context); we re-assert our own
# label whenever the connection is gone.
set_title() { printf '\033]0;%s\007' "$1"; }

# Ctrl-C while we are waiting to reconnect: clear the status line, restore the
# plain label and leave.
trap 'printf "\r\033[K"; set_title "$host"; exit 0' INT

# Wait for the host to come back, quietly. Instead of letting failed ssh
# attempts (and their "Could not resolve hostname…" noise) pile up line after
# line, we probe in the background and keep a single status line updated in
# place, then clear it once the host answers.
wait_for_network() {
  local start=$SECONDS spin='|/-\' i=0
  set_title "$host · waiting…"
  while true; do
    printf '\r\033[K\033[33m%s  %s disconnected — waiting for network (%ds, Ctrl-C to stop)\033[0m' \
      "${spin:i:1}" "$host" "$((SECONDS - start))"
    ssh -o ConnectTimeout=4 -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
      "$host" true 2>/dev/null && break
    i=$(((i + 1) % 4))
    sleep 1
  done
  printf '\r\033[K'   # erase the status line; the reconnect takes over the screen
}

set_title "$host"
while true; do
  ssh -t "$host"
  code=$?
  # 0 or any non-255 code => the user logged out / detached on purpose.
  [ "$code" -eq 255 ] || break
  wait_for_network
done

set_title "$host"
