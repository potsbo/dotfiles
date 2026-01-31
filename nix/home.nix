{ config, pkgs, lib, accentColor ? "#797979", hostname ? "unknown", dotfilesPath ? "", ... }:

let
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/config/${path}";
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
  ] ++ lib.optionals stdenv.isLinux [
    wl-clipboard
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
