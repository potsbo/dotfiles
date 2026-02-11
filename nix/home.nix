{ config, pkgs, lib, accentColor ? "#797979", hostname ? "unknown", ... }:

let

  aqua =
    let
      version = "2.56.5";
      sources = {
        x86_64-linux = {
          url = "https://github.com/aquaproj/aqua/releases/download/v${version}/aqua_linux_amd64.tar.gz";
          hash = "sha256-nCGl9UdZv/zm/3ukJM6F7RQVkowFyTC+pcA/ghUKtvY=";
        };
        aarch64-linux = {
          url = "https://github.com/aquaproj/aqua/releases/download/v${version}/aqua_linux_arm64.tar.gz";
          hash = "sha256-aPgDUqvX/Z5vOv09BWKv+6QNOVwwhk9RrcaVX7uWyvE=";
        };
        x86_64-darwin = {
          url = "https://github.com/aquaproj/aqua/releases/download/v${version}/aqua_darwin_amd64.tar.gz";
          hash = "sha256-wwhgm020OXqRMxU/9v34+7o5HW1i7ir18nt2vwHwqhs=";
        };
        aarch64-darwin = {
          url = "https://github.com/aquaproj/aqua/releases/download/v${version}/aqua_darwin_arm64.tar.gz";
          hash = "sha256-+yW5py9CvgaXC7czWAMwW4KZ5FT2HtyRJYVqg1yFI58=";
        };
      };
      src = sources.${pkgs.stdenv.hostPlatform.system};
    in
    pkgs.stdenv.mkDerivation {
      pname = "aqua";
      inherit version;

      src = pkgs.fetchurl {
        inherit (src) url hash;
      };

      sourceRoot = ".";

      installPhase = ''
        mkdir -p $out/bin
        cp aqua $out/bin/
      '';
    };

  opener = pkgs.buildGoModule {
    pname = "opener";
    version = "0.1.6";

    src = pkgs.fetchFromGitHub {
      owner = "superbrothers";
      repo = "opener";
      rev = "v0.1.6";
      hash = "sha256-rYeQ45skFXWxdxMj0dye8IBEYcQCRqdt9nLVXF36od8=";
    };

    vendorHash = "sha256-lju+QlWxUb11UV9NvXSgQ+ZG37WhyZVahJTM5voDEfw=";
  };

in
{
  home.username = "potsbo";
  home.homeDirectory = if pkgs.stdenv.isDarwin then "/Users/potsbo" else "/home/potsbo";
  home.stateVersion = "24.05";
  programs.home-manager.enable = true;
  programs.starship.enable = true;

  # home-manager 内部で builtins.toFile が store path を参照する際の警告を回避
  # 原因は home-manager が nixpkgs の meta.nix を参照する実装にあり、このコードベースでは修正不可
  # https://github.com/nix-community/home-manager/issues/7935
  manual.manpages.enable = false;

  # home-manager が .config に書き込まないようにする
  targets.genericLinux.enable = false;

  # Nix の gcc は macOS SDK のライブラリパスを検索しないため、
  # cargo crate (tokei 等) のビルド時に -liconv が見つからずリンクエラーになる。
  home.sessionVariables = lib.optionalAttrs pkgs.stdenv.isDarwin {
    LIBRARY_PATH = "${pkgs.libiconv}/lib";
  };

  home.packages = with pkgs; [
    aqua
    # cargo は aqua 管理の tokei (cargo crate) のビルドに必要。
    # rustup は aqua で入るが、toolchain install を別途実行しないと cargo が使えず、
    # aqua install を最低でも2回に分ける必要が出てしまうため nix で直接入れる。
    cargo
    btop # aqua では macos 用のバイナリが提供されていない
    whois
    dnsutils
    rclone

    # 以下 aqua 未提供
    tmux
    gcc
    gnumake
    cmake
    zip
    unzip
    nkf
    watch
    libyaml
    pv
  ] ++ lib.optionals stdenv.isLinux [
    wl-clipboard
  ] ++ lib.optionals stdenv.isDarwin [
    reattach-to-user-namespace
    coreutils
    opener
  ];
}
