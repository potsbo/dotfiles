#!/usr/bin/env bash
# Resolve a session name back to a directory's full path.
# Inverse of path-to-name.sh.
#
# Usage: name-to-path.sh <session-name>
#
# Examples (ghq root = ~/src):
#    potsbo/dotfiles                              → ~/src/github.com/potsbo/dotfiles
#    potsbo/dotfiles/<wt> potsbo/fix-bug          → ~/src/github.com/potsbo/dotfiles/.worktrees/potsbo/fix-bug
#    org/repo                                     → ~/src/gitlab.com/org/repo
#   sr.ht user/project                            → ~/src/sr.ht/user/project
set -eu

session_name="$1"

ghq_root="${GHQ_ROOT:-$(ghq root)}"

# Nerd font icons
ICON_GITHUB=$(printf '\uea84')
ICON_GITLAB=$(printf '\ue7eb')
ICON_WORKTREE=$(printf '\uef81')

# Extract host icon/name and the rest
# Format: "<host_part> <rest>"
host_part="${session_name%% *}"
rest="${session_name#* }"

# Host icon -> host name
case "$host_part" in
  "$ICON_GITHUB") host="github.com" ;;
  "$ICON_GITLAB") host="gitlab.com" ;;
  *) host="$host_part" ;;
esac

# Worktree icon -> .worktrees
rest="${rest/\/$ICON_WORKTREE /\/.worktrees\/}"

echo "$ghq_root/$host/$rest"
