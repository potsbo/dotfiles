#!/usr/bin/env bash
# tuicast ssh view display: host icon tinted with the host's assigned color.
host="$1"
hex=$(~/.local/bin/host-color "$host")
r=$((16#${hex:1:2})); g=$((16#${hex:3:2})); b=$((16#${hex:5:2}))
printf '\033[38;2;%d;%d;%dm\356\254\272\033[39m %s\n' "$r" "$g" "$b" "$host"
