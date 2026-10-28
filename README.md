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

### SSH (macOS)

`./install` / `rebuild` はログイン中の Mac ユーザーとして Secure Enclave 内に
取り出し不可の P-256 鍵を作り、次回から同じ鍵を再利用する。追加アプリは不要。
Secure Enclave と `sc_auth create-ctk-identity` 対応の macOS が必要。
herdr の複数ホストへの再接続で毎回承認する負担を避けるため、`-t none` を使う。
SSH のパスフレーズ入力も Touch ID の承認も不要だが、秘密鍵は取り出せない。
Mac 上のプロセスからの署名依頼は承認なしで処理される。

初回は `doctor` に従い、`gh auth login` 後に公開鍵を登録する:

```sh
gh ssh-key add ~/.ssh/id_secure_enclave.pub
ssh -T git@github.com
```

以前の `bio` 版からは新しい鍵になるため、公開鍵を登録し直す。
新しい鍵で接続を確認したら、agent に残っている旧鍵も外す。旧参照を
`id_secure_enclave.bio.pub` に退避してある場合は
`ssh-add -d ~/.ssh/id_secure_enclave.bio.pub`。外さないと転送先で旧鍵が選ばれ、
Touch ID を要求されることがある。

`~/.ssh/id_secure_enclave` は秘密鍵そのものではなく、Mac 固有の鍵への参照情報。
公開鍵とともに gitignore される。再起動後も最初の SSH 接続時に標準 agent に入り、
Linux への agent forwarding でも Mac 側で署名する。
旧 `id_ed25519` は削除しないが、Mac の標準設定では新しい鍵だけを選ぶ。
新しい鍵で接続できることと別の復旧経路を確認してから、旧公開鍵を接続先から削除する。
鍵は別の Mac への移行もバックアップからの復元もできないため、Mac の故障時には
別の管理経路で新しい公開鍵を登録する必要がある。

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
- `hosts/<host>/` - NixOS host configurations (`hosts/raptorlake-win/` だけは Windows ゲストで、PowerShell のスクリプト)
- `modules/{nixos,darwin,home-manager}/` - shared modules per system type
- `pkgs/` - packages not in nixpkgs
