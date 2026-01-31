{ config, pkgs, lib, accentColor ? "#797979", hostname ? "unknown", dotfilesPath ? "", ... }:

let
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/${path}";

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
in
{
  home.username = "potsbo";
  home.homeDirectory = if pkgs.stdenv.isDarwin then "/Users/potsbo" else "/home/potsbo";
  home.stateVersion = "24.05";
  programs.home-manager.enable = true;
  programs.starship.enable = true;

  # home-manager が .config に書き込まないようにする
  targets.genericLinux.enable = false;

  home.packages = with pkgs; [
    aqua
    zsh
    gcc
    gnumake
    zip
    unzip
    tldr
    nkf
    tmux
    rclone
    whois
    dnsutils
    ijq
    watch
    libyaml
  ] ++ lib.optionals stdenv.isLinux [
    wl-clipboard
  ] ++ lib.optionals stdenv.isDarwin [
    reattach-to-user-namespace
    coreutils
  ];

  # .config は install スクリプトでリンクするので、ここでは設定しない
  home.file = {
    ".ssh".source = link ".ssh";
    ".zshrc".source = link ".zshrc";
    ".vim".source = link ".vim";
    ".tigrc".source = link ".tigrc";
    "bin".source = link "bin";
    ".clipper.json".source = link ".clipper.json";
    ".default-npm-packages".source = link ".default-npm-packages";
    "aqua-checksums.json".source = link "aqua-checksums.json";
    "aqua.yaml".source = link "aqua.yaml";
    "go/src".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/src";
  } // lib.optionalAttrs pkgs.stdenv.isDarwin {
    ".Brewfile".source = link ".Brewfile";
    "iCloudDrive".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Library/Mobile Documents/com~apple~CloudDocs";
  };
}
