# dotfiles

Personal dotfiles managed across multiple platforms (NixOS, macOS, and a generic Linux fallback).

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
- `lib/recipe.rb` - mitamae recipes (legacy, migrating to nix)
- `flake.nix` - single flake for NixOS hosts, nix-darwin and home-manager
- `hosts/<host>/` - NixOS host configurations
- `modules/{nixos,darwin,home-manager}/` - shared modules per system type
- `pkgs/` - packages not in nixpkgs
