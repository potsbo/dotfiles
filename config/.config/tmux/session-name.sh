#!/usr/bin/env bash
# Generate tmux session name from repo path and optional branch
# Usage: session-name.sh <repo_path> [<branch>]
#
# Examples (ghq root = ~/src):
#   session-name.sh ~/src/github.com/potsbo/dotfiles          →  dotfiles
#   session-name.sh ~/src/github.com/potsbo/dotfiles fix-bug   →  dotfiles@fix-bug
#   session-name.sh ~/src/github.com/kubernetes/kubernetes fix  →  kubernetes/kubernetes@fix
#   session-name.sh ~/src/gitlab.com/org/repo feature           →  org/repo@feature
set -eu

repo_path="$1"
branch="${2:-}"

ghq_root=$(ghq root)
rel="${repo_path#"$ghq_root"/}"

# Split: host/owner/repo...
host="${rel%%/*}"
after_host="${rel#*/}"
owner="${after_host%%/*}"
repo="${after_host#*/}"

# Host -> nerd font icon
ICON_GITHUB=$(printf '\uea84')
ICON_GITLAB=$(printf '\ue7eb')

case "$host" in
  "github.com") host_part="$ICON_GITHUB" ;;
  "gitlab.com") host_part="$ICON_GITLAB" ;;
  *) host_part="$host" ;;
esac

# Skip owner if potsbo or medicu-inc
case "$owner" in
  "potsbo"|"medicu-inc") name="$repo" ;;
  *) name="$owner/$repo" ;;
esac

session_name="$host_part $name"

# Append @branch if provided
if [ -n "$branch" ]; then
  branch_part="${branch##*/}"
  session_name="${session_name}@${branch_part}"
fi

echo "$session_name"
