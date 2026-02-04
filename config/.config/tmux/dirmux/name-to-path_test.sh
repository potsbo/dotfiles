#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENCODE="$SCRIPT_DIR/path-to-name.sh"
DECODE="$SCRIPT_DIR/name-to-path.sh"

export GHQ_ROOT="/home/user/src"

pass=0
fail=0

# Test that name-to-path is the exact inverse of path-to-name
assert_roundtrip() {
  local description="$1"
  local path="$2"
  local name
  name=$("$ENCODE" "$path")
  local restored
  restored=$("$DECODE" "$name")

  if [ "$restored" = "$path" ]; then
    echo "  PASS: $description"
    pass=$((pass + 1))
  else
    echo "  FAIL: $description"
    echo "    path:     $path"
    echo "    name:     $name"
    echo "    restored: $restored"
    fail=$((fail + 1))
  fi
}

echo "=== dirmux/name-to-path tests (roundtrip) ==="
echo ""

echo "--- github.com ---"
assert_roundtrip "own repo" \
  "/home/user/src/github.com/potsbo/dotfiles"

assert_roundtrip "own worktree" \
  "/home/user/src/github.com/potsbo/dotfiles/.worktrees/potsbo/fix-bug"

assert_roundtrip "org repo" \
  "/home/user/src/github.com/medicu-inc/api"

assert_roundtrip "org worktree" \
  "/home/user/src/github.com/medicu-inc/one/.worktrees/potsbo/bundle-e2e-nix"

assert_roundtrip "other owner" \
  "/home/user/src/github.com/kubernetes/kubernetes"

assert_roundtrip "other owner worktree" \
  "/home/user/src/github.com/hashicorp/terraform/.worktrees/fix"

echo ""
echo "--- gitlab.com ---"
assert_roundtrip "gitlab repo" \
  "/home/user/src/gitlab.com/org/repo"

assert_roundtrip "gitlab worktree" \
  "/home/user/src/gitlab.com/org/repo/.worktrees/feature"

echo ""
echo "--- other hosts ---"
assert_roundtrip "unknown host" \
  "/home/user/src/sr.ht/user/project"

echo ""
echo "=== Results: $pass passed, $fail failed ==="
[ "$fail" -eq 0 ]
