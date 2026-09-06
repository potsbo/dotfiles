{ config, pkgs, lib, ... }:
{
  imports = [
    ../../modules/nixos/common.nix
  ];

  networking.hostName = "phoenix";

  # 開発機なので未使用イメージ・volume も含めて毎週 prune する
  # (volume を消すのは phoenix 限定の判断。共通モジュールには入れない)
  virtualisation.docker.autoPrune = {
    enable = true;
    dates = "weekly";
    flags = [ "--all" "--volumes" ];
  };

  # Hyprland + DMS の試用。ブートメニューで "hyprland" を選んだときだけ GNOME と
  # 入れ替わる (modules/nixos/desktop/hyprland.nix)。通常起動は GNOME のまま。
  specialisation.hyprland.configuration = {
    desktop.environment = "hyprland";
  };
}
