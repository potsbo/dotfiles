#!/usr/bin/env bash

set -eu

# Icons (nerdfont)
ICON_GHQ=$(printf '\uEA84')
ICON_SSH=$(printf '\uEB3A')

# ghq repos that don't have a tmux session yet
ghq_repos_without_session() {
  local existing_sessions
  existing_sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null || true)

  ghq list --full-path | roots --depth 4 --root-file .git 2>/dev/null | while read -r repo; do
    local name="${repo##*/}"
    if ! echo "$existing_sessions" | grep -q -E "^${name}$"; then
      echo "$ICON_GHQ $(echo "$repo" | sed "s|^$HOME|~|")"
    fi
  done
}

# SSH hosts from config (exclude github.com, *.github.com, etc.)
ssh_hosts() {
  {
    cat ~/.ssh/config 2>/dev/null
    cat ~/.ssh/config.d/* 2>/dev/null
  } | grep '^Host ' \
    | awk '{print $2}' \
    | grep -v '\*' \
    | grep -v 'github\.com' \
    | sort -u \
    | while read -r host; do echo "$ICON_SSH $host"; done
}

# Recent SSH hosts from history (last 3 months)
ssh_history() {
  local three_months_ago
  three_months_ago=$(date -v-3m +%s 2>/dev/null || date -d '3 months ago' +%s)

  # zsh history format: ": timestamp:0;command"
  grep -a '^: [0-9]*:0;ssh ' ~/.zsh_history 2>/dev/null \
    | while IFS= read -r line; do
        ts=$(echo "$line" | cut -d':' -f2 | tr -d ' ')
        if [ "$ts" -ge "$three_months_ago" ] 2>/dev/null; then
          echo "$line" | sed 's/^: [0-9]*:0;ssh //' | awk '{print $1}'
        fi
      done \
    | grep -v '^-' \
    | sort -u \
    | while read -r host; do echo "$ICON_SSH $host"; done
}

# Combine and dedupe SSH hosts
all_ssh_hosts() {
  { ssh_hosts; ssh_history; } | sort -u
}

# List everything
list_all() {
  # If we're in an SSH session (remote), show exit option at the top
  if [ -n "${SSH_CONNECTION:-}" ] && [ -z "${TMUX:-}" ]; then
    echo "🚪  Exit SSH"
  fi
  sesh list --icons --hide-duplicates
  ghq_repos_without_session
  all_ssh_hosts
}

selected=$(
  list_all | fzf-tmux -p 100%,100% \
    --no-sort --ansi --border-label ' sesh ' --prompt '⚡  ' \
    --header '^q tmux kill' \
    --bind 'tab:down,btab:up' \
    --bind 'ctrl-q:execute(tmux kill-session -t {2..})+change-prompt(⚡  )+reload(sesh list --icons --hide-duplicates)' \
    --preview-window 'right:70%' \
    --preview 'sesh preview {}'
)

if [[ "$selected" == *"Exit SSH"* ]]; then
  # Signal to zshrc that we want to exit SSH
  touch /tmp/sesh-exit-ssh
  exit 0
elif [[ "$selected" == *"$ICON_GHQ"* ]]; then
  # Extract repo path from "$ICON_GHQ  ~/path/to/repo"
  repo=$(echo "$selected" | sed "s/.*$ICON_GHQ //" | sed "s|^~|$HOME|")
  name="${repo##*/}"

  # Create session and connect
  tmux new-session -d -c "$repo" -s "$name"
  if [ -n "${TMUX:-}" ]; then
    tmux switch-client -t "$name"
  else
    tmux attach-session -t "$name"
  fi
elif [[ "$selected" == *"$ICON_SSH"* ]]; then
  # Extract hostname from "$ICON_SSH  hostname"
  host=$(echo "$selected" | sed "s/.*$ICON_SSH //")

  if [ -n "${TMUX:-}" ]; then
    # Inside tmux: write host to temp file, then detach
    # zshrc will pick this up and ssh after detach
    echo "$host" > /tmp/sesh-ssh-pending
    tmux detach-client
  else
    # Outside tmux: just ssh directly
    exec ssh "$host"
  fi
else
  sesh connect "$selected"
fi
