{ config, pkgs, lib, accentColor ? "#797979", hostname ? "unknown", ... }:

{
  home.username = "potsbo";
  home.homeDirectory = if pkgs.stdenv.isDarwin then "/Users/potsbo" else "/home/potsbo";
  home.stateVersion = "24.05";
  programs.home-manager.enable = true;
  programs.starship.enable = true;
}
