#!/usr/bin/env bash
# All worktrees across all ghq repos, one path per line, deduped.
#
# Linked worktrees of the same repo are separate ghq entries and each reports
# the full worktree set, so the same path shows up many times without dedup.
# Repos are visited most-recently-touched first (by .git/index mtime), so
# frequently-used repos stream to the top of the picker immediately instead of
# waiting behind the whole ghq list. Dedup keeps the first occurrence, so each
# worktree inherits its owning repo's rank.
set -u

ghq list --full-path | while IFS= read -r repo; do
  t=$(stat -c %Y "$repo/.git/index" 2>/dev/null || stat -f %m "$repo/.git/index" 2>/dev/null || echo 0)
  printf '%s\t%s\n' "$t" "$repo"
done | sort -rn | cut -f2- | while IFS= read -r repo; do
  git -C "$repo" worktree list --porcelain 2>/dev/null
done | awk '/^worktree / { print substr($0, 10) }' | awk '!seen[$0]++'
