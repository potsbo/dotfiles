{ config, pkgs, lib, ... }:
{
  imports = [ ../../modules/common.nix ];

  networking.hostName = "phoenix";

  # phoenix 固有: LAN ルート広告
  services.tailscale.extraUpFlags = [ "--advertise-routes=192.168.10.0/24" ];
}
