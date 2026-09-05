{ config, pkgs, lib, ... }:
{
  imports = [
    ../../modules/nixos/common.nix
    ../../modules/nixos/laptop.nix
  ];

  networking.hostName = "staten-nix";
}
