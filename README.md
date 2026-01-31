# dotfiles

Personal dotfiles managed across multiple platforms (NixOS, Ubuntu, macOS).

## Package Management Strategy

1. **aqua** (preferred)
   - Renovate integration for automated updates
   - Lazy installation
   - Works in GitHub Codespaces and similar environments
   - See `config/aqua.yaml` for managed packages

2. **nix / home-manager** (fallback)
   - For packages not available in aqua
   - System-level configuration
   - Platform-specific settings

3. **Homebrew / apt** (legacy, migrating away)
   - Gradually moving to aqua or nix

## Setup

```bash
curl -fsSL https://raw.githubusercontent.com/potsbo/dotfiles/main/install | bash
```

## Home Manager (PoC)

Home Manager manages packages not available in aqua (e.g., git, tmux).

### First-time setup

```bash
# Install nix (if not already installed)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Apply home-manager configuration
cd ~/src/github.com/potsbo/dotfiles/nix

# Linux
nix run home-manager -- switch --flake .#potsbo@linux

# macOS (Apple Silicon)
nix run home-manager -- switch --flake .#potsbo@darwin-arm

# macOS (Intel)
nix run home-manager -- switch --flake .#potsbo@darwin-x86
```

### Subsequent updates

```bash
cd ~/src/github.com/potsbo/dotfiles/nix
home-manager switch --flake .#potsbo@linux  # or darwin-arm, darwin-x86
```

## Structure

- `config/` - Dotfiles (symlinked to `$HOME`)
- `config/aqua.yaml` - aqua package definitions
- `lib/recipe.rb` - mitamae recipes (legacy, migrating to nix)
- `nix/` - Nix/home-manager configuration (flake-based)
- `nixos/` - NixOS host configurations
