#!/usr/bin/env bash

# Usage: worktree_label <output-variable> <checkout-path> <ghq-root>
# 結果は変数へ返す。一覧の各行で command substitution の subshell を作らないため。
worktree_label() {
  local rel host rest icon repo branch
  rel="${2#"$3"/}"
  host="${rel%%/*}"
  rest="${rel#*/}"

  case "$host" in
    github.com) icon='' ;;
    gitlab.com) icon='' ;;
    *)          icon=$host ;;
  esac

  if [[ "$rest" == */.worktrees/* ]]; then
    repo="${rest%%/.worktrees/*}"
    branch="${rest#*/.worktrees/}"
    branch="${branch#potsbo/}"
    printf -v "$1" '%s %s %s' "$branch" "$icon" "$repo"
  else
    printf -v "$1" '%s %s' "$icon" "$rest"
  fi
}
