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
        green = "#a6e22e";
      };

      hostColors = {
        tigerlake = colors.yellow;
        raptorlake = colors.white;
        avalanche = colors.purple;
        phoenix = colors.orange;
        "staten-nix" = colors.red;
        blizzard = colors.cyan;
        skylake = colors.blue;
        graniteridge = colors.green;
        default = colors.gray;
      };

      mkHome = { system, hostname }:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          accentColor = hostColors.${hostname} or hostColors.default;
          homeDir = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/potsbo" else "/home/potsbo";
          dotfilesPath = "${homeDir}/src/github.com/potsbo/dotfiles";
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ./home.nix
            ./modules/starship.nix
            ./modules/notes-sync.nix
            ./modules/notes-remote-control.nix
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

      # `<host>` は Homebrew / Mac App Store を含まない軽い構成 (./install)。
      # `<host>-apps` は GUI アプリまで含む重い構成 (./install-apps)。
      darwinConfigurations =
        let
          hosts = [ "darwin" "avalanche" "blizzard" ];
          mkDarwin = { apps }: nix-darwin.lib.darwinSystem {
            system = "aarch64-darwin";
            modules = [ ./modules/darwin.nix ]
              ++ nixpkgs.lib.optional apps ./modules/darwin-apps.nix;
          };
        in
        nixpkgs.lib.listToAttrs (nixpkgs.lib.concatMap
          (host: [
            { name = host; value = mkDarwin { apps = false; }; }
            { name = "${host}-apps"; value = mkDarwin { apps = true; }; }
          ])
          hosts);

      packages.aarch64-darwin.default = nix-darwin.packages.aarch64-darwin.default;

      # nix-update がハッシュを自動更新するための出力。CI (autofix.ci) が
      # `nix-update --flake --version=skip <name>` で参照する。
      packages.x86_64-linux = nixpkgs.lib.genAttrs [ "aqua" "tuicast" "todoist-cli" "evalcache" ]
        (name: nixpkgs.legacyPackages.x86_64-linux.callPackage (./pkgs + "/${name}.nix") { });
    };
}
