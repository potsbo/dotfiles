#!/usr/bin/env bash

set -eu

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
    | sed 's/^/🖥️  SSH: /'
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
    | sed 's/^/🖥️  SSH: /'
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
elif [[ "$selected" == *"SSH:"* ]]; then
  # Extract hostname from "🖥️  SSH: hostname"
  host=$(echo "$selected" | sed 's/.*SSH: //')

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
