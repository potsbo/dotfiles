#!/usr/bin/env bash
set -eu

cd "$(dirname "$0")/.."

# イメージをビルド
docker build -t dotfiles-test test/

# hostname を指定しない（linux fallback のテスト）
docker run --rm \
  -v "$(pwd):/dotfiles:ro" \
  dotfiles-test \
  bash -c '
    set -eu

    # dotfiles を配置
    mkdir -p ~/src/github.com/potsbo
    cp -r /dotfiles ~/src/github.com/potsbo/dotfiles 2>/dev/null || true

    # install 実行
    ~/src/github.com/potsbo/dotfiles/install

    # チェック
    export PATH="$HOME/.nix-profile/bin:$HOME/.local/share/aquaproj-aqua/bin:$PATH"
    echo "=== Checking commands ==="
    check() {
      if command -v "$1" &>/dev/null; then
        echo "✓ $1"
      else
        echo "✗ $1"
        exit 1
      fi
    }

    check zsh
    check git
    check nvim
    check fzf
    check rg

    echo "=== All checks passed ==="
  '
