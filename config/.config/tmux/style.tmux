#!/usr/bin/env bash

set -eu

main() {
  tmux set -g status "on"
  tmux set -g status-position "top"
  tmux set -g status-justify "right"
}

main
