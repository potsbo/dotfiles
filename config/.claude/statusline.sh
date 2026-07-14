#!/bin/bash
# Claude Code statusline: rate limit の使用率だけを表示する
# rate_limits は Pro/Max プランでセッション初回の API レスポンス以降にのみ含まれる
set -euo pipefail

input=$(cat)

# 使用率に応じて色を付ける (>=80% 赤, >=50% 黄, それ未満は淡色)
colorize() {
  local pct=$1
  local rounded
  rounded=$(printf '%.0f' "$pct")
  if [ "$rounded" -ge 80 ]; then
    printf '\033[31m%s%%\033[0m' "$rounded"
  elif [ "$rounded" -ge 50 ]; then
    printf '\033[33m%s%%\033[0m' "$rounded"
  else
    printf '\033[2m%s%%\033[0m' "$rounded"
  fi
}

five=$(jq -r '.rate_limits.five_hour.used_percentage // empty' <<<"$input")
week=$(jq -r '.rate_limits.seven_day.used_percentage // empty' <<<"$input")
five_reset=$(jq -r '.rate_limits.five_hour.resets_at // empty' <<<"$input")

parts=()
if [ -n "$five" ]; then
  segment="5h $(colorize "$five")"
  if [ -n "$five_reset" ]; then
    segment+=$(printf ' \033[2m(reset %s)\033[0m' "$(date -d "@$five_reset" +%H:%M 2>/dev/null || date -r "$five_reset" +%H:%M)")
  fi
  parts+=("$segment")
fi
[ -n "$week" ] && parts+=("7d $(colorize "$week")")

out=""
for p in "${parts[@]}"; do
  out+="${out:+ | }$p"
done
printf '%s' "$out"
