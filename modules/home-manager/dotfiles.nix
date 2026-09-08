# リポジトリの home/ を ~ に張る symlink。lib/recipe.rb (mitamae) の置き換え。
#
# store を経由せず、リポジトリの作業ツリーを直接指す。ツールが ~/.config 配下に
# 書いた設定がそのまま git status に現れて気づける、というのが今の運用の要で、
# store (読み取り専用) へのリンクにするとそれが壊れる。
#
# ディレクトリ (.config など) とファイルで張り方が違う:
#
# - ファイルは home.file + mkOutOfStoreSymlink。home-manager の標準機能。
# - ディレクトリは activation script で ln -sfn する。home.file で ~/.config を
#   丸ごと symlink にすると、home-manager 自身が ~/.config 配下に生成するファイル
#   (starship.toml, systemd の user unit, environment.d) を「$HOME の外」と判定して
#   ビルドが落ちる。ln で張った symlink ならそれらは今までどおり symlink 越しに
#   リポジトリ側へ落ちる (gitignore 済み)。.config を丸ごと 1 本にするのは
#   「知らないファイルが追加されたときに気づく」ためで、個別リンクにはしない。
{ config, lib, pkgs, ... }:

let
  inherit (config.lib.file) mkOutOfStoreSymlink;
  repoHome = "${config.home.homeDirectory}/src/github.com/potsbo/dotfiles/home";

  dirLinks = [
    ".config"
    ".local/bin"
    ".ssh"
  ];

  fileLinks = [
    ".zshenv"
    ".zprofile"
    ".zshrc"
    # .claude はセッション状態などが多いのでディレクトリごとはリンクせず settings.json だけ管理する。
    # 注意: herdr が integration 更新時にこのファイルを書き直す (二重登録や再整形の diff が出たらこの管理をやめる)
    ".claude/settings.json"
    ".claude/claude-powerline.json"
    # .codex もセッション状態などを含むため、設定ファイルだけ管理する。
    ".codex/config.toml"
  ];
in
{
  home = {
    file = lib.genAttrs fileLinks (path: { source = mkOutOfStoreSymlink "${repoHome}/${path}"; })
      // {
        # go/src -> ~/src
        "go/src".source = mkOutOfStoreSymlink "${config.home.homeDirectory}/src";
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin (lib.genAttrs
        (map (app: "Library/Application Support/${app}/User/settings.json") [ "Cursor" "Code" ])
        (_: { source = mkOutOfStoreSymlink "${repoHome}/.config/cursor/user/settings.json"; }));

    activation = {
      # writeBoundary より前に張るのは、この後の linkGeneration が
      # ~/.config/starship.toml 等を symlink 越しに書くため。
      #
      # 新規マシンで ~/.config や ~/.ssh が実ディレクトリとして先にできていると
      # (NixOS の activation が ~/.config/mozc を作る、ssh が known_hosts を作る)、
      # ln -T が "cannot overwrite directory" で止まる。中身をリポジトリ側の home/ へ
      # mv してから rebuild を打ち直す。黙って中にリンクを作られるより失敗する方を選ぶ。
      linkDotfileDirs = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
        for rel in ${lib.escapeShellArgs dirLinks}; do
          run mkdir -p "$(dirname "$HOME/$rel")"
          run ln -sfnT "${repoHome}/$rel" "$HOME/$rel"
        done
      '';

      # nix に GitHub のトークンを渡す (home/.config/nix/nix.conf が include する)。
      # 未認証だと GitHub API が 60 req/hour で、nix flake update が 403 で落ちる。
      # gh を使うので新規に PAT を発行しなくてよい。gh 未認証なら黙って飛ばす。
      # 書き込み先は ~/.config ではなくリポジトリ側 (同じ場所を指す symlink だが、
      # gitignore 済みの実体として置く)。トークンをログに出さないよう run は使わない。
      writeNixGithubToken = lib.hm.dag.entryAfter [ "installPackages" ] ''
        export AQUA_GLOBAL_CONFIG="${repoHome}/.config/aquaproj-aqua/aqua.yaml"
        if [ -z "''${DRY_RUN:-}" ] && token="$("${config.home.profileDirectory}/bin/aqua" exec -- gh auth token 2>/dev/null)" && [ -n "$token" ]; then
          (umask 077; printf 'access-tokens = github.com=%s\n' "$token" >"${repoHome}/.config/nix/access-tokens.conf")
        fi
      '';

      # aqua は lazy install なので、aqua.yaml に足しただけでは shim (~/.local/share/
      # aquaproj-aqua/bin/*) が無く、コマンドが PATH に出てこない。-l で shim だけ張る
      # (本体は初回実行時に落ちる)。-a が要るのは、aqua i が既定でカレントディレクトリ側の
      # aqua.yaml しか見ず、ここの設定は global config だから。
      # .zshrc の precmd も同じことをするので、これが無くても次のプロンプトでは揃う。
      # ここでやるのは switch した直後のそのシェルで使えるようにするため。
      # 失敗しても activation は落とさない: registry の取得にネットが要り、圏外や GitHub の
      # rate limit で失敗しうる。module mode では boot 時の home-manager-<user>.service でも
      # 走るので、落とすと起動が degraded になる。
      linkAquaShims = lib.hm.dag.entryAfter [ "installPackages" ] ''
        export AQUA_GLOBAL_CONFIG="${repoHome}/.config/aquaproj-aqua/aqua.yaml"
        export AQUA_POLICY_CONFIG="${repoHome}/.config/aquaproj-aqua/aqua-policy.yaml"
        run "${config.home.profileDirectory}/bin/aqua" install --only-link --all || \
          warnEcho "aqua i -l -a に失敗した (ネットワーク?)"
      '';

      # Hunk (hunk.dev) 同梱のレビュースキルを user skill として全 repo に見せる。
      # これが無いと別 repo で Hunk セッションを認識できずエージェントが暴走する。
      # 実体パスは OS とバージョンで変わるため hardcode せず `hunk skill path` で
      # 毎回解決し、現在インストール済みの版へ貼り直す。hunk は aqua の lazy install
      # なので aqua exec 経由で叩く。aqua か hunk が未導入なら no-op。
      # activation の PATH に aqua は無い (system 側から呼ばれる) ので profile の実体を叩く。
      linkHunkReviewSkill = lib.hm.dag.entryAfter [ "installPackages" ] ''
        export AQUA_GLOBAL_CONFIG="${repoHome}/.config/aquaproj-aqua/aqua.yaml"
        if p="$("${config.home.profileDirectory}/bin/aqua" exec -- hunk skill path 2>/dev/null)" && [ -n "$p" ]; then
          link="$HOME/.claude/skills/hunk-review"
          if [ "$(readlink "$link" 2>/dev/null)" != "$(dirname "$p")" ]; then
            run mkdir -p "$HOME/.claude/skills"
            run ln -sfn "$(dirname "$p")" "$link"
          fi
        fi
      '';
    };
  };
}
