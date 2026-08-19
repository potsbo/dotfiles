# dotfiles

Personal dotfiles managed across multiple platforms (NixOS, Ubuntu, macOS).

Package management strategy is documented in `CLAUDE.md`.

## Setup

```bash
curl -fsSL https://raw.githubusercontent.com/potsbo/dotfiles/main/install | bash
```

### オプション

`./install` は速くて高頻度なものだけを流す (nix / home-manager / symlink)。
遅くて低頻度なものは opt-in。

```bash
./install --apps    # + GUI アプリ (Homebrew cask / Mac App Store, macOS のみ)
./install --cache   # + 遅延インストールされる実体の先読み
./install --all     # 全部 (新マシンの初期化はこれ)
```

curl 経由で渡すときは `| bash -s -- --all`。

`--apps` / `--cache` の中身はそれぞれ `apps` / `cache` コマンドそのもので、
アプリだけ・キャッシュだけ入れ直したいときは直接叩ける。

## Home Manager (PoC)

Home Manager manages packages not available in aqua (e.g., git, mosh).

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

- `home/` - Dotfiles (symlinked to `$HOME`)
- `home/.config/aquaproj-aqua/aqua.yaml` - aqua package definitions
- `lib/recipe.rb` - mitamae recipes (legacy, migrating to nix)
- `nix/` - Nix/home-manager configuration (flake-based)
- `nixos/` - NixOS host configurations
