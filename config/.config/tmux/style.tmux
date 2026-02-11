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
  thm_orange="#d7875f"

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
  "phoenix")
    thm_main=$thm_orange
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
  tmux set -g status-style "bg=${thm_main},fg=${thm_sub}"
  tmux set -g message-style "align=right,fg=${thm_sub},bg=${thm_main},align=centre"

  # left panel
  tmux set -g status-left-length 100
  tmux set -g status-left '#{?client_prefix, s:  w:  n/p:  c:  &:  %%%%:  ":  z:  q:  ^:, #S  ▕}'

  # right panel
  tmux set -g status-right ""
  tmux set -g status-right-style "none"
  tmux set -g status-right-style "none"

  # copy-mode (text selection)
  # ================================================
  tmux set -g mode-style "bg=${thm_main},fg=${thm_sub}"
  tmux set -g copy-mode-current-match-style "bg=${thm_main},fg=${thm_sub}"
  tmux set -g copy-mode-match-style "bg=${thm_main},fg=${thm_sub}"
  tmux set -g cursor-colour "${thm_main}"

  # window
  # ================================================
  tmux setw -g window-status-current-style "bold,fg=${thm_main},bg=${thm_sub}"
  tmux setw -g window-status-activity-style "none,bg=${thm_sub}"
  tmux setw -g window-status-style "none,fg=${thm_black}"
  tmux setw -g window-status-current-format '#{?client_prefix,,  #I #W ▕}'
  tmux setw -g window-status-format '#{?client_prefix,,  #I #W ▕}'
  tmux setw -g window-status-separator ""
  tmux setw -g status-justify left
}

main
