{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    xremap-flake.url = "github:xremap/nix-flake";
  };

  outputs = { nixpkgs, xremap-flake, ... }: {
    nixosConfigurations.phoenix = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        /etc/nixos/hardware-configuration.nix
        ./configuration.nix
        xremap-flake.nixosModules.default
        ./xremap.nix
      ];
    };
  };
}
