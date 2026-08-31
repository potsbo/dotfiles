{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    xremap-flake.url = "github:xremap/nix-flake";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, xremap-flake, disko, ... }: {
    nixosConfigurations.raptorlake = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hardware-configuration.nix
        ./disk-config.nix
        ./configuration.nix
        disko.nixosModules.disko
        xremap-flake.nixosModules.default
        ../../modules/xremap.nix
      ];
    };
  };
}
