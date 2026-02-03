#!/usr/bin/env bash
# Generate tmux session name from a path
# Usage: session-name.sh <path>
#
# Examples (ghq root = ~/src):
#   session-name.sh ~/src/github.com/potsbo/dotfiles                          →  dotfiles
#   session-name.sh ~/src/github.com/potsbo/dotfiles/.worktrees/fix-bug        →  dotfiles/<wt>/fix-bug
#   session-name.sh ~/src/github.com/kubernetes/kubernetes/.worktrees/fix       →  kubernetes/kubernetes/<wt>/fix
#   session-name.sh ~/src/gitlab.com/org/repo                                  →  org/repo
set -eu

target_path="$1"

ghq_root=$(ghq root)
rel="${target_path#"$ghq_root"/}"

# Split: host/owner/rest...
host="${rel%%/*}"
after_host="${rel#*/}"
owner="${after_host%%/*}"
rest="${after_host#*/}"

# Host -> nerd font icon
ICON_GITHUB=$(printf '\uea84')
ICON_GITLAB=$(printf '\ue7eb')
ICON_WORKTREE=$(printf '\uef81')

case "$host" in
  "github.com") host_part="$ICON_GITHUB" ;;
  "gitlab.com") host_part="$ICON_GITLAB" ;;
  *) host_part="$host" ;;
esac

# Skip owner if potsbo or medicu-inc
case "$owner" in
  "potsbo"|"medicu-inc") name="$rest" ;;
  *) name="$owner/$rest" ;;
esac

# Replace /.worktrees/ with worktree icon (with spacing)
name="${name/\/.worktrees\///$ICON_WORKTREE }"

echo "$host_part $name"
