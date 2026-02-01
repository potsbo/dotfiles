#!/usr/bin/env bash

set -eu

window=$(tmux list-windows -F "#{window_index}:#{window_name}" | \
  fzf-tmux -p 80%,60% \
    --no-sort --ansi \
    --border-label ' windows ' \
    --prompt '  ' \
    --delimiter ':' \
    --preview 'tmux capture-pane -ep -t :{1}' \
    --preview-window 'right:60%')

if [ -n "$window" ]; then
  index=$(echo "$window" | cut -d: -f1)
  tmux select-window -t ":$index"
fi
