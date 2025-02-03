#!/usr/bin/env bash

set -eu

main() {
  # https://gist.github.com/r-malon/8fc669332215c8028697a0bbfbfbb32a
  thm_gray="#797979"
  thm_fg="#9e86c8"
  thm_black="#2e2e2e"

  separator="#[fg=${thm_gray},bg=default,none]▕#[default]"

  # status bar
  # ================================================
  tmux set -g status "on"
  tmux set -g status-position "top"
  tmux set -g status-style "none"

  # left panel
  tmux set -g status-left-length 20
  tmux set -g status-left " #h ${separator}"

  # right panel
  tmux set -g status-right " #S"
  tmux set -g status-right-style "none"

  # window
  # ================================================
  tmux setw -g window-status-current-style "bold,fg=${thm_fg}"
  tmux setw -g window-status-activity-style "none,fg=${thm_black}"
  tmux setw -g window-status-style "none,fg=${thm_black}"
  tmux setw -g window-status-current-format "  #I #W ${separator}"
  tmux setw -g window-status-format "  #I #W ${separator}"
  tmux setw -g window-status-separator ""
  tmux setw -g status-justify left
}

main
