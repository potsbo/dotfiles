{ config, pkgs, lib, accentColor ? "#797979", hostname ? "unknown", ... }:

let

  aqua =
    let
      # renovate: datasource=github-releases depName=aquaproj/aqua
      version = "2.57.1";
    in
    pkgs.buildGoModule.override { go = pkgs.go_1_26; } {
      pname = "aqua";
      inherit version;

      src = pkgs.fetchFromGitHub {
        owner = "aquaproj";
        repo = "aqua";
        rev = "v${version}";
        hash = "sha256-ZxSRUVhDDW8+GGqLV7gia/zH1wa9e1iU3vG3RCV7cmI=";
      };

      vendorHash = "sha256-kN7FxyVy2QFLkC/fiYGIuf3/6PrUoC2CMY5sQMuBLPE=";

      # テスト実行をスキップする。
      # aqua のテストが /bin/date をハードコードしており、nix サンドボックスには存在しないため失敗する。
      # aqua 本体の品質は upstream CI で担保されているため、ここでのテストは不要。
      doCheck = false;
    };

  tiri = pkgs.buildGoModule {
    pname = "tiri";
    version = "0-unstable-2025-06-28";

    src = pkgs.fetchFromGitHub {
      owner = "potsbo";
      repo = "tiri";
      rev = "00d26cf930cbe923ca26081d06f18b2046f490dd";
      hash = "sha256-0H8cdls7OUYX3gtG26yOII3+XvBMaKEbCNDcAt980h8=";
    };

    vendorHash = "sha256-jEdOBs7cdVOJFH1yevbfFia4pp3LqOFpSgLNNIk7YQM=";
  };

  tuicast = pkgs.buildGoModule {
    pname = "tuicast";
    version = "0-unstable-2026-06-27";

    src = pkgs.fetchFromGitHub {
      owner = "potsbo";
      repo = "tuicast";
      rev = "0551c8932de61f83014e42a78ecaf184a3e4b378";
      hash = "sha256-VBYaJOa+mZu2kaXeb1gQaS3t1wF72WTif3SNPB0gbFY=";
    };

    vendorHash = "sha256-g+yaVIx4jxpAQ/+WrGKxhVeliYx7nLQe/zsGpxV4Fn4=";
  };

  todoist-cli = pkgs.buildNpmPackage {
    pname = "todoist-cli";
    # renovate: datasource=github-releases depName=Doist/todoist-cli
    version = "3.0.0";

    src = pkgs.fetchFromGitHub {
      owner = "Doist";
      repo = "todoist-cli";
      rev = "v1.26.0";
      hash = "sha256-JIuvQjj7d99cVv1JUB3QweWDwlvMRO/tLa55Yvaav5Q=";
    };

    npmDepsHash = "sha256-6aSUy6YUtgTN5E64cVRJXFqzJcVZzsoIJArp1s5/cRs=";
  };

in
{
  home.username = "potsbo";
  home.homeDirectory = if pkgs.stdenv.isDarwin then "/Users/potsbo" else "/home/potsbo";
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
    LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.unixODBC pkgs.freetds ];
    # odbcinst.ini の検索先ディレクトリ
    ODBCSYSINI = "${config.home.homeDirectory}/.config/odbc";
  } // lib.optionalAttrs pkgs.stdenv.isDarwin {
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

  # FreeTDS ODBC ドライバの登録
  home.file.".config/odbc/odbcinst.ini".text = ''
    [FreeTDS]
    Description=FreeTDS ODBC Driver
    Driver=${pkgs.freetds}/lib/libtdsodbc.so
    UsageCount=1
  '';

  home.packages = with pkgs; [
    aqua
    tiri
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

    # ODBC (arrow-odbc + FreeTDS で SQL Server から Arrow ネイティブ読み取り)
    unixODBC
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
  ] ++ lib.optionals stdenv.isLinux [
    wl-clipboard
  ] ++ lib.optionals stdenv.isDarwin [
    coreutils
  ];

  # linux ホストの open/xdg-open を Mac 側で開くためのリスナー。
  # inetd 互換モード: launchd が 127.0.0.1:2226 を listen し、接続ごとに
  # opener-listen を socket 繋ぎで起動する。ssh の RemoteForward
  # (config/.ssh/config) がこのポートへ各 linux ホストの 2226 を繋ぐ。
  launchd.agents = lib.optionalAttrs pkgs.stdenv.isDarwin {
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
