#!/usr/bin/env bash

set -eu

# Icons (nerdfont)
ICON_SSH=$(printf '\uEB3A')
ICON_GITHUB=$(printf '\uea84')
ICON_GITLAB=$(printf '\ue7eb')
ICON_WORKTREE=$(printf '\uef81')

SESH_HISTORY="${XDG_STATE_HOME:-$HOME/.local/state}/sesh-connect/history"
GHQ_ROOT="${GHQ_ROOT:-$(ghq root)}"

# Inline version of path-to-name.sh (avoids fork per repo)
path_to_name() {
  local rel="${1#"$GHQ_ROOT"/}"
  local host="${rel%%/*}"
  local name="${rel#*/}"
  local host_part
  case "$host" in
    "github.com") host_part="$ICON_GITHUB" ;;
    "gitlab.com") host_part="$ICON_GITLAB" ;;
    *) host_part="$host" ;;
  esac
  name="${name/\/.worktrees\///$ICON_WORKTREE }"
  printf '%s\n' "$host_part $name"
}

# SSH hosts from config (exclude github.com, *.github.com, etc.)
ssh_hosts() {
  {
    cat ~/.ssh/config 2>/dev/null
    cat ~/.ssh/config.d/* 2>/dev/null
  } | awk -v icon="$ICON_SSH" '/^Host / && $2 !~ /\*/ && $2 !~ /github\.com/ { print icon " " $2 }' | sort -u
}

# Recent SSH hosts from history (last 3 months)
ssh_history() {
  local three_months_ago
  three_months_ago=$(date -v-3m +%s 2>/dev/null || date -d '3 months ago' +%s)

  grep -a '^: [0-9]*:0;ssh ' ~/.zsh_history 2>/dev/null | awk \
    -v cutoff="$three_months_ago" \
    -v icon="$ICON_SSH" \
    '{
      split($0, a, ":")
      ts = a[2] + 0
      if (ts >= cutoff) {
        sub(/^: [0-9]*:0;ssh /, "")
        host = $1
        if (host !~ /^-/) hosts[host] = 1
      }
    }
    END { for (h in hosts) print icon " " h }' | sort -u
}

# Combine and dedupe SSH hosts
all_ssh_hosts() {
  {
    ssh_hosts
    ssh_history
  } | sort -u
}

# List everything
if [ -n "${SSH_CONNECTION:-}" ] && [ -z "${TMUX:-}" ]; then
  echo "🚪  Exit SSH"
fi
echo "🌿  New worktree"
sesh list --tmux --icons --hide-duplicates

# Build associative array of active tmux sessions (O(1) lookup, no grep fork)
declare -A _sessions
while IFS= read -r s; do
  [[ -n "$s" ]] && _sessions["$s"]=1
done < <(tmux list-sessions -F "#{session_name}" 2>/dev/null || true)

declare -A _seen

# Phase 1: Repos from history, sorted by recency (instant)
if [[ -f "$SESH_HISTORY" ]]; then
  while IFS= read -r name; do
    if [[ -z "${_sessions[$name]:-}" ]]; then
      echo "$name"
      _seen["$name"]=1
    fi
  done < <(
    awk -F'\t' '
      { if ($1+0 > latest[$2]+0) latest[$2]=$1 }
      END { for (n in latest) print latest[n] "\t" n }
    ' "$SESH_HISTORY" | sort -t$'\t' -k1,1rn | cut -f2
  )
fi

# Phase 2: Remaining ghq repos sorted by .git/index mtime (descending)
# First pass: collect mtime for each repo path (fast, stat only)
# Second pass: resolve display names via inlined path_to_name and stream
ghq list --full-path | roots --depth 4 --root-file .git 2>/dev/null | while read -r repo; do
  git_dir="$repo/.git"
  if [[ ! -d "$git_dir" ]]; then
    git_dir=$(git -C "$repo" rev-parse --git-dir 2>/dev/null || echo "$repo/.git")
    [[ "$git_dir" != /* ]] && git_dir="$repo/$git_dir"
  fi
  mtime=$(stat -c %Y "$git_dir/index" 2>/dev/null || stat -f %m "$git_dir/index" 2>/dev/null || echo 0)
  printf '%s\t%s\n' "$mtime" "$repo"
done | sort -t$'\t' -k1,1rn | cut -f2 | while read -r repo; do
  name=$(path_to_name "$repo")
  if [[ -z "${_sessions[$name]:-}" && -z "${_seen[$name]:-}" ]]; then
    echo "$name"
  fi
done

all_ssh_hosts
