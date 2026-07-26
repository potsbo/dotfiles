#!/usr/bin/env bash
# Connect to an SSH host, handling the herdr detach-and-reconnect pattern
# (same shape as the old tmux flow).
#
# Inside herdr the remote host's own herdr would draw nested inside the local
# pane, so we want the local client out of the way first. herdr has no
# client-detach API, but its client quits gracefully (terminal restored,
# server untouched) on SIGINT via its ctrl-c handler — and a detached server
# is exactly what prefix+d leaves behind. So: stash the target, SIGINT the
# attached client(s); the login-shell wrapper in .zprofile picks up the
# pending file, runs the ssh full-screen, and re-attaches herdr afterwards.
set -eu

host="$1"

if [ -z "${HERDR_PANE_ID:-}" ]; then
  exec ~/.config/tuicast/ssh-reconnect.sh "$host"
fi

echo "$host" >/tmp/herdr-ssh-pending

# Attached clients on this machine: a herdr process with a controlling tty
# whose argv is an attach form (`herdr`, `herdr --session x`) — not the server
# daemon, not transient `herdr <subcommand>` CLI calls. If several windows are
# attached they all detach; the first wrapper to consume the pending file runs
# the ssh and the rest just re-attach.
ps -eo pid=,tty=,args= \
  | awk '$2 != "?" && $3 ~ /(^|\/)herdr[^ ]*$/ && ($4 == "" || $4 ~ /^--/) && $0 !~ / server / { print $1 }' \
  | xargs -r kill -INT
