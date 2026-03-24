{ config, pkgs, lib, ... }:
{
  imports = [
    ../../modules/common.nix
    ../../modules/server.nix
  ];

  networking.hostName = "phoenix";

  # Thunderbolt Bridge: 対向 (10.0.0.1) への静的 IP
  networking.networkmanager.ensureProfiles.profiles.thunderbolt0 = {
    connection = {
      id = "thunderbolt0";
      type = "ethernet";
      interface-name = "thunderbolt0";
      autoconnect = "true";
    };
    ipv4 = {
      method = "manual";
      addresses = "10.0.0.2/24";
    };
    ipv6 = {
      method = "link-local";
    };
  };

  # phoenix 固有: LAN ルート広告
  services.tailscale.extraUpFlags = [ "--advertise-routes=192.168.10.0/24" ];
}
