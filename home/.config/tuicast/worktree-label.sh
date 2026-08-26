#!/usr/bin/env bash
# Display filter for the tuicast worktree view: reads checkout paths on stdin
# and prints one display line per path — status dot, herdr-label-style label,
# then the checked-out branch (tuicast pipe display, the "|" form).
#
# Pipe form instead of per-item ({}): this renders every ghq worktree
# (~170 rows), and per-item cost is 4 process spawns a row (sh, this script,
# herdr-label, ghq root) — ~8s for the column. One process doing pure string
# ops per line brings that under 100ms.
#
# The label logic mirrors ~/.local/bin/herdr-label ("<branch-leaf> <icon>
# <shorturl>") instead of calling it, for the spawn cost above. herdr-label
# stays the source of truth for herdr itself; keep the two in sync.
#
# fzf matches on the displayed text only (tuicast renders field 3 via
# --with-nth and searches that string), so anything not in the label is
# unsearchable. The branch is appended for main checkouts and herdr's own
# worktree pool (~/.herdr/worktrees/...), whose label carries no branch leaf.
#
# HEAD is read as a file instead of calling git: process spawns dominate here.
#
# The leading dot is the herdr sidebar's state_dot for the pane rooted at the
# worktree: blocked=赤● > working=peach● > idle=mint○ > 状態不明=灰·, closed
# (no pane) gets blank padding. 色は herdr の vesper テーマの palette 値
# (truecolor)。theme を変えたらここも合わせる。
#
# Usage: list-worktrees.sh ... | worktree-label.sh --dot (blocked|working|idle|unknown|none)
set -u

case "${2:-none}" in
  blocked) dot=$'\033[38;2;255;128;128m\342\227\217\033[39m ' ;;
  working) dot=$'\033[38;2;255;199;153m\342\227\217\033[39m ' ;;
  idle)    dot=$'\033[38;2;153;255;228m\342\227\213\033[39m ' ;;
  unknown) dot=$'\033[38;2;92;92;92m\302\267\033[39m ' ;;
  *)       dot='  ' ;;
esac

ghq_root="${GHQ_ROOT:-$(ghq root)}"
ICON_GITHUB=$(printf '\356\252\204')
ICON_GITLAB=$(printf '\356\237\253')

while IFS= read -r path; do
  rel="${path#"$ghq_root"/}"
  host="${rel%%/*}"
  rest="${rel#*/}"

  case "$host" in
    github.com) icon=$ICON_GITHUB ;;
    gitlab.com) icon=$ICON_GITLAB ;;
    *)          icon=$host ;;
  esac

  if [[ "$rest" == */.worktrees/* ]]; then
    repo="${rest%%/.worktrees/*}"
    leaf="${rest#*/.worktrees/}"
    leaf="${leaf#potsbo/}"
    label="$leaf $icon $repo"
  else
    label="$icon $rest"
  fi

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
    printf '%s%s \033[38;2;92;92;92m\356\202\240 %s\033[39m\n' "$dot" "$label" "$branch"
  else
    printf '%s%s\n' "$dot" "$label"
  fi
done
