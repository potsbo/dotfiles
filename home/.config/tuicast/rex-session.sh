#!/usr/bin/env bash
# Keep each checkout's tabs and splits in its own session. Match labels exactly
# so a repo name cannot accidentally resolve to another resource's ID suffix.
set -euo pipefail

label="$1"
dir="$2"
rex="$REX_BIN_DIR/rex"

session=$("$rex" session ls --json | jq -r --arg l "$label" \
  'first(.sessions[] | select(.label == $l) | .session_id) // empty')

if [ -z "$session" ]; then
  session=$("$rex" session new -c "$dir" "$label" --json | jq -er '.session_id')
fi

# Let Rex choose the app client (or honor REX_CLIENT). With several connected
# apps it requires REX_CLIENT rather than switching other devices unexpectedly.
exec "$rex" 'do' session.select "session_id=$session"
