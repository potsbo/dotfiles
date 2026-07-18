{ config, pkgs, lib, ... }:

let
  registryPort = 5000;
  hostname = config.networking.hostName;
  isX86 = pkgs.stdenv.hostPlatform.isx86_64;

  # google-chrome は aarch64 非対応のため、アーキテクチャで切り替え
  browser = if isX86 then {
    package = pkgs.google-chrome;
    binary = "${pkgs.google-chrome}/bin/google-chrome-stable";
    icon = "google-chrome";
  } else {
    package = pkgs.chromium;
    binary = "${pkgs.chromium}/bin/chromium";
    icon = "chromium-browser";
  };

  # Mozc カスタムローマ字テーブル (potsbo/anpan)
  anpanRelease = pkgs.fetchzip {
    url = "https://github.com/potsbo/anpan/releases/download/0.1.0/tables-0.1.0.zip";
    sha256 = "sha256-oyfVfoJppTUs0DFgwLStEykjePNnoIsYNng+qLYLJ8Q=";
    stripRoot = true;
  };
  mozcConfigProto = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/google/mozc/2.30.5544.102/src/protocol/config.proto";
    sha256 = "0d6jms4hwhagfdskmgyyijpdbix6rhaxxiq4277zcnflpiv783yg";
  };
  # xremap がフォーカス中のアプリを検出するための GNOME Shell 拡張機能
  # アプリごとに Emacs Ctrl バインドの適用/除外を切り替えるために必要
  xremap-gnome-extension = pkgs.stdenvNoCC.mkDerivation {
    pname = "gnome-shell-extension-xremap";
    version = "13";
    src = pkgs.fetchFromGitHub {
      owner = "xremap";
      repo = "xremap-gnome";
      rev = "9434933b430d466f8ea01a32cf5781e9b2cb75af";
      hash = "sha256-gA7UlCoYB+avYi3BNXJ8P0cyDCDTpmqDRyY/iwQWbns=";
    };
    installPhase = ''
      mkdir -p $out/share/gnome-shell/extensions/xremap@k0kubun.com
      cp extension.js metadata.json $out/share/gnome-shell/extensions/xremap@k0kubun.com/
    '';
  };

  mozcConfigDb = pkgs.runCommand "mozc-config1-db" {
    nativeBuildInputs = [ pkgs.protobuf pkgs.python3 ];
  } ''
    python3 ${./mozc-romantable-to-config.py} ${anpanRelease}/anpan.txt config.textproto
    protoc --proto_path=$(dirname ${mozcConfigProto}) \
      --encode=mozc.config.Config $(basename ${mozcConfigProto}) \
      < config.textproto > $out
  '';

  # Web アプリを Chrome/Chromium --app モードで起動する .desktop エントリを生成
  webApp = { name, desktopName, url, icon ? browser.icon }:
    pkgs.makeDesktopItem {
      inherit name desktopName icon;
      exec = "${browser.binary} --app=${url}";
      categories = [ "Network" ];
    };
