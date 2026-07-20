#!/usr/bin/env bash
# tuicast ssh view display: host icon tinted with the host's assigned color,
# name padded to a column, then dim icon+text tags. Tags stay literal text so
# typing "ssh" / "nixos" in the picker matches them.
host="$1"
hex=$(~/.local/bin/host-color "$host")
r=$((16#${hex:1:2})); g=$((16#${hex:3:2})); b=$((16#${hex:5:2}))

tags=" ssh"
for t in $(~/.local/bin/host-tags "$host"); do
  case "$t" in
    nixos)   tags+="   nixos" ;;
    darwin)  tags+="  󰀵 darwin" ;;
    linux)   tags+="  󰌽 linux" ;;
    windows) tags+="  󰖳 windows" ;;
    *)       tags+="  󰓹 $t" ;;
  esac
done

printf '\033[38;2;%d;%d;%dm\356\254\272\033[39m %-19s\033[2m%s\033[22m\n' \
  "$r" "$g" "$b" "$host" "$tags"
