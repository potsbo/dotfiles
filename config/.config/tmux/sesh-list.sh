#!/usr/bin/env bash

set -eu

# Icons (nerdfont)
ICON_SSH=$(printf '\uEB3A')

# ghq repos that don't have a tmux session yet
ghq_repos_without_session() {
  local existing_sessions
  existing_sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null || true)

  ghq list --full-path | roots --depth 4 --root-file .git 2>/dev/null | while read -r repo; do
    local name
    name=$(~/.config/tmux/dirmux/path-to-name.sh "$repo")
    if ! echo "$existing_sessions" | grep --quiet --line-regexp --fixed-strings "$name"; then
      echo "$name"
    fi
  done
}

# SSH hosts from config (exclude github.com, *.github.com, etc.)
ssh_hosts() {
  {
    cat ~/.ssh/config 2>/dev/null
    cat ~/.ssh/config.d/* 2>/dev/null
  } | awk -v icon="$ICON_SSH" '/^Host / && $2 !~ /\*/ && $2 !~ /github\.com/ { print icon " " $2 }' | sort -u
}

# Recent SSH hosts from history (last 3 months)
ssh_history() {
  local three_months_ago
  three_months_ago=$(date -v-3m +%s 2>/dev/null || date -d '3 months ago' +%s)

  grep -a '^: [0-9]*:0;ssh ' ~/.zsh_history 2>/dev/null | awk \
    -v cutoff="$three_months_ago" \
    -v icon="$ICON_SSH" \
    '{
      split($0, a, ":")
      ts = a[2] + 0
      if (ts >= cutoff) {
        sub(/^: [0-9]*:0;ssh /, "")
        host = $1
        if (host !~ /^-/) hosts[host] = 1
      }
    }
    END { for (h in hosts) print icon " " h }' | sort -u
}

# Combine and dedupe SSH hosts
all_ssh_hosts() {
  {
    ssh_hosts
    ssh_history
  } | sort -u
}

# List everything
if [ -n "${SSH_CONNECTION:-}" ] && [ -z "${TMUX:-}" ]; then
  echo "🚪  Exit SSH"
fi
echo "🌿  New worktree"
sesh list --tmux --icons --hide-duplicates
ghq_repos_without_session
all_ssh_hosts
