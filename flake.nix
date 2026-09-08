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
    # DankMaterialShell: Hyprland 上の bar / ランチャー / 通知 / ロック画面。release tag に固定。
    # Renovate の nix manager は lock の rev しか見ず URL 中の tag は進めないので、
    # renovate.json の regex で tag を進め、flake.lock は autofix.ci が relock する。
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/v1.6.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # herdr: aqua ではなく upstream flake から source build する。1 台に 1 版しか居られないので
    # lazy install の利点が無く、rebuild で入れて同じ activation で稼働中サーバを載せ替える
    # (modules/home-manager/home.nix)。tag 固定と Renovate/relock の扱いは dms と同じ。
    # upstream は binary cache を出していないので release ごとに各ホストで build する (raptorlake で 1m43s)。
    herdr = {
      url = "github:herdrdev/herdr/v0.9.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, nix-darwin, xremap-flake, disko, dms, herdr, ... }:
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
        # builder を持つホストは他ホストの nix build を引き受ける (modules/remote-build.nix)。
        # 常時稼働の x86_64-linux 機だけ。sshHostKey は client 側 root の known_hosts 用で、
        # 入れ直して host key が変わったら ssh-keyscan -t ed25519 <host> で取り直す。
        # raptorlake を全ホストから最優先にする。phoenix も client として raptorlake に出す。
        # 以前は LAN の phoenix (往復 5ms) を優先していた。store path の転送が支配的で、外に
        # ある raptorlake (往復 26ms) より速く終わるため。しかし phoenix の upload 回線が
        # 細く、phoenix でローカル build した出力を raptorlake に送る状況が一番遅い。ほぼ
        # 全部を raptorlake で build すれば、入力は raptorlake が cache から直接取るか
        # 自分の store に既にあるかで、phoenix から上がるのは .drv とローカルソースだけになる。
        # builder 同士は store を共有しないので、分散させず 1 台に寄せるのも同じ理由。
        # phoenix は raptorlake が満杯か到達不能なときの fallback として builder に残す。
        #
        # nix は空きのある builder を load / speedFactor (整数除算) の小さい順、同点なら
        # speedFactor の大きい順に選ぶ。raptorlake の speedFactor を maxJobs 以上にしておくと
        # 枠が埋まるまで常に 0 で勝ち、phoenix はそのときだけ使われる。
        # speedFactor は委譲の向きも決める (自分より大きい builder にだけ出す)。
        phoenix = {
          system = "x86_64-linux"; os = "nixos"; color = palette.orange; manage = "system"; role = "workstation";
          extraModules = [ ];
          builder = { maxJobs = 16; speedFactor = 16; };
          sshHostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOTgQinkEH54/i8XT8+2+rajQUEqvx84dSzMd/aZzS6l";
        };
        raptorlake = {
          system = "x86_64-linux"; os = "nixos"; color = palette.white; manage = "system"; role = "server";
          extraModules = [ ./hosts/raptorlake/disk-config.nix disko.nixosModules.disko ];
          builder = { maxJobs = 20; speedFactor = 20; };
          sshHostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILr0XeysKahURB4x3NQ1KjGsq6pcoUwNNQuDg4uaF91N";
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
        ./modules/home-manager/mozc.nix
        ./modules/home-manager/starship.nix
        ./modules/home-manager/lazygit.nix
        ./modules/home-manager/notes-sync.nix
      ];
      # home 配下のパスは渡さない。各モジュールが config.home.homeDirectory から組む。
      hmSpecialArgs = hostname: {
        inherit hostname palette hosts herdr;
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
          ./modules/remote-build.nix
          xremap-flake.nixosModules.default
          ./modules/nixos/xremap.nix
          dms.nixosModules.dank-material-shell
          home-manager.nixosModules.home-manager
          (hmModule hostname)
        ] ++ extraModules;
      };

      mkDarwin = { hostname, system, apps }: nix-darwin.lib.darwinSystem {
        inherit system;
        specialArgs = { inherit user hosts hostname; };
        modules = [
          { networking.hostName = hostname; }
          ./modules/darwin
          ./modules/remote-build.nix
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

      packages = {
        aarch64-darwin.default = nix-darwin.packages.aarch64-darwin.default;

        # nix-update がハッシュを自動更新するための出力。CI (autofix.ci) が
        # `nix-update --flake --version=skip <name>` で参照する。
        x86_64-linux = lib.genAttrs [ "aqua" "tuicast" "evalcache" ]
          (name: nixpkgs.legacyPackages.x86_64-linux.callPackage ./pkgs/${name}.nix { });
      };
    };
}
