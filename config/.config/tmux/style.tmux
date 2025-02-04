#!/usr/bin/env bash

set -eu

main() {
  thm_black="#2e2e2e"
  thm_gray="#797979"

  # https://www.color-hex.com/color-palette/59231
  thm_red="#f92672"
  thm_green="#a6e22e"
  thm_blue="#66d9ef"
  thm_yellow="#fd971f"
  thm_purple="#ae81ff"
  thm_white="#f8f8f2"

  case $(hostname) in
  "tigerlake")
    thm_main=$thm_yellow
    thm_sub=$thm_black
    ;;
  "raptorlake")
    thm_main=$thm_white
    thm_sub=$thm_black
    ;;
  "staten.local")
    thm_main=$thm_purple
    thm_sub=$thm_black
    ;;
  *)
    thm_main=$thm_gray
    thm_sub=$thm_black
    ;;
  esac

  separator="#[fg=${thm_sub},bg=default,none]▕#[default]"

  # status bar
  # ================================================
  tmux set -g status "on"
  tmux set -g status-position "top"
  tmux set -g status-style "bold,bg=${thm_main},fg=${thm_sub}"
  tmux set -g message-style "align=right,fg=${thm_sub},bg=${thm_main},align=centre"

  # left panel
  tmux set -g status-left-length 40
  tmux set -g status-left " #S@#h ${separator}"

  # right panel
  tmux set -g status-right ""
  tmux set -g status-right-style "none"

  # window
  # ================================================
  tmux setw -g window-status-current-style "bold,fg=${thm_main},bg=${thm_sub}"
  tmux setw -g window-status-activity-style "none,bg=${thm_sub}"
  tmux setw -g window-status-style "none,fg=${thm_black}"
  tmux setw -g window-status-current-format "  #I #W ${separator}"
  tmux setw -g window-status-format "  #I #W ${separator}"
  tmux setw -g window-status-separator ""
  tmux setw -g status-justify left
}

main
