#!/usr/bin/env bash

set -eu

# Icons (nerdfont)
ICON_GHQ=$(printf '\uEAC4')
ICON_SSH=$(printf '\uEB3A')
ICON_GITHUB=$(printf '\uF09B')

# Host-specific color (same as style.tmux)
case $(hostname) in
"tigerlake")    COLOR_MAIN="#fd971f" ;;  # yellow
"raptorlake")   COLOR_MAIN="#f8f8f2" ;;  # white
"staten.local") COLOR_MAIN="#ae81ff" ;;  # purple
"phoenix")      COLOR_MAIN="#d7875f" ;;  # orange
*)              COLOR_MAIN="#797979" ;;  # gray
esac

# Shorten path for display
shorten_path() {
  sed "s|$HOME|~|g" | sed "s|~/src/github.com|$ICON_GITHUB |g"
}

# Restore shortened path
restore_path() {
  sed "s|$ICON_GITHUB |~/src/github.com|g" | sed "s|~|$HOME|g"
}

# ghq repos that don't have a tmux session yet
ghq_repos_without_session() {
  local existing_sessions
  existing_sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null || true)

  ghq list --full-path | roots --depth 4 --root-file .git 2>/dev/null | while read -r repo; do
    local name
    name=$(~/.config/tmux/session-name.sh "$repo")
    if ! echo "$existing_sessions" | grep -qF "$name"; then
      echo "$ICON_GHQ $repo"
    fi
  done
}

# SSH hosts from config (exclude github.com, *.github.com, etc.)
ssh_hosts() {
  {
    cat ~/.ssh/config 2>/dev/null
    cat ~/.ssh/config.d/* 2>/dev/null
  } | grep '^Host ' |
    awk '{print $2}' |
    grep -v '\*' |
    grep -v 'github\.com' |
    sort -u |
    while read -r host; do echo "$ICON_SSH $host"; done
}

# Recent SSH hosts from history (last 3 months)
ssh_history() {
  local three_months_ago
  three_months_ago=$(date -v-3m +%s 2>/dev/null || date -d '3 months ago' +%s)

  # zsh history format: ": timestamp:0;command"
  grep -a '^: [0-9]*:0;ssh ' ~/.zsh_history 2>/dev/null |
    while IFS= read -r line; do
      ts=$(echo "$line" | cut -d':' -f2 | tr -d ' ')
      if [ "$ts" -ge "$three_months_ago" ] 2>/dev/null; then
        echo "$line" | sed 's/^: [0-9]*:0;ssh //' | awk '{print $1}'
      fi
    done |
    grep -v '^-' |
    sort -u |
    while read -r host; do echo "$ICON_SSH $host"; done
}

# Combine and dedupe SSH hosts
all_ssh_hosts() {
  {
    ssh_hosts
    ssh_history
  } | sort -u
}

# List everything
list_all() {
  # If we're in an SSH session (remote), show exit option at the top
  if [ -n "${SSH_CONNECTION:-}" ] && [ -z "${TMUX:-}" ]; then
    echo "🚪  Exit SSH"
  fi
  echo "🌿  New worktree"
  sesh list --icons --hide-duplicates
  ghq_repos_without_session
  all_ssh_hosts
}

selected=$(
  list_all | shorten_path | fzf-tmux -p 100%,100% \
    --no-sort --ansi --layout=reverse --border-label " $(hostname) " --prompt '⚡  ' \
    --color="border:$COLOR_MAIN,label:$COLOR_MAIN,prompt:$COLOR_MAIN,pointer:$COLOR_MAIN,marker:$COLOR_MAIN,spinner:$COLOR_MAIN,header:$COLOR_MAIN,hl:$COLOR_MAIN,hl+:$COLOR_MAIN" \
    --header '^q tmux kill' \
    --bind 'tab:down,btab:up' \
    --bind 'ctrl-q:execute(tmux kill-session -t {2..})+change-prompt(⚡  )+reload(sesh list --icons --hide-duplicates)' \
    --preview-window 'down:50%:follow' \
    --preview 'sesh preview {}'
) || exit 0

# Exit if cancelled
[[ -z "$selected" ]] && exit 0

if [[ "$selected" == *"Exit SSH"* ]]; then
  # Signal to zshrc that we want to exit SSH
  touch /tmp/sesh-exit-ssh
  exit 0
elif [[ "$selected" == *"New worktree"* ]]; then
  exec ~/.config/tmux/worktree-new.sh
elif [[ "$selected" == *"$ICON_GHQ"* ]]; then
  # Extract repo path from "$ICON_GHQ  ~/path/to/repo"
  repo=$(echo "$selected" | sed "s/.*$ICON_GHQ //" | restore_path)
  ~/.config/tmux/tmux-session-connect.sh "$repo"
elif [[ "$selected" == *"$ICON_SSH"* ]]; then
  # Extract hostname from "$ICON_SSH  hostname"
  host=$(echo "$selected" | sed "s/.*$ICON_SSH //")

  if [ -n "${TMUX:-}" ]; then
    # Inside tmux: write host to temp file, then detach
    # zshrc will pick this up and ssh after detach
    echo "$host" >/tmp/sesh-ssh-pending
    tmux detach-client
  else
    # Outside tmux: just ssh directly
    exec ssh "$host"
  fi
else
  target="$(echo "$selected" | restore_path)"
  if [[ "$target" == *"$HOME"* ]]; then
    # Contains a path — extract it and create session with consistent naming
    path=$(echo "$target" | grep -o "$HOME.*")
    ~/.config/tmux/tmux-session-connect.sh "$path"
  else
    # Existing session name — let sesh handle connection
    sesh connect "$target"
  fi
fi
