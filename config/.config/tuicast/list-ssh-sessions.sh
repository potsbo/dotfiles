#!/usr/bin/env bash
# List "<host> <session>" pairs across all SSH hosts.
#
# Each host is queried in parallel and results are streamed as they arrive, so
# fast hosts show up immediately and slow / unreachable hosts drop off after
# ConnectTimeout instead of blocking the whole list. Hosts that need interactive
# auth are skipped (BatchMode=yes).
#
# Output is consumed by tuicast's ssh-session view and split back into
# host + session by ssh-session-connect.sh.
set -u

while IFS= read -r host; do
  [ -n "$host" ] || continue
  (
    ssh -o ConnectTimeout=2 -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
      "$host" 'tmux list-sessions -F "#{session_name}" 2>/dev/null' 2>/dev/null \
    | while IFS= read -r session; do
        [ -n "$session" ] && printf '%s %s\n' "$host" "$session"
      done
  ) &
done < <(~/.config/tuicast/list-ssh-hosts.sh)

wait
