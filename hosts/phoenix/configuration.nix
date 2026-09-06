{ config, pkgs, lib, ... }:
{
  imports = [
    ../../modules/nixos/common.nix
  ];

  # 開発機なので未使用イメージ・volume も含めて毎週 prune する
  # (volume を消すのは phoenix 限定の判断。共通モジュールには入れない)
  virtualisation.docker.autoPrune = {
    enable = true;
    dates = "weekly";
    flags = [ "--all" "--volumes" ];
  };

  # 既定は Hyprland + DMS (modules/nixos/desktop.nix)。GNOME はブートメニューで "gnome" を
  # 選んだときだけの逃げ道。Hyprland 側で困ったときに戻れるように残している。
  specialisation.gnome.configuration = {
    desktop.environment = "gnome";
  };
}
