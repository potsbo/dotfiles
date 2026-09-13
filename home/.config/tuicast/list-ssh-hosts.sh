#!/usr/bin/env bash
# List SSH hostnames from config files.
# Outputs plain hostnames (no icons), one per line, deduplicated.
set -eu

# Hosts from SSH config (exclude wildcard/negation patterns and github.com).
# One Host line can carry multiple patterns ("Host a b c"), keyword is
# case-insensitive and may be indented — all valid ssh_config syntax.
{
  cat ~/.ssh/config 2>/dev/null
  cat ~/.ssh/config.d/* 2>/dev/null
} | awk 'tolower($1) == "host" {
  for (i = 2; i <= NF; i++)
    if ($i !~ /[*?!]/ && $i !~ /github\.com/) print $i
}' | sort -u
