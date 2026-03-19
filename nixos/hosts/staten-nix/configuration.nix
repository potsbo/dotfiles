{ config, pkgs, lib, ... }:
{
  imports = [
    ../../modules/common.nix
    ../../modules/laptop.nix
  ];

  networking.hostName = "staten-nix";
}