in
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nixpkgs.config.allowUnfree = true;

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Tokyo";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "en_CA.UTF-8/UTF-8"
    "ja_JP.UTF-8/UTF-8"
    "C.UTF-8/UTF-8"
  ];

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        fcitx5-mozc
        fcitx5-gtk
      ];
    };
  };

  # Mozc に anpan ローマ字テーブルを適用
  system.activationScripts.mozcAnpanTable = {
    text = ''
      install -d -o potsbo -g users /home/potsbo/.config/mozc
      install -o potsbo -g users -m 644 ${mozcConfigDb} /home/potsbo/.config/mozc/config1.db
    '';
  };

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = isX86;
    pulse.enable = true;
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  # Enable the X11/Wayland display server and GNOME desktop environment.
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # GNOME Shell 拡張機能の有効化 & tiling-assistant 設定
  programs.dconf = {
    enable = true;
    profiles.user.databases = [{
      settings = {
        "org/gnome/shell" = {
          disable-user-extensions = false;
          enabled-extensions = [
            "xremap@k0kubun.com"
            "tiling-assistant@leleat-on-github"
            "appindicatorsupport@rgcjonas.gmail.com"
            "vicinae@dagimg-dot"
          ];
        };
        "org/gnome/shell/extensions/tiling-assistant" = {
          # スナップ時に反対側のウィンドウ候補を表示しない
          enable-tiling-popup = false;
          # Magnet 風四分割: Ctrl+Option+U/I/J/K → xremap が Super+U/I/J/K に変換
          tile-topleft-quarter = [ "<Super>u" ];
          tile-topright-quarter = [ "<Super>i" ];
          tile-bottomleft-quarter = [ "<Super>j" ];
          tile-bottomright-quarter = [ "<Super>k" ];
        };
        # xremap が Ctrl+Alt+Arrow を横取りするので、GNOME デフォルトのワークスペース
        # 切り替えショートカットを無効化 (Ctrl+Alt+Up/Down/Left/Right の衝突を防ぐ)
        "org/gnome/desktop/wm/keybindings" = let
          noBinding = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        in {
          switch-to-workspace-up = noBinding;
          switch-to-workspace-down = noBinding;
          switch-to-workspace-left = noBinding;
          switch-to-workspace-right = noBinding;
        };
        "org/gnome/desktop/peripherals/touchpad" = {
          speed = 0.5;
        };
        "org/gnome/desktop/interface" = {
          font-name = "Noto Sans CJK JP 11";
          document-font-name = "Noto Sans CJK JP 12";
          monospace-font-name = "JetBrains Mono 11";
          font-antialiasing = "grayscale";
          font-hinting = "none";
          show-battery-percentage = true;
        };
        "org/gnome/desktop/wm/preferences" = {
          titlebar-font = "Noto Sans CJK JP Bold 11";
        };
      };
    }];
  };

  # GTK Emacs keybindings (Ctrl+A/E/K/D/H etc.) — like macOS Cocoa
  environment.sessionVariables = {
    GTK_KEY_THEME = "Emacs";
    # fcitx5 input method
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
    # Default to OCI buildx builder
    BUILDX_BUILDER = "oci-builder";
  };

  users.users.potsbo = {
    uid = 1000;
    isNormalUser = true;
    description = "Shimpei Otsubo";
    extraGroups = [ "networkmanager" "wheel" "docker" "onepassword-cli" ];
    shell = pkgs.zsh;
    packages = with pkgs; [];
  };
  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      insecure-registries = [ "${hostname}:${toString registryPort}" ];
      features.containerd-snapshotter = true;
    };
  };

  # BuildKit config for OCI buildx builder (zstd compression + insecure registry)
  environment.etc."buildkitd/oci-builder.toml".text = ''
    [worker.oci]
      gc = true
      compression = "zstd"
      force-compression = true

    [registry."${hostname}:${toString registryPort}"]
      http = true
      insecure = true
  '';

  # Buildx builder with docker-container driver for OCI output
  systemd.services.docker-buildx-oci = {
    description = "Setup Docker Buildx OCI builder";
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ config.virtualisation.docker.package ];
    environment.HOME = "/home/potsbo";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "potsbo";
      SupplementaryGroups = [ "docker" ];
    };
    script = ''
      docker buildx rm oci-builder 2>/dev/null || true
      docker buildx create \
        --name oci-builder \
        --driver docker-container \
        --config /etc/buildkitd/oci-builder.toml \
        --bootstrap
    '';
  };

  fonts.packages = with pkgs; [
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    jetbrains-mono
    biz-ud-gothic
    nerd-fonts.symbols-only
  ];

  fonts.fontconfig = {
    defaultFonts = {
      sansSerif = [ "Noto Sans CJK JP" ];
      serif = [ "Noto Serif CJK JP" ];
      monospace = [ "JetBrains Mono" "Noto Sans Mono CJK JP" ];
    };
    # macOS 風レンダリング: ヒンティング無効、ビットマップフォント無効
    hinting.enable = false;
    subpixel.rgba = "none";
  };

  programs.zsh.enable = true;
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    readline
    krb5.lib
  ];
  programs.mosh.enable = true;
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "potsbo" ];
  };

  environment.systemPackages = with pkgs; [
    git
    browser.package

    xremap-gnome-extension
    gnomeExtensions.tiling-assistant
    gnomeExtensions.appindicator
    vscode
    vicinae
    gnomeExtensions.vicinae
    (webApp { name = "notion"; desktopName = "Notion"; url = "https://www.notion.so"; })
    zotero
    freerdp
  ] ++ lib.optionals isX86 (with pkgs; [
    slack
    zoom-us
    code-cursor
    pgadmin4-desktopmode
  ]);

  environment.etc."ssh/gh-authorized-keys".text = ''
    #!/bin/sh
    exec ${pkgs.curl}/bin/curl -fsSL "https://github.com/$1.keys"
  '';
  environment.etc."ssh/gh-authorized-keys".mode = "0555";
  environment.etc."ssh/gh-authorized-keys".user = "root";
  environment.etc."ssh/gh-authorized-keys".group = "root";

  services.openssh = {
    enable = true;
    settings = {
      PubkeyAuthentication = true;
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      StreamLocalBindUnlink = true;

      AuthorizedKeysCommand = "/etc/ssh/gh-authorized-keys %u";
      AuthorizedKeysCommandUser = "nobody";

      # Mosh アプリ等 etm 非対応の SSH クライアント向けに etm なしの MAC も許可
      Macs = [
        "hmac-sha2-512-etm@openssh.com"
        "hmac-sha2-256-etm@openssh.com"
        "umac-128-etm@openssh.com"
        "hmac-sha2-512"
        "hmac-sha2-256"
      ];
    };
  };
  services.resolved = {
    enable = true;
    settings.Resolve.LLMNR = "true";
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    extraUpFlags = [];
  };

  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # Docker Registry（Tailscale 経由のみアクセス可）
  # tailscale0 が trustedInterfaces にあり、port が allowedTCPPorts にないことで制限される
  services.dockerRegistry = {
    enable = true;
    listenAddress = "0.0.0.0";
    port = registryPort;
  };

  assertions = [
    {
      assertion = builtins.elem "tailscale0" config.networking.firewall.trustedInterfaces;
      message = "Docker Registry は tailscale0 が trustedInterfaces にある前提で Tailscale 限定にしている";
    }
    {
      assertion = !(builtins.elem registryPort config.networking.firewall.allowedTCPPorts);
      message = "Docker Registry の port 5000 を allowedTCPPorts に追加すると全インターフェースに公開されてしまう";
    }
  ];

  # ============================================================
  # メモリ枯渇耐性 (最小構成)
  #
  # 方針: 重いジョブ (Python データ分析等) が RAM+swap を食い尽くしても、
  #   kernel / sshd / tailscaled には必ずメモリを残し、
  #   「ssh で入って暴走プロセスを kill する」余力を確保する。
  # 過去事例: ユーザランドの Python ジョブがメモリを食い尽くし、
  #   新規接続を捌くメモリすら確保できず全応答停止 → 物理再起動が必要に。
  #
  # 注意: ここでは swap 構成やユーザジョブの上限には手を入れない。
  #   暴走時はディスクスワップ thrash で「重く」はなるが、救命線のメモリ予約で
  #   ssh 経由の救出はできる状態を保つ、という割り切り。
  #   「重さ」自体も消したい場合は別途 zram 化 / user.slice 上限を検討する。
  # ============================================================

  # --- カーネルの予約 ---
  # min_free_kbytes: カーネルが常に確保しておく空きページ。ネットワーク受信など
  #   割り込み内の atomic 確保に使われ、逼迫時も tailscale/ssh のパケットを捌ける。
  # admin_reserve_kbytes: OOM 寸前でも root が復旧コマンド (ps/kill) を実行できる予約。
  boot.kernel.sysctl = {
    "vm.min_free_kbytes" = 262144;      # 256MiB
    "vm.admin_reserve_kbytes" = 262144; # 256MiB
  };

  # --- 救命線へのメモリ予約 ---
  # system.slice 全体 + sshd/tailscaled 個別に memory.min を与え、逼迫時も
  # カーネルがこれらのページを回収 (swap-out/破棄) しないようにしている。
  #
  # 注意: sshd に systemd の OOMScoreAdjust を設定してはいけない。
  #   oom_score_adj は fork で継承されるため、SSH セッション配下の全プロセス
  #   (shell → claude → python ジョブ...) にまで -900 が伝播し、
  #   暴走したユーザジョブが OOM killer から保護されてしまう。
  #   2026-07-10 の障害はこれが原因: python ジョブ 82 個 (RSS 27GB + swap 全食い)
  #   が -900 で殺せず、代わりに NetworkManager が OOM kill →
  #   restart も OOM kill × 5 で start-limit 到達 → NM 永久停止 →
  #   リンクフラップでルート消失 → 沈黙、物理再起動が必要になった。
  #   sshd 自身は Linux では自力で listener を -1000 にし、セッションには
  #   起動時の値 (=0) を復元するので、systemd 側では何も設定しないのが正解。
  systemd.slices."system".sliceConfig.MemoryMin = "512M";
  systemd.services.sshd.serviceConfig.MemoryMin = "32M";
  systemd.services."sshd@".serviceConfig.MemoryMin = "32M";
  systemd.services.tailscaled.serviceConfig = {
    OOMScoreAdjust = -900;
    MemoryMin = "128M";
  };

  # --- NetworkManager: OOM 保護 + 無限リトライ ---
  # NM は new connection を捌く sshd/tailscaled と同格の救命線。
  # NM が死んで DHCP 更新・リンクフラップ後のルート再設定が行われないと、
  # sshd/tailscaled が生きていても外から到達不能になる。
  systemd.services.NetworkManager = {
    # デフォルトの StartLimitBurst=5/10s は OOM 嵐の中で一瞬で使い切り
    # 「Start request repeated too quickly」で永久停止する。無限にリトライさせる。
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig = {
      Restart = lib.mkForce "always";
      RestartSec = "5s";
      OOMScoreAdjust = -900; # NM はユーザプロセスを spawn しないので継承問題なし
      MemoryMin = "32M";
    };
  };
  # NM の再起動には dbus が必要なので dbus も保護
  systemd.services.dbus.serviceConfig.OOMScoreAdjust = -900;

  # --- earlyoom: カーネル OOM killer 発動前にプロアクティブに kill (バックストップ) ---
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 5;
    extraArgs = [
      "--avoid" "^(sshd|tailscaled|systemd|NetworkManager|dbus)"
      # 過去の障害は毎回 python のデータジョブがメモリを食い尽くしている。
      # 逼迫時はまず python を殺す (ジョブは失敗するがマシンは守る)。
      "--prefer" "^python3"
    ];
  };

  # --- ネットワーク自己修復 watchdog ---
  # デフォルトルートが消えたら NetworkManager を叩き直し、
  # それでも 30 分回復しなければ最終手段として再起動する。
  # (再起動すれば必ず到達可能な状態に戻る = 物理アクセス不要の保険)
  # ISP 障害ではデフォルトルート自体は残るので、誤発動で再起動ループにはならない。
  systemd.services.network-watchdog = {
    description = "Restart NetworkManager (and eventually reboot) if default route is lost";
    serviceConfig.Type = "oneshot";
    path = [ pkgs.iproute2 ];
    script = ''
      state=/run/network-watchdog-down-since
      if ip route show default | grep -q .; then
        rm -f "$state"
        exit 0
      fi
      now=$(date +%s)
      if [ ! -f "$state" ]; then
        echo "$now" > "$state"
      fi
      echo "no default route; kicking NetworkManager"
      systemctl reset-failed NetworkManager.service 2>/dev/null || true
      systemctl restart NetworkManager.service || true
      first=$(cat "$state")
      if [ "$((now - first))" -gt 1800 ]; then
        echo "no default route for 30+ minutes; rebooting as last resort"
        systemctl reboot
      fi
    '';
  };
  systemd.timers.network-watchdog = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "2min";
    };
  };

  # rclone mount (FUSE) support
  programs.fuse.userAllowOther = true;

  # Keep user services running after logout (for rclone mount)
  users.users.potsbo.linger = true;

  system.stateVersion = "25.11";
}
