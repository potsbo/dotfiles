#!/usr/bin/env bash
# List SSH hostnames from config files and recent zsh history.
# Outputs plain hostnames (no icons), one per line, deduplicated.
set -eu

{
  # Hosts from SSH config (exclude wildcards and github.com)
  {
    cat ~/.ssh/config 2>/dev/null
    cat ~/.ssh/config.d/* 2>/dev/null
  } | awk '/^Host / && $2 !~ /\*/ && $2 !~ /github\.com/ { print $2 }'

  # Recent SSH hosts from zsh history (last 3 months)
  three_months_ago=$(date -v-3m +%s 2>/dev/null || date -d '3 months ago' +%s 2>/dev/null || echo 0)
  grep -a '^: [0-9]*:0;ssh ' ~/.zsh_history 2>/dev/null | awk -v cutoff="$three_months_ago" '{
    split($0, a, ":")
    ts = a[2] + 0
    if (ts >= cutoff) {
      sub(/^: [0-9]*:0;ssh /, "")
      host = $1
      if (host !~ /^-/) hosts[host] = 1
    }
  } END { for (h in hosts) print h }'
} | sort -u
