# CLAUDE.md

## Workflow

Commit dotfiles changes directly on `main` — do **not** create a branch or git
worktree unless explicitly asked. These changes are usually meant to be tried
immediately (the repo is symlinked into `~`), so branching just adds friction.

## Cross-platform

Config must work correctly on **both macOS and Linux**. The same repo is
symlinked into `~` on both, so anything platform-specific has to be resolved at
runtime, not baked in.

- **No hardcoded home paths.** Never write `/home/<user>` or `/Users/<user>`
  literally — home differs per OS (`/home/...` on Linux, `/Users/...` on macOS).
  Prefer `~`, `$HOME`, or an XDG var (`$XDG_DATA_HOME`, etc.). When a tool's
  config format can't expand `~`/env vars, find a mechanism that can (a wrapper,
  a generated file, or the tool's own template vars) rather than hardcoding.
- Guard OS-specific commands/paths behind an `uname`/`$OSTYPE` check.

## Package Management Strategy

Priority order for installing packages:

1. **aqua** (preferred) - Lazy installation, Renovate integration. See `home/.config/aquaproj-aqua/aqua.yaml`
2. **nix / home-manager** - Same config across OSes. See `nix/home.nix`
3. **Mac App Store** (`masApps`) - For macOS GUI apps; allows manual upgrade timing
4. **Homebrew** (legacy, migrating away) - Managed declaratively via nix-darwin, not directly

Both masApps and Homebrew casks are configured in `nix/modules/darwin.nix`.
