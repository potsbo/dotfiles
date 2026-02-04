#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/path-to-name.sh"

export GHQ_ROOT="/home/user/src"

ICON_GITHUB=$(printf '\uea84')
ICON_GITLAB=$(printf '\ue7eb')
ICON_WORKTREE=$(printf '\uef81')

pass=0
fail=0

assert() {
  local description="$1"
  local input="$2"
  local expected="$3"
  local actual
  actual=$("$SCRIPT" "$input")

  if [ "$actual" = "$expected" ]; then
    echo "  PASS: $description"
    pass=$((pass + 1))
  else
    echo "  FAIL: $description"
    echo "    input:    $input"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    fail=$((fail + 1))
  fi
}

echo "=== dirmux/path-to-name tests ==="
echo ""

echo "--- github.com ---"
assert "own repo" \
  "/home/user/src/github.com/potsbo/dotfiles" \
  "$ICON_GITHUB potsbo/dotfiles"

assert "own worktree" \
  "/home/user/src/github.com/potsbo/dotfiles/.worktrees/potsbo/fix-bug" \
  "$ICON_GITHUB potsbo/dotfiles/$ICON_WORKTREE potsbo/fix-bug"

assert "org repo" \
  "/home/user/src/github.com/medicu-inc/api" \
  "$ICON_GITHUB medicu-inc/api"

assert "org worktree" \
  "/home/user/src/github.com/medicu-inc/one/.worktrees/potsbo/bundle-e2e-nix" \
  "$ICON_GITHUB medicu-inc/one/$ICON_WORKTREE potsbo/bundle-e2e-nix"

assert "other owner" \
  "/home/user/src/github.com/kubernetes/kubernetes" \
  "$ICON_GITHUB kubernetes/kubernetes"

assert "other owner worktree" \
  "/home/user/src/github.com/hashicorp/terraform/.worktrees/fix" \
  "$ICON_GITHUB hashicorp/terraform/$ICON_WORKTREE fix"

echo ""
echo "--- gitlab.com ---"
assert "gitlab repo" \
  "/home/user/src/gitlab.com/org/repo" \
  "$ICON_GITLAB org/repo"

assert "gitlab worktree" \
  "/home/user/src/gitlab.com/org/repo/.worktrees/feature" \
  "$ICON_GITLAB org/repo/$ICON_WORKTREE feature"

echo ""
echo "--- other hosts ---"
assert "unknown host" \
  "/home/user/src/sr.ht/user/project" \
  "sr.ht user/project"

echo ""
echo "--- bijection: name uniquely identifies path ---"
assert "potsbo/dotfiles != medicu-inc/dotfiles" \
  "/home/user/src/github.com/medicu-inc/dotfiles" \
  "$ICON_GITHUB medicu-inc/dotfiles"

echo ""
echo "=== Results: $pass passed, $fail failed ==="
[ "$fail" -eq 0 ]
