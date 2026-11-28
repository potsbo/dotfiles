{ config, pkgs, lib, rex, ... }:

let

  # この repo で package 化したもの (localPkgs.aqua のように参照する)。
  # 別ファイルなのは nix-update が flake output 経由でハッシュを自動更新するため。
  # nix-update は derivation の meta.position を見て書き戻すので、let 束縛のままだと扱えない。
  # 名前を列挙せず pkgs/ を読むのは flake.nix の packages と同じ理由。
  localPkgs = lib.packagesFromDirectoryRecursive {
    inherit (pkgs) callPackage;
    directory = ../../pkgs;
  };

in
{
  programs = {
    home-manager.enable = true;
    # starship は aqua でなく nix で入れる。プロンプト 1 回で 2 回 (左右)、起動時はさらに 1 回
    # 呼ばれるので、aqua-proxy が呼び出しごとに足す ~12ms (config と registry の読み込み) が
    # そのまま効く。実測で shell の起動が 78ms → 42ms (phoenix)。aqua.yaml に戻さないこと。
    starship.enable = true;
    # eza は aqua でも管理できるが、zsh completion を自動で fpath に配置するために home-manager を使う。
    # aqua は completion ファイルを展開せず、eza 自体にも `eza completion zsh` のような生成コマンドがないため。
    eza.enable = true;
    eza.enableZshIntegration = false; # エイリアスは不要、completion だけ欲しい
  };

  # home-manager 内部で builtins.toFile が store path を参照する際の警告を回避
  # 原因は home-manager が nixpkgs の meta.nix を参照する実装にあり、このコードベースでは修正不可
  # https://github.com/nix-community/home-manager/issues/7935
  manual.manpages.enable = false;

  # home-manager が .config に書き込まないようにする
  targets.genericLinux.enable = false;

  home = {
    stateVersion = "24.05";

    # Nix の gcc は macOS SDK のライブラリパスを検索しないため、
    # cargo crate (tokei 等) のビルド時に -liconv が見つからずリンクエラーになる。
    sessionVariables = {
      # npm cache を XDG へ。npm は $HOME 直下を決め打ちするため変数で変更する。
      # home-manager を単一ソースにする理由: 対話 shell を経ずに npx を叩く背景プロセス
      # (npx 製 MCP サーバ等) にも hm-session-vars 経由で継承させ ~/.npm 生成を防ぐ。
      # 他ツール (cargo/rustup 等) は .zshenv 側に集約。npm だけ背景プロセス対策で例外。
      NPM_CONFIG_CACHE = "${config.home.homeDirectory}/.cache/npm";
      # nixpkgs の rustc は rust-src を同梱せず、rust-analyzer (nvim では mason 管理) が
      # sysroot から std を解決できない。store path は lua に書けないのでここで渡す。
      RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
    } // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
      LIBRARY_PATH = "${pkgs.libiconv}/lib";

      # home-manager の gcc が cc/c++ として PATH 先頭に来る (.zshenv) が、
      # この gcc は現行の macOS SDK ヘッダ (例: mach/message.h の clang 専用マクロ)
      # をコンパイルできず、ソースビルドを伴う C/C++ 拡張 (uv sync での xgboost-cpu 等)
      # が落ちる。macOS のビルドには Apple clang を使わせる。
      # CMake / cargo / cgo / setuptools はいずれも CC/CXX を尊重する。
      # GCC 固有のビルドが必要な場合はそのコマンドだけ CC=... で局所上書きする。
      CC = "/usr/bin/clang";
      CXX = "/usr/bin/clang++";
    };

    file = {
      # zsh plugins (.zshrc から source する)。以前は ghq clone だったのを nix 管理に
      # 置き換えたもので、配置は ghq 規約のパスのまま維持している。
      "src/github.com/romkatv/zsh-defer".source = "${pkgs.zsh-defer}/share/zsh-defer";
      "src/github.com/mroth/evalcache".source = "${localPkgs.evalcache}/share/evalcache";

      # プロフィール画像。DMS (ロック画面、コントロールセンター) と GDM は AccountsService の
      # IconFile を見て、それが ~/.face を指している。GitHub のアイコンを使う。画像が変わったら
      # hash を更新する (nix-prefetch-url https://github.com/potsbo.png)。
      ".face".source = pkgs.fetchurl {
        url = "https://github.com/potsbo.png";
        hash = "sha256-vL+tQ5Xvfm+/HU9XRdxdsoZTG9b21AZ8szjYLuKFgBQ=";
      };

      # login(1) が pane / タブを開くたびに出す "Last login: ..." と motd を消す。macOS の端末
      # (Rex, Terminal.app) は login -f 経由でシェルを起動するので毎回出る。sshd も同じファイルを
      # 見るため ssh ログイン時の Last login も消え、不正ログインに気づく手がかりが一つ減るが、
      # 受け入れている。中身は見られず存在だけで効くので、作業ツリーではなく store から張る。
      ".hushlogin".text = "";
    };

    # 移行前の ghq clone が実体ディレクトリとして残っていると symlink を張れず
    # activation が止まる (force = true もディレクトリには効かない) ので先に消す。
    # symlink になっていれば管理済みなので触らない。
    activation.removeStaleZshPluginClones = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      for dir in \
        "$HOME/src/github.com/romkatv/zsh-defer" \
        "$HOME/src/github.com/mroth/evalcache"; do
        if [ -d "$dir" ] && [ ! -L "$dir" ]; then
          run rm -rf "$dir"
        fi
      done
    '';

    packages = with pkgs; [
      localPkgs.aqua
      localPkgs.cascp
      # macOS の /usr/bin/git (Apple Git) は版が古く upstream から遅れるので、全ホストで
      # nixpkgs (unstable) の git に揃える。設定は programs.git ではなく home/.config/git/config。
      git
      # macOS の /usr/bin/rsync は openrsync (protocol 29) で、Linux の rsync 3.x の
      # オプション (--info=progress2, --mkpath, -A/-X 等) が通らない。
      rsync
      # cargo は aqua 管理の tokei (cargo crate) のビルドに必要。
      # rustup は aqua で入るが、toolchain install を別途実行しないと cargo が使えず、
      # aqua install を最低でも2回に分ける必要が出てしまうため nix で直接入れる。
      # cargo と rustc はバージョンが一致しないとビルドエラーになるため両方入れる。
      cargo
      rustc
      btop # aqua では macos 用のバイナリが提供されていない
      whois
      dnsutils
      rclone

      # 以下 aqua 未提供
      gcc
      gnumake
      cmake
      zip
      unzip
      nkf
      watch
      libyaml
      pv
      groff # aws help が man 整形に要求する

      # LazyVim の lang.nix extra が nix 保存時に nvim-lint 経由で呼ぶ。aqua 標準レジストリ未登録。
      # 同 extra が formatter に指定する nixfmt は入れていない: このリポジトリの 1 行 attrset
      # スタイルをほぼ全ファイル書き換えてしまうので、保存時整形は無効のままにしておく。
      statix
    ] ++ lib.optionals stdenv.hostPlatform.isLinux [
      # Codex の Linux sandbox 用。PATH 上の bwrap を使い、同梱 helper への依存を避ける。
      bubblewrap
      rex.packages.${stdenv.hostPlatform.system}.default
      wl-clipboard
    ] ++ lib.optionals stdenv.hostPlatform.isDarwin [
      # BSD 版を GNU 版で PATH ごと上書きし、Linux ホストと同じ挙動に揃える (NixOS 側は
      # 元から GNU)。g 接頭辞や対話 shell だけの alias にしないのは意図的: `uname` で
      # macOS を判定して BSD 構文 (`sed -i ''`, `stat -f` 等) を渡すサードパーティの
      # script は壊れうるが、その都度直す方を取った。
      coreutils
      gnused
      gawk
      gnugrep
      findutils
      diffutils
      gnupatch
      gnutar
      gzip
    ];
  };
}
