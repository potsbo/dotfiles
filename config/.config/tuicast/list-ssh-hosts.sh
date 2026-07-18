#!/usr/bin/env bash
# List SSH hostnames from config files and recent zsh history.
# Outputs plain hostnames (no icons), one per line, deduplicated.
set -eu

{
  # Hosts from SSH config (exclude wildcard/negation patterns and github.com).
  # One Host line can carry multiple patterns ("Host a b c"), keyword is
  # case-insensitive and may be indented — all valid ssh_config syntax.
  {
    cat ~/.ssh/config 2>/dev/null
    cat ~/.ssh/config.d/* 2>/dev/null
  } | awk 'tolower($1) == "host" {
    for (i = 2; i <= NF; i++)
      if ($i !~ /[*?!]/ && $i !~ /github\.com/) print $i
  }'

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
