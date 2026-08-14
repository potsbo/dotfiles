#!/usr/bin/env bash
# Display label for the tuicast worktree view: herdr-label + checked-out branch.
#
# fzf matches on the displayed text only (tuicast renders field 3 via
# --with-nth and searches that string), so anything not in the label is
# unsearchable. herdr-label only surfaces a branch for paths under
# `<repo>/.worktrees/`; main checkouts and herdr's own worktree pool
# (~/.herdr/worktrees/...) show none, so their branch is appended here.
#
# HEAD is read as a file instead of calling git: this runs once per row over
# every ghq worktree (~170 rows), where process spawns dominate the wall clock.
#
# Usage: worktree-label.sh <checkout-path>
set -u

path=$1
label=$(~/.local/bin/herdr-label "$path")

gitdir="$path/.git"
if [ -f "$gitdir" ]; then
  # linked worktree: ".git" is a "gitdir: <path>" pointer, possibly relative
  read -r line <"$gitdir" || line=""
  target=${line#gitdir: }
  case "$target" in
    /*) ;;
    *) target="$path/$target" ;;
  esac
  gitdir=$target
fi

branch=""
if [ -r "$gitdir/HEAD" ]; then
  read -r head <"$gitdir/HEAD" || head=""
  case "$head" in
    "ref: refs/heads/"*) branch=${head#ref: refs/heads/} ;;
    "") ;;
    *) branch=${head:0:7} ;; # detached
  esac
fi

# herdr-label front-loads the branch leaf (own-owner prefix stripped) for
# .worktrees/ paths; re-printing it there would be pure noise.
leaf=${branch#potsbo/}
if [ -n "$branch" ] && [ "${label%% *}" != "$leaf" ]; then
  printf '%s \033[38;2;92;92;92m\356\202\240 %s\033[39m' "$label" "$branch"
else
  printf '%s' "$label"
fi
