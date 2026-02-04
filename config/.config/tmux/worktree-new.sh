#!/usr/bin/env bash
set -eu

COLOR_MAIN=$(~/.config/tmux/dirmux/config/color.sh)

FZF_COLOR="border:$COLOR_MAIN,label:$COLOR_MAIN,prompt:$COLOR_MAIN,pointer:$COLOR_MAIN,marker:$COLOR_MAIN,spinner:$COLOR_MAIN,header:$COLOR_MAIN,hl:$COLOR_MAIN,hl+:$COLOR_MAIN"

# 1. Select repository (displayed as session names)
selected_repo=$(ghq list --full-path | while read -r d; do
  t=$(stat -c %Y "$d/.git/index" 2>/dev/null || stat -f %m "$d/.git/index" 2>/dev/null || echo 0)
  name=$(~/.config/tmux/dirmux/path-to-name.sh "$d")
  rel=$(~/.config/tmux/dirmux/relative-time.sh "$t")
  printf '%s\t%s  %s\n' "$t" "$name" "$rel"
done | sort -rn | cut -f2- | fzf-tmux -p 80%,60% \
  --ansi --layout=reverse --no-sort \
  --prompt "Repository: " \
  --color="$FZF_COLOR") || exit 0

[[ -z "$selected_repo" ]] && exit 0

# Strip relative time and resolve back to path
repo_name=$(echo "$selected_repo" | sed 's/  .*$//')
repo=$(~/.config/tmux/dirmux/name-to-path.sh "$repo_name")

# 2. Select branch
cd "$repo"
# Fetch in background to avoid blocking on slow networks
git fetch --prune 2>/dev/null &

branch=$(
  {
    echo "✨ Create new branch"
    git branch -a --sort=-committerdate --format='%(refname:short)  %(committerdate:relative)' | grep -v HEAD
  } | fzf-tmux -p 80%,60% \
    --ansi --layout=reverse --no-sort \
    --prompt "Branch: " \
    --color="$FZF_COLOR"
) || exit 0

[[ -z "$branch" ]] && exit 0

# 3. Create worktree
if [[ "$branch" == "✨ Create new branch" ]]; then
  # Input new branch name
  branch_name=$(echo "" | fzf-tmux -p 40%,20% \
    --ansi --layout=reverse \
    --prompt "New branch name: " \
    --color="$FZF_COLOR" \
    --print-query | head -1) || exit 0

  [[ -z "$branch_name" ]] && exit 0

  branch_name=$(echo "$branch_name" | ~/.config/git/sanitize-branch-name.sh)
  if [[ "$branch_name" != */* ]]; then
    branch_name="potsbo/$branch_name"
  fi
  git wt "$branch_name"
else
  # Extract branch name (remove date part)
  # "origin/potsbo/fix  3 days ago" -> "origin/potsbo/fix"
  branch=$(echo "$branch" | awk '{print $1}')
  # origin/potsbo/fix -> potsbo/fix
  local_branch="${branch#origin/}"
  git wt "$local_branch" "$branch"
fi

# 4. Create/connect tmux session
worktree_path=$(git wt | grep "${branch_name:-$local_branch}" | awk '{print $1}')
exec ~/.config/tmux/tmux-session-connect.sh "$worktree_path"
