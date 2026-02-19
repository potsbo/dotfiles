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

  # cheatsheet shown on prefix key
  cheatsheet=' s:  w:  n/p:  c:  &:  %%%%:  ":  z:  q:  ^:'

  # status bar (2 lines)
  # ================================================
  tmux set -g status 2
  tmux set -g status-position "top"
  tmux set -g status-style "bg=default"
  tmux set -g message-style "align=right,fg=${thm_sub},bg=${thm_main},align=centre"

  # line 0: session name (or cheatsheet on prefix)
  tmux set -g 'status-format[0]' "#{?client_prefix,#[bg=${thm_main} fg=${thm_sub} bold fill=${thm_main}]${cheatsheet},#[bg=${thm_main} fg=${thm_sub} bold fill=${thm_main}] #S }"

  # line 1: window list
  # tmux 3.6+ defaults status-format[1] to pane list; override to window list
  tmux set -g 'status-format[1]' "#[align=left range=left #{E:status-left-style}]#[push-default]#{T;=/#{status-left-length}:status-left}#[pop-default]#[norange default]#[list=on align=#{status-justify}]#[list=left-marker]<#[list=right-marker]>#[list=on]#{W:#[range=window|#{window_index} #{E:window-status-style}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-format}#[pop-default]#[norange default]#{?loop_last_flag,,#{window-status-separator}},#[range=window|#{window_index} list=focus #{?#{!=:#{E:window-status-current-style},default},#{E:window-status-current-style},#{E:window-status-style}}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-current-format}#[pop-default]#[norange list=on default]#{?loop_last_flag,,#{window-status-separator}}}#[nolist align=right range=right #{E:status-right-style}]#[push-default]#{T;=/#{status-right-length}:status-right}#[pop-default]#[norange default]"
  tmux set -g status-left ''
  tmux set -g status-left-length 100
  tmux set -g status-right ""

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
  tmux setw -g window-status-style "none,fg=${thm_gray}"
  tmux setw -g window-status-current-format ' #I #W '
  tmux setw -g window-status-format ' #I #W '
  tmux setw -g window-status-separator ""
  tmux setw -g status-justify left
}

main
