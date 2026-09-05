{
  description = "potsbo's dotfiles: NixOS hosts, nix-darwin, home-manager";

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
    xremap-flake.url = "github:xremap/nix-flake";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, nix-darwin, xremap-flake, disko, ... }:
    let
      lib = nixpkgs.lib;

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

      # ホスト一覧はここだけ。nixos / darwin / home の各 configuration、
      # `./install` の既知ホスト判定、シェル側の host-color / host-tags
      # (modules/home-manager/hosts.nix) はすべてここから導出する。
      #
      # os:
      #   nixos  - nixosConfigurations を持ち、./install が nixos-rebuild する
      #   darwin - darwinConfigurations を持ち、./install が nix-darwin を switch する
      #   linux  - 管理外の Linux。./install の対象外で、ssh 先として色とタグだけ持つ
      hosts = {
        phoenix = { system = "x86_64-linux"; os = "nixos"; color = colors.orange; };
        raptorlake = {
          system = "x86_64-linux"; os = "nixos"; color = colors.white;
          extraModules = [ ./hosts/raptorlake/disk-config.nix disko.nixosModules.disko ];
        };
        skylake = { system = "x86_64-linux"; os = "nixos"; color = colors.blue; };
        avalanche = { system = "aarch64-darwin"; os = "darwin"; color = colors.purple; };
        blizzard = { system = "aarch64-darwin"; os = "darwin"; color = colors.cyan; };
        graniteridge = { system = "x86_64-linux"; os = "linux"; color = colors.green; };
      };
      hostsByOs = os: lib.filterAttrs (_: h: h.os == os) hosts;

      # home-manager は standalone ではなく NixOS / nix-darwin のモジュールとして組み込む。
      # system と home が同じ世代で切り替わり、./install は rebuild 一発で済む。
      hmModule = hostname: isDarwin:
        let
          homeDir = if isDarwin then "/Users/potsbo" else "/home/potsbo";
        in
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.potsbo.imports = [
              ./modules/home-manager/home.nix
              ./modules/home-manager/hosts.nix
              ./modules/home-manager/dotfiles.nix
              ./modules/home-manager/starship.nix
              ./modules/home-manager/notes-sync.nix
              ./modules/home-manager/notes-remote-control.nix
            ];
            extraSpecialArgs = {
              inherit hostname;
              accentColor = hosts.${hostname}.color;
              dotfilesPath = "${homeDir}/src/github.com/potsbo/dotfiles";
              hosts = lib.mapAttrs (_: h: { inherit (h) os color; }) hosts;
              defaultColor = colors.gray;
            };
          };
        };

      # hardware-configuration.nix は nixos-generate-config の出力をそのまま
      # hosts/<host>/ に commit する。/etc/nixos のものを読むと --impure が要り、
      # eval cache も効かなくなる。
      mkNixos = hostname: { system, extraModules ? [ ], ... }: lib.nixosSystem {
        inherit system;
        modules = [
          (./hosts + "/${hostname}/hardware-configuration.nix")
          (./hosts + "/${hostname}/configuration.nix")
          xremap-flake.nixosModules.default
          ./modules/nixos/xremap.nix
          home-manager.nixosModules.home-manager
          (hmModule hostname false)
        ] ++ extraModules;
      };

      mkDarwin = { hostname, system, apps }: nix-darwin.lib.darwinSystem {
        inherit system;
        modules = [
          ./modules/darwin
          home-manager.darwinModules.home-manager
          (hmModule hostname true)
        ] ++ lib.optional apps ./modules/darwin/apps.nix;
      };
    in
    {
      nixosConfigurations = lib.mapAttrs mkNixos (hostsByOs "nixos");

      # `<host>` は Homebrew / Mac App Store を含まない軽い構成 (./install)。
      # `<host>-apps` は GUI アプリまで含む重い構成 (`apps` コマンド)。
      darwinConfigurations = lib.concatMapAttrs
        (name: h: {
          ${name} = mkDarwin { hostname = name; inherit (h) system; apps = false; };
          "${name}-apps" = mkDarwin { hostname = name; inherit (h) system; apps = true; };
        })
        (hostsByOs "darwin");

      packages.aarch64-darwin.default = nix-darwin.packages.aarch64-darwin.default;

      # nix-update がハッシュを自動更新するための出力。CI (autofix.ci) が
      # `nix-update --flake --version=skip <name>` で参照する。
      packages.x86_64-linux = lib.genAttrs [ "aqua" "tuicast" "todoist-cli" "evalcache" ]
        (name: nixpkgs.legacyPackages.x86_64-linux.callPackage (./pkgs + "/${name}.nix") { });
    };
}
