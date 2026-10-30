#!/usr/bin/env bash
# Keep each repo's tabs and splits in its own session. Match labels exactly
# so a repo name cannot accidentally resolve to another resource's ID suffix.
set -euo pipefail

label="$1"
dir="$2"
rex="$REX_BIN_DIR/rex"

# A pane can be shared by several apps, so it cannot identify who invoked us.
# Prefer the last app attached to the source session as a practical fallback;
# returning to an older attached device requires an explicit REX_CLIENT.
client="${REX_CLIENT:-}"
if [ -z "$client" ]; then
  client=$("$rex" api call -s "$REX_SESSION" session.list_clients | jq -er \
    '[.clients[] | select(.info.kind == "app" and .connection_state != "lost")]
     | last | .client_id // empty')
fi

session=$("$rex" session ls --json | jq -r --arg l "$label" \
  'first(.sessions[] | select(.label == $l) | .session_id) // empty')

if [ -z "$session" ]; then
  session=$("$rex" session new -c "$dir" "$label" --json | jq -er '.session_id')
fi

exec "$rex" -C "$client" 'do' session.select "session_id=$session"
