#!/usr/bin/env bash
# git tree <branch words...> [-- <prompt...>]
#
# Create a worktree named after the branch words and open its herdr space.
# With `-- <prompt>`, also start claude there with that prompt. Branch words
# and prompt are separated so the prompt can be free-form (Japanese, long
# sentences) without leaking into the branch/space name.
#
# Auto-generating the branch name from the prompt (e.g. `claude -p --model haiku`)
# was considered and rejected: branch naming stays the user's call. It would also
# risk billing the API instead of the subscription when ANTHROPIC_API_KEY is set.
set -euo pipefail

branch_words=()
while [ $# -gt 0 ]; do
  [ "$1" = "--" ] && { shift; break; }
  branch_words+=("$1")
  shift
done

if [ ${#branch_words[@]} -eq 0 ]; then
  echo "usage: git tree <branch words...> [-- <prompt>]" >&2
  exit 1
fi

b="potsbo/$(echo "${branch_words[*]}" | ~/.config/git/sanitize-branch-name.sh)"

gh repo sync
git switch "$(git default-branch)"
git wt "$b"
dir="$(git wt | grep "$b" | awk '{print $1}')"

if [ $# -gt 0 ]; then
  exec ~/.local/bin/herdr-space-connect "$dir" claude "$*"
else
  exec ~/.local/bin/herdr-space-connect "$dir"
fi
