{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    xremap-flake.url = "github:xremap/nix-flake";
    nixos-apple-silicon.url = "github:tpwrules/nixos-apple-silicon";
  };

  outputs = { nixpkgs, xremap-flake, nixos-apple-silicon, ... }: {
    nixosConfigurations.staten-nix = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        nixos-apple-silicon.nixosModules.apple-silicon-support
        /etc/nixos/hardware-configuration.nix
        ./configuration.nix
        xremap-flake.nixosModules.default
        ../../modules/xremap.nix
      ];
    };
  };
}
