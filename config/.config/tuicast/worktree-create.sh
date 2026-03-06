#!/usr/bin/env bash
# Create a git worktree and connect to it as a tmux session.
# Usage: worktree-create.sh <repo-path> <branch>
set -eu

repo="$1"
branch="$2"

cd "$repo"

# Strip remote prefix
local_branch="${branch#origin/}"

# Sanitize if it looks like a new branch name (typed via free input)
local_branch=$(echo "$local_branch" | ~/.config/git/sanitize-branch-name.sh)

# Add user prefix if no slash present
if [[ "$local_branch" != */* ]]; then
  local_branch="potsbo/$local_branch"
fi

git fetch --prune 2>/dev/null || true

# Determine start point
if git show-ref --verify "refs/remotes/$branch" >/dev/null 2>&1; then
  git wt "$local_branch" "$branch"
elif git show-ref --verify "refs/heads/$branch" >/dev/null 2>&1; then
  git wt "$local_branch" "$branch"
else
  git wt "$local_branch" "origin/$(git default-branch)"
fi

worktree_path=$(git wt | grep "$local_branch" | awk '{print $1}')
exec ~/.config/tmux/tmux-session-connect.sh "$worktree_path"
