#!/usr/bin/env bash
set -eu

# Host-specific color (same as sesh-connect.sh)
case $(hostname) in
"tigerlake")    COLOR_MAIN="#fd971f" ;;  # yellow
"raptorlake")   COLOR_MAIN="#f8f8f2" ;;  # white
"staten.local") COLOR_MAIN="#ae81ff" ;;  # purple
"phoenix")      COLOR_MAIN="#d7875f" ;;  # orange
*)              COLOR_MAIN="#797979" ;;  # gray
esac

FZF_COLOR="border:$COLOR_MAIN,label:$COLOR_MAIN,prompt:$COLOR_MAIN,pointer:$COLOR_MAIN,marker:$COLOR_MAIN,spinner:$COLOR_MAIN,header:$COLOR_MAIN,hl:$COLOR_MAIN,hl+:$COLOR_MAIN"

# 1. Select repository
repo=$(ghq list --full-path | fzf-tmux -p 80%,60% \
  --ansi --layout=reverse \
  --prompt "Repository: " \
  --color="$FZF_COLOR") || exit 0

[[ -z "$repo" ]] && exit 0

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
# potsbo/fix-bug -> fix-bug
session_name="${branch_name:-$local_branch}"
session_name="${session_name##*/}"

# Get worktree path
worktree_path=$(git wt | grep "${branch_name:-$local_branch}" | awk '{print $1}')

if tmux has-session -t "$session_name" 2>/dev/null; then
  if [ -n "${TMUX:-}" ]; then
    tmux switch-client -t "$session_name"
  else
    tmux attach-session -t "$session_name"
  fi
else
  tmux new-session -d -c "$worktree_path" -s "$session_name"
  if [ -n "${TMUX:-}" ]; then
    tmux switch-client -t "$session_name"
  else
    tmux attach-session -t "$session_name"
  fi
fi
