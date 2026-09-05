{ config, pkgs, lib, ... }:
{
  imports = [
    ../../modules/common.nix
    ../../modules/laptop.nix
  ];

  networking.hostName = "skylake";

  # RDP キオスク PoC。ブートメニューで "kiosk" を選んだときだけ有効になる。
  # 通常起動には影響しない。
  specialisation.kiosk.configuration = {
    imports = [ ../../modules/kiosk.nix ];
  };
}
