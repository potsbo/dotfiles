{ config, pkgs, lib, ... }:
{
  imports = [ ../../modules/common.nix ];

  networking.hostName = "blizzard";
}
