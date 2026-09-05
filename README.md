# dotfiles

Personal dotfiles managed across multiple platforms (NixOS, macOS, and a generic Linux fallback).

Package management strategy is documented in `CLAUDE.md`.

## Setup

```bash
curl -fsSL https://raw.githubusercontent.com/potsbo/dotfiles/main/install | bash
```

### GUI アプリ (macOS)

Homebrew cask と Mac App Store のアプリは遅いので `./install` からは入れない。
アプリを足した / 消したときだけ `apps` コマンド (home/.local/bin/apps) を叩く。

## Nix

`./install` runs everything (nixos-rebuild on NixOS, nix-darwin on macOS,
home-manager on both). To run one piece by hand:

```bash
cd ~/src/github.com/potsbo/dotfiles
sudo nixos-rebuild switch --flake .#<host>          # NixOS
nix run . -- switch --flake .#<host>               # nix-darwin
nix build .#homeConfigurations.<host>.activationPackage && ./result/activate  # home-manager
```

## Structure

- `home/` - Dotfiles (symlinked to `$HOME`)
- `home/.config/aquaproj-aqua/aqua.yaml` - aqua package definitions
- `modules/home-manager/dotfiles.nix` - symlinks `home/` into `$HOME`
- `flake.nix` - single flake for NixOS hosts, nix-darwin and home-manager
- `hosts/<host>/` - NixOS host configurations
- `modules/{nixos,darwin,home-manager}/` - shared modules per system type
- `pkgs/` - packages not in nixpkgs
