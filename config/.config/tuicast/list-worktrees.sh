#!/usr/bin/env bash
# Worktree lists for the tuicast worktree view.
#
#   --open   : worktrees that already have a herdr pane rooted at them
#   --closed : every other worktree across all ghq repos
#
# The view stacks the two as separate sources (open first, with a ● marker in
# its display), so switching back to something already open is a near-instant
# top-of-list pick — same behavior the retired herdr-worktree-switch had.
# With no herdr server up, --open is empty and --closed lists everything.
#
# --closed enumeration: linked worktrees of the same repo are separate ghq
# entries and each reports the full worktree set, so the same path shows up
# many times without dedup. Repos are visited most-recently-touched first (by
# .git/index mtime), so frequently-used repos stream to the top of the picker
# immediately instead of waiting behind the whole ghq list. Dedup keeps the
# first occurrence, so each worktree inherits its owning repo's rank.
set -u

open_cwds() {
  herdr pane list 2>/dev/null | jq -r '.result.panes[].cwd' 2>/dev/null | awk '!seen[$0]++'
}

all_worktrees() {
  ghq list --full-path | while IFS= read -r repo; do
    t=$(stat -c %Y "$repo/.git/index" 2>/dev/null || stat -f %m "$repo/.git/index" 2>/dev/null || echo 0)
    printf '%s\t%s\n' "$t" "$repo"
  done | sort -rn | cut -f2- | while IFS= read -r repo; do
    git -C "$repo" worktree list --porcelain 2>/dev/null
  done | awk '/^worktree / { print substr($0, 10) }' | awk '!seen[$0]++'
}

case "${1:-}" in
  --open)
    # pane の cwd のうち checkout root (.git を持つ) だけ。ssh 用 workspace の
    # ~ などを弾くための判定で、worktree 全列挙より圧倒的に安い。
    open_cwds | while IFS= read -r d; do
      [ -e "$d/.git" ] && printf '%s\n' "$d"
    done
    ;;
  --closed)
    all_worktrees | grep -vxF -f <(open_cwds) || true
    ;;
  *)
    all_worktrees
    ;;
esac
