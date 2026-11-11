#!/usr/bin/env bash
# Display filter for the tuicast worktree view: reads checkout paths on stdin
# and prints one display line per path — label, then the checked-out branch
# (tuicast pipe display, the "|" form).
#
# Pipe form instead of per-item ({}): this renders every ghq worktree
# (~170 rows), and per-item cost is several process spawns a row (sh, this
# script, ghq root) — ~8s for the column. One process doing pure string ops
# per line brings that under 100ms.
#
# fzf matches on the displayed text only (tuicast renders field 3 via
# --with-nth and searches that string), so anything not in the label is
# unsearchable. The branch is appended for main checkouts, whose label carries
# no branch leaf.
#
# HEAD is read as a file instead of calling git: process spawns dominate here.
#
# 行頭の 2 桁の空白は、他のエントリのアイコン + 空白の列に揃えるため。
#
# Usage: list-worktrees.sh | worktree-label.sh
set -u

# shellcheck source=home/.config/shell/worktree-label.sh
source ~/.config/shell/worktree-label.sh

pad='  '
ghq_root="${GHQ_ROOT:-$(ghq root)}"

while IFS= read -r path; do
  label=''
  worktree_label label "$path" "$ghq_root"

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

  # The label front-loads the branch leaf (own-owner prefix stripped) for
  # .worktrees/ paths; re-printing it there would be pure noise.
  if [ -n "$branch" ] && [ "${label%% *}" != "${branch#potsbo/}" ]; then
    printf '%s%s \033[38;2;92;92;92m\356\202\240 %s\033[39m\n' "$pad" "$label" "$branch"
  else
    printf '%s%s\n' "$pad" "$label"
  fi
done
