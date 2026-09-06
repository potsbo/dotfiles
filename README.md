# dotfiles

Personal dotfiles managed across multiple platforms (NixOS and macOS).

Package management strategy is documented in `CLAUDE.md`.

## Setup

```bash
curl -fsSL https://raw.githubusercontent.com/potsbo/dotfiles/main/install | bash
```

### GUI アプリ (macOS)

Homebrew cask と Mac App Store のアプリは遅いので `rebuild` からは入れない。
アプリを足した / 消したときだけ `apps` コマンド (home/.local/bin/apps) を叩く。

## Nix

`install` は nix の導入と clone だけをして `rebuild` (home/.local/bin/rebuild) に
渡す。設定を変えたあとの再適用は `rebuild` を叩く (nixos-rebuild on NixOS,
nix-darwin on macOS, home-manager はそのモジュールとして一緒に当たる)。
中身を手で打つなら:

```bash
cd ~/src/github.com/potsbo/dotfiles
sudo nixos-rebuild switch --flake .#<host>          # NixOS
nix run . -- switch --flake .#<host>               # nix-darwin
```

## Structure

- `home/` - Dotfiles (symlinked to `$HOME`)
- `home/.config/aquaproj-aqua/aqua.yaml` - aqua package definitions
- `modules/home-manager/dotfiles.nix` - symlinks `home/` into `$HOME`
- `flake.nix` - single flake for NixOS hosts, nix-darwin and home-manager
- `hosts/<host>/` - NixOS host configurations
- `modules/{nixos,darwin,home-manager}/` - shared modules per system type
- `pkgs/` - packages not in nixpkgs
