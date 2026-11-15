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
    # 独自のパッケージ定義を持たず公式 flake を使い、既存の snapshot 利用を維持する。
    rex = {
      url = "https://pkgs.superlogical.com/rex/nix/snapshot.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # DankMaterialShell: Hyprland 上の bar / ランチャー / 通知 / ロック画面。release tag に固定。
    # Renovate の nix manager は lock の rev しか見ず URL 中の tag は進めないので、
    # renovate.json は github:owner/repo/[v]X.Y.Z の URL を共通の regex で拾う。
    # autofix.ci の nix flake lock が宣言の変更に追従するので、input 名の列挙は不要。
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/v1.6.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, nix-darwin, xremap-flake, disko, dms, rex, ... }:
    let
      inherit (nixpkgs) lib;

      palette = import ./lib/palette.nix;

      # ホスト一覧はここだけ。nixos / darwin / home の各 configuration、
      # シェル側の host-color / host-tags (modules/home-manager/hosts.nix) は
      # すべてここから導出する。
      #
      # 既定値は持たず、各ホストで全キーを書き下す。省略可能にすると既定値の埋めが
      # 参照側 (mkNixos の引数、hostsWith) に散って読めなくなる。
      #
      # os:      nixos | darwin。host-tags が表示に使う
      # manage:  この dotfiles がそのホストで何を管理するか。
      #          system: OS (NixOS / nix-darwin) ごと。home-manager はそのモジュールとして当たる
      #          home:   home-manager だけ (standalone)。会社管理などで OS 側を触れないホスト
      #          どちらも管理しない (ssh 先として色とタグだけ持つ) ホストは今は無い
      # 以下は manage = system な nixos ホストだけが持つ:
      # role:    laptop (蓋で寝る、GUI) | workstation (常時稼働、GUI) | server (常時稼働、headless)。
      #          意味は modules/nixos/common.nix の options.host。物理形状ではなく扱い
      #          (raptorlake は据え置きで使うので server)
      # extraModules: そのホストだけの NixOS モジュール
      # (「モニタやキーボードが繋がっているか」は別の性質で、今は参照する設定が無いので持たない)
      hosts = {
        phoenix = {
          system = "x86_64-linux"; os = "nixos"; color = palette.orange; manage = "system"; role = "workstation";
          extraModules = [ ];
        };
        raptorlake = {
          system = "x86_64-linux"; os = "nixos"; color = palette.white; manage = "system"; role = "server";
          extraModules = [ ./hosts/raptorlake/disk-config.nix disko.nixosModules.disko ];
        };
        skylake = { system = "x86_64-linux"; os = "nixos"; color = palette.blue; manage = "system"; role = "laptop"; extraModules = [ ]; };
        avalanche = { system = "aarch64-darwin"; os = "darwin"; color = palette.purple; manage = "system"; };
        blizzard = { system = "aarch64-darwin"; os = "darwin"; color = palette.cyan; manage = "system"; };
        # green だと starship の branch セグメントと同色で境界が消える。black は端末背景に
        # 沈んで見えなかったので、少し明るい surface に白文字。
        graniteridge = { system = "x86_64-linux"; os = "nixos"; color = palette.surface; fg = palette.white; manage = "home"; };
      };
      hostsWith = manage: os: lib.filterAttrs (_: h: h.os == os && h.manage == manage) hosts;

      # ユーザー名はここだけ。
      # homeDirectory は書かない。manage = system では NixOS / nix-darwin の
      # users.users.${user} から home-manager が引き、standalone は mkHome が組む。
      user = "potsbo";

      hmModules = [
        { home.username = user; }
        ./modules/home-manager/home.nix
        ./modules/home-manager/hosts.nix
        ./modules/home-manager/dotfiles.nix
        ./modules/home-manager/aqua.nix
        ./modules/home-manager/mozc.nix
        ./modules/home-manager/starship.nix
        ./modules/home-manager/lazygit.nix
        ./modules/home-manager/notes-sync.nix
        ./modules/home-manager/rex.nix
      ];
      # home 配下のパスは渡さない。各モジュールが config.home.homeDirectory から組む。
      hmSpecialArgs = hostname: {
        inherit hostname palette hosts rex;
        accentColor = hosts.${hostname}.color;
        # accent の上に乗せる文字色。accent が暗いホストだけ fg で白を指定する。
        accentFgColor = hosts.${hostname}.fg or palette.black;
        defaultColor = palette.gray;
      };

      # manage = system では home-manager を NixOS / nix-darwin のモジュールとして組み込む。
      # system と home が同じ世代で切り替わり、`rebuild` は switch 一発で済む。
      hmModule = hostname: {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          users.${user}.imports = hmModules;
          extraSpecialArgs = hmSpecialArgs hostname;
        };
      };

      # manage = home では standalone。OS 側の設定が無いので、モジュール経由なら
      # そちらから来る homeDirectory と allowUnfree (modules/nixos/common.nix) をここで与える。
      # homeDirectory は Linux の慣習で決め打つ。standalone は Linux でしか使わない
      # (macOS は必ず nix-darwin ごと管理する) ので、OS で分ける必要が無い。
      mkHome = hostname: { system, ... }: home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
        modules = hmModules ++ [
          ({ config, ... }: { home.homeDirectory = "/home/${config.home.username}"; })
        ];
        extraSpecialArgs = hmSpecialArgs hostname;
      };

      # hardware-configuration.nix は nixos-generate-config の出力をそのまま
      # hosts/<host>/ に commit する。/etc/nixos のものを読むと --impure が要り、
      # eval cache も効かなくなる。
      mkNixos = hostname: { system, extraModules, role, ... }: lib.nixosSystem {
        inherit system;
        specialArgs = { inherit user hosts hostname; };
        modules = [
          {
            host = { inherit role; };
            networking.hostName = hostname;
          }
          ./hosts/${hostname}/hardware-configuration.nix
          ./hosts/${hostname}/configuration.nix
          ./modules/nix-daemon.nix
          ./modules/certificate-trust.nix
          xremap-flake.nixosModules.default
          ./modules/nixos/xremap.nix
          dms.nixosModules.dank-material-shell
          home-manager.nixosModules.home-manager
          (hmModule hostname)
        ] ++ extraModules;
      };

      # pkgs/ の出力 (packages / devShells) を出す system。aarch64-darwin は、`task cascp:cargo` が
      # 手元の Mac でも `.#cascp` を build するため。
      pkgSystems = [ "x86_64-linux" "aarch64-darwin" ];

      mkDarwin = { hostname, system, apps }: nix-darwin.lib.darwinSystem {
        inherit system;
        specialArgs = { inherit user hosts hostname; };
        modules = [
          { networking.hostName = hostname; }
          ./modules/darwin
          ./modules/certificate-trust.nix
          ./modules/nix-daemon.nix
          home-manager.darwinModules.home-manager
          (hmModule hostname)
        ] ++ lib.optional apps ./modules/darwin/apps.nix;
      };
    in
    {
      nixosConfigurations = lib.mapAttrs mkNixos (hostsWith "system" "nixos");

      # `<host>` は Homebrew / Mac App Store を含まない軽い構成 (`rebuild` コマンド)。
      # `<host>-apps` は GUI アプリまで含む重い構成 (`apps` コマンド)。
      darwinConfigurations = lib.concatMapAttrs
        (name: h: {
          ${name} = mkDarwin { hostname = name; inherit (h) system; apps = false; };
          "${name}-apps" = mkDarwin { hostname = name; inherit (h) system; apps = true; };
        })
        (hostsWith "system" "darwin");

      homeConfigurations = lib.mapAttrs mkHome (hostsWith "home" "nixos");

      # pkgs/ の出力。CI (autofix.ci) が `nix-update --flake --version=skip <name>` で
      # ハッシュを自動更新するために x86_64-linux の attrNames を読む。
      #
      # 名前は書き下さず pkgs/ を読んで作る。ここ・home.nix・autofix.yaml の 3 箇所に
      # 同じ一覧を書いていて、実際 nix-graph を足したとき autofix.yaml を落とした。
      # パッケージの追加は pkgs/ にファイルを置いて使う場所から参照するだけで済む。
      packages = lib.recursiveUpdate
        (lib.genAttrs pkgSystems (system: lib.packagesFromDirectoryRecursive {
          inherit (nixpkgs.legacyPackages.${system}) callPackage;
          directory = ./pkgs;
        }))
        {
          aarch64-darwin.default = nix-darwin.packages.aarch64-darwin.default;
        };

      # pkgs/<name>/shell.nix を devShells.<name> として出す。中身は各ディレクトリに閉じ、ここには
      # 個別の名前を書かない (packages と同じく、足すときにここを触らずに済むように)。
      # packagesFromDirectoryRecursive は package.nix のあるディレクトリでは他のファイルを
      # 見ないので、shell.nix が packages に混ざることはない。
      devShells = lib.genAttrs pkgSystems (system:
        lib.mapAttrs (name: _: nixpkgs.legacyPackages.${system}.callPackage ./pkgs/${name}/shell.nix { })
          (lib.filterAttrs (name: _: builtins.pathExists ./pkgs/${name}/shell.nix) (builtins.readDir ./pkgs)));
    };
}
