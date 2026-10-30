#!/usr/bin/env bash
# Connect to the herdr space for a worktree path — the tuicast worktree view's
# run target, and the one place where herdr-inside/outside behavior forks:
#
#   inside herdr : focus the workspace rooted at the path (create it if needed)
#   inside Rex   : select the Rex session for the path (create it if needed)
#   outside      : same, but prepare it server-side and then attach; if no
#                  herdr server is up yet, start herdr from that directory
set -eu

dir="$1"

# 内外判定は HERDR_ENV (popup にも入る)。HERDR_PANE_ID は popup で未設定。
if [ -n "${HERDR_ENV:-}" ]; then
  exec ~/.local/bin/herdr-space-connect "$dir"
fi

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

if ~/.local/bin/herdr-space-connect "$dir" 2>/dev/null; then
  exec ~/.local/bin/herdr-attach
else
  # herdr server がまだ無い: その dir から起動して最初の workspace にする
  cd "$dir"
  exec ~/.local/bin/herdr-attach
fi
