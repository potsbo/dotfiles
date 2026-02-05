#!/usr/bin/env bash

set -eu

# Icons (nerdfont)
ICON_SSH=$(printf '\uEB3A')

COLOR_MAIN=$(~/.config/tmux/dirmux/config/color.sh)

selected=$(
  ~/.config/tmux/sesh-list.sh | fzf-tmux -p 100%,100% \
    --no-sort --ansi --layout=reverse --border-label " $(hostname) " --prompt '⚡  ' \
    --color="border:$COLOR_MAIN,label:$COLOR_MAIN,prompt:$COLOR_MAIN,pointer:$COLOR_MAIN,marker:$COLOR_MAIN,spinner:$COLOR_MAIN,header:$COLOR_MAIN,hl:$COLOR_MAIN,hl+:$COLOR_MAIN" \
    --header '^q tmux kill' \
    --bind 'tab:down,btab:up' \
    --bind 'ctrl-q:execute(tmux kill-session -t {2..})+change-prompt(⚡  )+reload(~/.config/tmux/sesh-list.sh)' \
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
  # Everything else: existing session or new ghq repo
  # Try sesh first (handles existing sessions with sesh icons),
  # then resolve via dirmux
  sesh connect "$selected" 2>/dev/null || {
    path=$(~/.config/tmux/dirmux/name-to-path.sh "$selected")
    ~/.config/tmux/tmux-session-connect.sh "$path"
  }
fi
