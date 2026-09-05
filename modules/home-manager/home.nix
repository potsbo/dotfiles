{ config, pkgs, lib, accentColor ? "#797979", hostname ? "unknown", ... }:

let

  # 別ファイルなのは nix-update が flake output 経由でハッシュを自動更新するため。
  # nix-update は derivation の meta.position を見て書き戻すので、let 束縛のままだと扱えない。
  aqua = pkgs.callPackage ../../pkgs/aqua.nix { };

  tuicast = pkgs.callPackage ../../pkgs/tuicast.nix { };

  todoist-cli = pkgs.callPackage ../../pkgs/todoist-cli.nix { };

  evalcache = pkgs.callPackage ../../pkgs/evalcache.nix { };

in
{
  home.username = "potsbo";
  home.homeDirectory = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/potsbo" else "/home/potsbo";
  home.stateVersion = "24.05";
  programs.home-manager.enable = true;
  programs.starship.enable = true;
  # eza は aqua でも管理できるが、zsh completion を自動で fpath に配置するために home-manager を使う。
  # aqua は completion ファイルを展開せず、eza 自体にも `eza completion zsh` のような生成コマンドがないため。
  programs.eza.enable = true;
  programs.eza.enableZshIntegration = false; # エイリアスは不要、completion だけ欲しい

  # home-manager 内部で builtins.toFile が store path を参照する際の警告を回避
  # 原因は home-manager が nixpkgs の meta.nix を参照する実装にあり、このコードベースでは修正不可
  # https://github.com/nix-community/home-manager/issues/7935
  manual.manpages.enable = false;

  # home-manager が .config に書き込まないようにする
  targets.genericLinux.enable = false;

  # Nix の gcc は macOS SDK のライブラリパスを検索しないため、
  # cargo crate (tokei 等) のビルド時に -liconv が見つからずリンクエラーになる。
  home.sessionVariables = {
    # arrow-odbc が libodbc.so.2 を見つけるために必要
    LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.unixodbc pkgs.freetds ];
    # odbcinst.ini の検索先ディレクトリ
    ODBCSYSINI = "${config.home.homeDirectory}/.config/odbc";
    # npm cache を XDG へ。npm は $HOME 直下を決め打ちするため変数で変更する。
    # home-manager を単一ソースにする理由: 対話 shell を経ずに npx を叩く背景プロセス
    # (npx 製 MCP サーバ等) にも hm-session-vars 経由で継承させ ~/.npm 生成を防ぐ。
    # 他ツール (cargo/rustup 等) は .zshenv 側に集約。npm だけ背景プロセス対策で例外。
    NPM_CONFIG_CACHE = "${config.home.homeDirectory}/.cache/npm";
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

  # zsh plugins (.zshrc から source する)。以前は ghq clone だったのを nix 管理に
  # 置き換えたもので、配置は ghq 規約のパスのまま維持している。
  home.file."src/github.com/romkatv/zsh-defer".source = "${pkgs.zsh-defer}/share/zsh-defer";
  home.file."src/github.com/mroth/evalcache".source = "${evalcache}/share/evalcache";

  # 移行前の ghq clone が実体ディレクトリとして残っていると symlink を張れず
  # activation が止まる (force = true もディレクトリには効かない) ので先に消す。
  # symlink になっていれば管理済みなので触らない。
  home.activation.removeStaleZshPluginClones = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    for dir in \
      "$HOME/src/github.com/romkatv/zsh-defer" \
      "$HOME/src/github.com/mroth/evalcache"; do
      if [ -d "$dir" ] && [ ! -L "$dir" ]; then
        run rm -rf "$dir"
      fi
    done
  '';

  # FreeTDS ODBC ドライバの登録
  home.file.".config/odbc/odbcinst.ini".text = ''
    [FreeTDS]
    Description=FreeTDS ODBC Driver
    Driver=${pkgs.freetds}/lib/libtdsodbc.so
    UsageCount=1
  '';

  home.packages = with pkgs; [
    aqua
    tuicast
    # todoist-cli # install がハングするようになってしまった
    # cargo は aqua 管理の tokei (cargo crate) のビルドに必要。
    # rustup は aqua で入るが、toolchain install を別途実行しないと cargo が使えず、
    # aqua install を最低でも2回に分ける必要が出てしまうため nix で直接入れる。
    # cargo と rustc はバージョンが一致しないとビルドエラーになるため両方入れる。
    cargo
    rustc
    temurin-bin-17 # H2O AutoML が JVM を要求する
    btop # aqua では macos 用のバイナリが提供されていない
    whois
    dnsutils
    rclone
    elan # Lean toolchain manager (rustup 相当)。aqua 未登録

    # ODBC (arrow-odbc + FreeTDS で SQL Server から Arrow ネイティブ読み取り)
    unixodbc
    freetds

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
    mosh
    groff # aws help が man 整形に要求する
    chafa # 端末に画像を出す
  ] ++ lib.optionals stdenv.hostPlatform.isLinux [
    wl-clipboard
  ] ++ lib.optionals stdenv.hostPlatform.isDarwin [
    coreutils
  ];

  # linux ホストの open/xdg-open を Mac 側で開くためのリスナー。
  # inetd 互換モード: launchd が 127.0.0.1:2226 を listen し、接続ごとに
  # opener-listen を socket 繋ぎで起動する。ssh の RemoteForward
  # (hosts.nix の programs.ssh) がこのポートへ各 linux ホストの 2226 を繋ぐ。
  launchd.agents = lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
    opener-listen = {
      enable = true;
      config = {
        ProgramArguments = [ "${config.home.homeDirectory}/.local/bin/opener-listen" ];
        Sockets = {
          Listener = {
            SockNodeName = "127.0.0.1";
            SockServiceName = "2226";
          };
        };
        inetdCompatibility = { Wait = false; };
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/opener-listen.log";
      };
    };
  };
}
