#!/usr/bin/env bash
# Worktree lists for the tuicast worktree view.
#
#   --open        worktrees that already have a herdr pane rooted at them,
#                 most urgent first (blocked > working > idle > unknown)
#   --open-status the same rows as "<status>\t<path>", for the display filter
#   --closed      every other worktree across all ghq repos
#
# --open used to be four per-status sources so each could carry its own dot in
# the display; that cost one herdr RPC (~50ms) per source. Now the ordering
# lives in this sort and the display filter recovers per-row status via
# --open-status — one extra RPC total instead of three, while tuicast's raw
# value stays a bare path (run/preview must not have to strip a status
# prefix). With no herdr server up, --open is empty and --closed lists
# everything.
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

open_status() { # "<status>\t<cwd>" per checkout root, most urgent first
  open_panes | awk -F'\t' '
    function rank(s) { return s == "blocked" ? 3 : s == "working" ? 2 : s == "idle" ? 1 : 0 }
    function name(r) { return r == 3 ? "blocked" : r == 2 ? "working" : r == 1 ? "idle" : "unknown" }
    {
      if (!($1 in best)) { order[++n] = $1; best[$1] = rank($2) }
      else if (rank($2) > best[$1]) best[$1] = rank($2)
    }
    END {
      for (r = 3; r >= 0; r--)
        for (i = 1; i <= n; i++)
          if (best[order[i]] == r) print name(r) "\t" order[i]
    }' | while IFS=$'\t' read -r st d; do
      # pane の cwd のうち checkout root (.git を持つ) だけ。ssh 用 workspace の
      # ~ などを弾くための判定で、worktree 全列挙より圧倒的に安い。
      [ -e "$d/.git" ] && printf '%s\t%s\n' "$st" "$d"
    done
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
    open_status | cut -f2-
    ;;
  --open-status)
    open_status
    ;;
  --closed)
    all_worktrees | grep -vxF -f <(open_status | cut -f2-) || true
    ;;
  *)
    all_worktrees
    ;;
esac
