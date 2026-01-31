{
  description = "Home Manager configuration for potsbo";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, nix-darwin, ... }:
    let
      colors = {
        gray = "#797979";
        yellow = "#fd971f";
        purple = "#ae81ff";
        white = "#f8f8f2";
        orange = "#d7875f";
      };

      hostColors = {
        tigerlake = colors.yellow;
        raptorlake = colors.white;
        staten = colors.purple;
        phoenix = colors.orange;
        default = colors.gray;
      };

      mkHome = { system, hostname }:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          accentColor = hostColors.${hostname} or hostColors.default;
          homeDir = if pkgs.stdenv.isDarwin then "/Users/potsbo" else "/home/potsbo";
          dotfilesPath = "${homeDir}/src/github.com/potsbo/dotfiles";
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ./home.nix
            ./modules/starship.nix
          ];
          extraSpecialArgs = { inherit accentColor hostname dotfilesPath; };
        };
    in
    {
      homeConfigurations = {
        "tigerlake" = mkHome { system = "x86_64-linux"; hostname = "tigerlake"; };
        "raptorlake" = mkHome { system = "x86_64-linux"; hostname = "raptorlake"; };
        "phoenix" = mkHome { system = "x86_64-linux"; hostname = "phoenix"; };
        "staten" = mkHome { system = "aarch64-darwin"; hostname = "staten"; };
      };

      darwinConfigurations = {
        "darwin" = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          modules = [ ./modules/darwin.nix ];
        };
        "staten" = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          modules = [ ./modules/darwin.nix ];
        };
      };
    };
}
