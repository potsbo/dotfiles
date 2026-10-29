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

# repo ごとのタブや分割を独立させるため、Rex では checkout ごとに session を使う
# (.zprofile も Rex 内では herdr に自動 attach しない)。ラベルは herdr の
# space と同じものにして、どちらで開いても同じ名前で見えるようにする。
if [ -n "${REX_SESSION:-}" ]; then
  exec ~/.config/tuicast/rex-session.sh "$(~/.local/bin/herdr-label "$dir")" "$dir"
fi

if ~/.local/bin/herdr-space-connect "$dir" 2>/dev/null; then
  exec ~/.local/bin/herdr-attach
else
  # herdr server がまだ無い: その dir から起動して最初の workspace にする
  cd "$dir"
  exec ~/.local/bin/herdr-attach
fi
