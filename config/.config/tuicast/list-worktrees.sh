#!/usr/bin/env bash
# Worktree lists for the tuicast worktree view.
#
#   --open [blocked|working|idle|unknown]
#            worktrees that already have a herdr pane rooted at them; with a
#            status class, only those whose most urgent agent is in it
#   --closed every other worktree across all ghq repos
#
# The view stacks these as separate sources (open first, most urgent status on
# top, each with the herdr sidebar's status-dot in its display), so switching
# back to something that needs attention is a top-of-list pick. With no herdr
# server up, --open is empty and --closed lists everything.
#
# A worktree can host several agents; like herdr's sidebar aggregate it is
# classed by the most urgent one: blocked > working > idle > unknown.
#
# --closed enumeration: linked worktrees of the same repo are separate ghq
# entries and each reports the full worktree set, so the same path shows up
# many times without dedup. Repos are visited most-recently-touched first (by
# .git/index mtime), so frequently-used repos stream to the top of the picker
# immediately instead of waiting behind the whole ghq list. Dedup keeps the
# first occurrence, so each worktree inherits its owning repo's rank.
set -u

open_panes() {  # "<cwd>\t<agent_status>" per pane
  herdr pane list 2>/dev/null \
    | jq -r '.result.panes[] | [.cwd, (.agent_status // "unknown")] | @tsv' 2>/dev/null
}

open_cwds() {   # deduped, optionally filtered to one aggregate status class
  open_panes | awk -F'\t' -v want="${1:-}" '
    function rank(s) { return s == "blocked" ? 3 : s == "working" ? 2 : s == "idle" ? 1 : 0 }
    {
      if (!($1 in best)) { order[++n] = $1; best[$1] = rank($2) }
      else if (rank($2) > best[$1]) best[$1] = rank($2)
    }
    END {
      w = rank(want)
      for (i = 1; i <= n; i++)
        if (want == "" || best[order[i]] == w) print order[i]
    }'
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
    open_cwds "${2:-}" | while IFS= read -r d; do
      [ -e "$d/.git" ] || continue
      printf '%s\n' "$d"
    done
    ;;
  --closed)
    all_worktrees | grep -vxF -f <(open_cwds) || true
    ;;
  *)
    all_worktrees
    ;;
esac
