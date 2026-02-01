#!/usr/bin/env bash

set -eu

sesh connect "$(
  sesh list --icons --hide-duplicates | fzf-tmux -p 100%,100% \
    --no-sort --ansi --border-label ' sesh ' --prompt '⚡  ' \
    --header '^q tmux kill' \
    --bind 'tab:down,btab:up' \
    --bind 'ctrl-q:execute(tmux kill-session -t {2..})+change-prompt(⚡  )+reload(sesh list --icons --hide-duplicates)' \
    --preview-window 'right:70%' \
    --preview 'sesh preview {}'
)"
