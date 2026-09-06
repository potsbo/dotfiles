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
    # DankMaterialShell: Hyprland 上の bar / ランチャー / 通知 / ロック画面。release tag に固定
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/v1.6.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, nix-darwin, xremap-flake, disko, dms, ... }:
    let
      lib = nixpkgs.lib;

      palette = import ./palette.nix;

      # ホスト一覧はここだけ。nixos / darwin / home の各 configuration、
      # `./install` の既知ホスト判定、シェル側の host-color / host-tags
      # (modules/home-manager/hosts.nix) はすべてここから導出する。
      #
      # os:      nixos | darwin。host-tags が表示に使う
      # managed: この dotfiles で system と home を管理するか (既定 true)。false は会社
      #          管理などで ./install の対象外。ssh 先として色とタグだけ持つ
      # alwaysOn: 常時稼働。サスペンドせず、notes の remote-control server を常駐させる
      # laptop:   蓋を閉じたらサスペンドする
      # desktop:  GUI (DE、音、日本語入力、GUI アプリ、xremap) を入れる。既定 true。
      #           false は headless サーバ。GPU ドライバは別 (CUDA 用に残る)
      # (「モニタやキーボードが繋がっているか」は別の性質で、今は参照する設定が無いので持たない)
      hosts = {
        phoenix = { system = "x86_64-linux"; os = "nixos"; color = palette.orange; alwaysOn = true; };
        raptorlake = {
          system = "x86_64-linux"; os = "nixos"; color = palette.white; alwaysOn = true; desktop = false;
          extraModules = [ ./hosts/raptorlake/disk-config.nix disko.nixosModules.disko ];
        };
        skylake = { system = "x86_64-linux"; os = "nixos"; color = palette.blue; laptop = true; };
        avalanche = { system = "aarch64-darwin"; os = "darwin"; color = palette.purple; };
        blizzard = { system = "aarch64-darwin"; os = "darwin"; color = palette.cyan; };
        graniteridge = { system = "x86_64-linux"; os = "nixos"; color = palette.green; managed = false; };
      };
      managedByOs = os: lib.filterAttrs (_: h: h.os == os && (h.managed or true)) hosts;

      # home-manager は standalone ではなく NixOS / nix-darwin のモジュールとして組み込む。
      # system と home が同じ世代で切り替わり、./install は rebuild 一発で済む。
      hmModule = hostname: { config, ... }:
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.potsbo.imports = [
              ./modules/home-manager/home.nix
              ./modules/home-manager/hosts.nix
              ./modules/home-manager/dotfiles.nix
              ./modules/home-manager/mozc.nix
              ./modules/home-manager/starship.nix
              ./modules/home-manager/lazygit.nix
              ./modules/home-manager/notes-sync.nix
              ./modules/home-manager/notes-remote-control.nix
            ];
            extraSpecialArgs = {
              inherit hostname;
              inherit palette;
              accentColor = hosts.${hostname}.color;
              dotfilesPath = "${config.users.users.potsbo.home}/src/github.com/potsbo/dotfiles";
              hosts = lib.mapAttrs (_: h: { inherit (h) os color; alwaysOn = h.alwaysOn or false; }) hosts;
              defaultColor = palette.gray;
            };
          };
        };

      # hardware-configuration.nix は nixos-generate-config の出力をそのまま
      # hosts/<host>/ に commit する。/etc/nixos のものを読むと --impure が要り、
      # eval cache も効かなくなる。
      mkNixos = hostname: { system, extraModules ? [ ], alwaysOn ? false, laptop ? false, desktop ? true, ... }: lib.nixosSystem {
        inherit system;
        modules = [
          { host = { inherit alwaysOn laptop desktop; }; }
          (./hosts + "/${hostname}/hardware-configuration.nix")
          (./hosts + "/${hostname}/configuration.nix")
          xremap-flake.nixosModules.default
          ./modules/nixos/xremap.nix
          dms.nixosModules.dank-material-shell
          home-manager.nixosModules.home-manager
          (hmModule hostname)
        ] ++ extraModules;
      };

      mkDarwin = { hostname, system, apps }: nix-darwin.lib.darwinSystem {
        inherit system;
        modules = [
          ./modules/darwin
          home-manager.darwinModules.home-manager
          (hmModule hostname)
        ] ++ lib.optional apps ./modules/darwin/apps.nix;
      };
    in
    {
      nixosConfigurations = lib.mapAttrs mkNixos (managedByOs "nixos");

      # `<host>` は Homebrew / Mac App Store を含まない軽い構成 (./install)。
      # `<host>-apps` は GUI アプリまで含む重い構成 (`apps` コマンド)。
      darwinConfigurations = lib.concatMapAttrs
        (name: h: {
          ${name} = mkDarwin { hostname = name; inherit (h) system; apps = false; };
          "${name}-apps" = mkDarwin { hostname = name; inherit (h) system; apps = true; };
        })
        (managedByOs "darwin");

      packages.aarch64-darwin.default = nix-darwin.packages.aarch64-darwin.default;

      # nix-update がハッシュを自動更新するための出力。CI (autofix.ci) が
      # `nix-update --flake --version=skip <name>` で参照する。
      packages.x86_64-linux = lib.genAttrs [ "aqua" "tuicast" "todoist-cli" "evalcache" ]
        (name: nixpkgs.legacyPackages.x86_64-linux.callPackage (./pkgs + "/${name}.nix") { });
    };
}
