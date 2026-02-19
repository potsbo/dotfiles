#!/usr/bin/env bash

set -eu

fmt_rate() {
  awk "BEGIN {
    r = $1
    if      (r >= 1073741824) printf \"%.1fG\", r/1073741824
    else if (r >= 1048576)    printf \"%.1fM\", r/1048576
    else if (r >= 1024)       printf \"%.0fK\", r/1024
    else                      printf \"%.0fB\", r
  }"
}

case "$(uname)" in
Darwin)
  iface=$(route -n get default 2>/dev/null | awk '/interface:/ { print $2 }')
  [ -n "${iface:-}" ] && read -r rx tx <<< "$(netstat -ib -I "$iface" | awk 'NR==2 { print $7, $10 }')"
  ;;
Linux)
  iface=$(ip route 2>/dev/null | awk '/default/ { print $5; exit }')
  [ -n "${iface:-}" ] && read -r rx tx <<< "$(awk -v iface="$iface:" '$1==iface { print $2, $10 }' /proc/net/dev)"
  ;;
esac

cache="/tmp/tmux-net-speed"
now=$(date +%s)
if [ -n "${rx:-}" ] && [ -n "${tx:-}" ]; then
  if [ -f "$cache" ]; then
    read -r prev_time prev_rx prev_tx < "$cache"
    elapsed=$((now - prev_time))
    if [ "$elapsed" -gt 0 ]; then
      rx_rate=$(( (rx - prev_rx) / elapsed ))
      tx_rate=$(( (tx - prev_tx) / elapsed ))
      [ "$rx_rate" -ge 0 ] && [ "$tx_rate" -ge 0 ] && printf "↓%s ↑%s" "$(fmt_rate "$rx_rate")" "$(fmt_rate "$tx_rate")"
    fi
  fi
  echo "$now $rx $tx" > "$cache"
fi
