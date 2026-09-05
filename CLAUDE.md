# CLAUDE.md

## Workflow

Commit dotfiles changes directly on `main` — do **not** create a branch or git
worktree unless explicitly asked. These changes are usually meant to be tried
immediately (the repo is symlinked into `~`), so branching just adds friction.

### Staging

**`git add -A` / `git add .` は絶対に使わない。** 明示パスか、追跡済みだけの
`git add -u` を使う。`home/.config` は丸ごと `~` に symlink されていて、gcloud の
認証情報・1Password の DB・Chrome プロファイルなど数万の実行時ファイルが
gitignore だけで除外されている。2026-07-26 に、リネームで gitignore の
path-anchor が外れたところへ `git add -A` を打って約 34,900 件を commit し、
履歴の書き換えと gc が必要になった。`git add` が数分かかったらこれが起きている。

ここのファイルを移動・リネームするときは、旧パスを全レイヤの gitignore
(root `.gitignore`, `home/.gitignore`, `home/.config/.gitignore`,
`.git/info/exclude`, `home/.config/git/ignore`) で grep すること。
ディレクトリを守る規則はそのディレクトリ自身の `.gitignore` に相対パスで置く
(root に path-anchor しない)。リネームで壊れないようにそう再構成してある (cb7311a)。

## Recording decisions

設計判断とそのトレードオフ、とくに「なぜこうしていないか」は、該当する設定の
直上にコメントとして残す。あとから見た人 (人でもエージェントでも) が同じ穴を
「不備だ」と再指摘して掘り返すのを止めるのが目的なので、判断がコードと一緒に
移動する場所に置くこと。

エージェント側の私的なメモ (memory) は原則使わない。作業の進め方への指摘も、
該当する規則の直上か CLAUDE.md に書く。例外は、リポジトリに置けないものだけ:
マシン特有の状態 (鍵の失効日など) と、公開リポジトリに載せるのが不適切な内容。

書くのは why だけ。コードやパスを読めば分かること — 値がどこから来たか、他に誰が
呼んでいるか、次の行が何をするか — は書かない。

## Changing how something is managed

ここの規則は「別の目的の作業のついでに mutation を増やすな」という意味。明確に
refactoring や再構成を頼まれたときは適用しない。その場合は構造を変える案も規則を
理由に落とさず選択肢に出し、コストと利点で比較する。壊してはいけないのは、`~` への
symlink 先や他ホストから参照される実行時パスのような、事実として依存があるものだけ。

- **配置パスは変えない。** 管理機構を差し替える (ghq clone → nix 管理 など) ときも、
  既存のパスは維持してリンク先だけ差し替える。パスは他の設定や手の癖から参照される。
- **独自の機構より標準の仕組みを優先する。** 多少の性能差なら標準側を取る。独自機構は
  積み上がって保守負債になる。実際、`install` の自作スタンプキャッシュ (no-op 0.14s)
  は Nix 自身の eval cache (~3s) を使う形に置き換えて捨てた。自作を提案するなら
  トレードオフとして明示し、差が大きくない限り不採用が既定と考えること。

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

`avalanche` (メインの Mac) は ssh を受け付けない。Mac 側にしか効かない変更は
リポジトリに入れたうえで、本人が Mac で `home-manager switch` を打つ必要がある。

## Package Management Strategy

Priority order for installing packages:

1. **aqua** (preferred) - Lazy installation, Renovate integration. See `home/.config/aquaproj-aqua/aqua.yaml`
2. **nix / home-manager** - Same config across OSes. See `modules/home-manager/home.nix`
3. **Mac App Store** (`masApps`) - For macOS GUI apps; allows manual upgrade timing
4. **Homebrew** (legacy, migrating away) - Managed declaratively via nix-darwin, not directly

Both masApps and Homebrew casks are configured in `modules/darwin/`.
