#!/usr/bin/env bash
# Open a worktree path — the tuicast worktree view's run target:
#
#   inside Rex : select the Rex session for the path's repo (create it if needed)
#   outside    : start a shell in the path
set -eu

dir="$1"

# 新規 tab の固定 dir を名前から復元するため、Rex ではアイコンを使わず
# ghq root からの repo パスを session 名にする。worktree も同じ session を使う。
if [ -n "${REX_SESSION:-}" ]; then
  common=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir)
  repo=$(dirname "$common")
  root=$(ghq root)
  case "$repo" in
    "$root"/*) label="${repo#"$root"/}" ;;
    *) printf 'Repository is outside ghq root: %s\n' "$repo" >&2; exit 1 ;;
  esac
  exec ~/.config/tuicast/rex-session.sh "$label" "$dir"
fi

cd "$dir"
exec "${SHELL:-zsh}"
