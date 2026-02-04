#!/usr/bin/env bash
# Convert a unix epoch timestamp to a human-readable relative time string.
#
# Usage: relative-time.sh <epoch>
#
# Examples:
#   relative-time.sh 1706918400  → "3 days ago"
#   relative-time.sh "$(date +%s)"  → "just now"
set -eu

t="$1"
now=$(date +%s)
diff=$((now - t))

if [ "$diff" -lt 60 ]; then
  echo "just now"
elif [ "$diff" -lt 3600 ]; then
  echo "$((diff / 60)) minutes ago"
elif [ "$diff" -lt 86400 ]; then
  echo "$((diff / 3600)) hours ago"
elif [ "$diff" -lt 604800 ]; then
  echo "$((diff / 86400)) days ago"
elif [ "$diff" -lt 2592000 ]; then
  echo "$((diff / 604800)) weeks ago"
else
  echo "$((diff / 2592000)) months ago"
fi
