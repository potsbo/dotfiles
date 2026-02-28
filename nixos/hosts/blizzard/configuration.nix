{ config, pkgs, lib, ... }:

let
  registryPort = 5000;

  # Mozc custom romantable (potsbo/anpan)
  anpanRelease = pkgs.fetchzip {
    url = "https://github.com/potsbo/anpan/releases/download/0.1.0/tables-0.1.0.zip";
    sha256 = "sha256-oyfVfoJppTUs0DFgwLStEykjePNnoIsYNng+qLYLJ8Q=";
    stripRoot = true;
  };
  mozcConfigProto = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/google/mozc/2.30.5544.102/src/protocol/config.proto";
    sha256 = "0d6jms4hwhagfdskmgyyijpdbix6rhaxxiq4277zcnflpiv783yg";
  };
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

  webApp = { name, desktopName, url, icon ? "chromium-browser" }:
    pkgs.makeDesktopItem {
      inherit name desktopName icon;
      exec = "${pkgs.chromium}/bin/chromium --app=${url}";
      categories = [ "Network" ];
    };
in
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nixpkgs.config.allowUnfree = true;

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "blizzard";

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
    pulse.enable = true;
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  # Enable the X11/Wayland display server and GNOME desktop environment.
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.displayManager.gdm.autoSuspend = false;
  services.desktopManager.gnome.enable = true;

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
          ];
        };
        "org/gnome/shell/extensions/tiling-assistant" = {
          enable-tiling-popup = false;
          tile-topleft-quarter = [ "<Super>u" ];
          tile-topright-quarter = [ "<Super>i" ];
          tile-bottomleft-quarter = [ "<Super>j" ];
          tile-bottomright-quarter = [ "<Super>k" ];
        };
        "org/gnome/desktop/wm/keybindings" = let
          noBinding = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        in {
          switch-to-workspace-up = noBinding;
          switch-to-workspace-down = noBinding;
          switch-to-workspace-left = noBinding;
          switch-to-workspace-right = noBinding;
        };
        "org/gnome/settings-daemon/plugins/power" = {
          sleep-inactive-ac-type = "nothing";
          sleep-inactive-battery-type = "nothing";
        };
        "org/gnome/desktop/interface" = {
          font-name = "Noto Sans CJK JP 11";
          document-font-name = "Noto Sans CJK JP 12";
          monospace-font-name = "JetBrains Mono 11";
          font-antialiasing = "grayscale";
          font-hinting = "none";
        };
        "org/gnome/desktop/wm/preferences" = {
          titlebar-font = "Noto Sans CJK JP Bold 11";
        };
      };
    }];
  };

  environment.sessionVariables = {
    GTK_KEY_THEME = "Emacs";
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
    BUILDX_BUILDER = "oci-builder";
  };

  users.users.potsbo = {
    uid = 1000;
    isNormalUser = true;
    description = "Shimpei Otsubo";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    shell = pkgs.zsh;
    packages = with pkgs; [];
  };
  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      insecure-registries = [ "blizzard:${toString registryPort}" ];
      features.containerd-snapshotter = true;
    };
  };

  environment.etc."buildkitd/oci-builder.toml".text = ''
    [worker.oci]
      gc = true
      compression = "zstd"
      force-compression = true

    [registry."blizzard:${toString registryPort}"]
      http = true
      insecure = true
  '';

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

  environment.systemPackages = with pkgs; [
    git
    ghostty
    chromium
    _1password-gui
    xremap-gnome-extension
    gnomeExtensions.tiling-assistant
    gnomeExtensions.appindicator
    slack
    vscode
    (webApp { name = "notion"; desktopName = "Notion"; url = "https://www.notion.so"; })
    zotero
  ];

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

      Macs = [
        "hmac-sha2-512-etm@openssh.com"
        "hmac-sha2-256-etm@openssh.com"
        "umac-128-etm@openssh.com"
        "hmac-sha2-512"
        "hmac-sha2-256"
      ];
    };
  };
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    extraUpFlags = [ "--advertise-exit-node" ];
  };

  networking.firewall.trustedInterfaces = [ "tailscale0" ];

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

  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };
  services.logind = {
    settings.Login = {
      HandleSuspendKey = "ignore";
      HandleLidSwitchDocked = "ignore";
      HandleHibernateKey = "ignore";
      HandleLidSwitch = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      IdleAction = "ignore";
    };
  };
  powerManagement.enable = false;

  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 5;
    extraArgs = [
      "--avoid" "^(sshd|tailscaled|systemd)"
    ];
  };

  programs.fuse.userAllowOther = true;

  users.users.potsbo.linger = true;

  system.stateVersion = "25.11";

}
