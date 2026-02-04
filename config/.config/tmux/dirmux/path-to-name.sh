#!/usr/bin/env bash
# Generate tmux session name from a directory's full path.
#
# Usage: path-to-name.sh <full-path>
#
# Rules:
#   1. Strip ghq root prefix
#   2. Replace host with nerd font icon (github.com → \uea84, gitlab.com → \ue7eb)
#   3. Replace /.worktrees/ with worktree icon (\uef81)
#
# Examples (ghq root = ~/src):
#   ~/src/github.com/potsbo/dotfiles                                  →  potsbo/dotfiles
#   ~/src/github.com/potsbo/dotfiles/.worktrees/potsbo/fix-bug        →  potsbo/dotfiles/<wt> potsbo/fix-bug
#   ~/src/github.com/kubernetes/kubernetes/.worktrees/fix              →  kubernetes/kubernetes/<wt> fix
#   ~/src/gitlab.com/org/repo                                         →  org/repo
set -eu

target_path="$1"

ghq_root="${GHQ_ROOT:-$(ghq root)}"
rel="${target_path#"$ghq_root"/}"

# Split: host/rest...
host="${rel%%/*}"
name="${rel#*/}"

# Host -> nerd font icon
ICON_GITHUB=$(printf '\uea84')
ICON_GITLAB=$(printf '\ue7eb')
ICON_WORKTREE=$(printf '\uef81')

case "$host" in
  "github.com") host_part="$ICON_GITHUB" ;;
  "gitlab.com") host_part="$ICON_GITLAB" ;;
  *) host_part="$host" ;;
esac

# Replace /.worktrees/ with worktree icon
name="${name/\/.worktrees\///$ICON_WORKTREE }"

echo "$host_part $name"
