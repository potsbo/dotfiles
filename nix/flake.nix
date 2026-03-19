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
        red = "#f92672";
        cyan = "#55bed2";
        blue = "#6796e6";
      };

      hostColors = {
        tigerlake = colors.yellow;
        raptorlake = colors.white;
        avalanche = colors.purple;
        phoenix = colors.orange;
        "staten-nix" = colors.red;
        blizzard = colors.cyan;
        skylake = colors.blue;
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
        "linux" = mkHome { system = "x86_64-linux"; hostname = "default"; };
        "tigerlake" = mkHome { system = "x86_64-linux"; hostname = "tigerlake"; };
        "raptorlake" = mkHome { system = "x86_64-linux"; hostname = "raptorlake"; };
        "phoenix" = mkHome { system = "x86_64-linux"; hostname = "phoenix"; };
        "skylake" = mkHome { system = "x86_64-linux"; hostname = "skylake"; };
        "staten-nix" = mkHome { system = "aarch64-linux"; hostname = "staten-nix"; };
        "avalanche" = mkHome { system = "aarch64-darwin"; hostname = "avalanche"; };
        "blizzard" = mkHome { system = "aarch64-darwin"; hostname = "blizzard"; };
      };

      darwinConfigurations = {
        "darwin" = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          modules = [ ./modules/darwin.nix ];
        };
        "avalanche" = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          modules = [ ./modules/darwin.nix ];
        };
        "blizzard" = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          modules = [ ./modules/darwin.nix ];
        };
      };

      packages.aarch64-darwin.default = nix-darwin.packages.aarch64-darwin.default;
    };
}
