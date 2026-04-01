# CLAUDE.md

## Package Management Strategy

Priority order for installing packages:

1. **aqua** (preferred) - Lazy installation, Renovate integration. See `config/aqua.yaml`
2. **nix / home-manager** - Same config across OSes. See `nix/home.nix`
3. **Mac App Store** (`masApps`) - For macOS GUI apps; allows manual upgrade timing
4. **Homebrew** (legacy, migrating away) - Managed declaratively via nix-darwin, not directly

Both masApps and Homebrew casks are configured in `nix/modules/darwin.nix`.
