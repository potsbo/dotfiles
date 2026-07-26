#!/usr/bin/env bash
# Sanitize a string for use as a git branch name
# Usage: echo "some name" | sanitize-branch-name
#    or: sanitize-branch-name "some name"
set -eu

input="${1:-$(cat)}"
echo "$input" | sed 's/ /-/g'
