# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

let
  registryPort = 5000;
in
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "phoenix";

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

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  # Enable the X11/Wayland display server and GNOME desktop environment.
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # GTK Emacs keybindings (Ctrl+A/E/K/D/H etc.) — like macOS Cocoa
  environment.sessionVariables.GTK_KEY_THEME = "Emacs";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.potsbo = {
    isNormalUser = true;
    description = "Shimpei Otsubo";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    shell = pkgs.zsh;
    packages = with pkgs; [];
  };
  virtualisation.docker = {
    enable = true;
    daemon.settings.insecure-registries = [ "phoenix:${toString registryPort}" ];
  };

  # Install firefox.
  programs.zsh.enable = true;
  programs.nix-ld.enable = true; # node を動作させたい
  programs.nix-ld.libraries = with pkgs; [
    readline
    krb5.lib
  ];
  programs.mosh.enable = true;


  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    git
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
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
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    extraUpFlags = [ "--advertise-exit-node" ];
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

  # 常時稼働サーバ用途のため、勝手に suspend しないように設定
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };
  services.logind = {
    settings.Login = {
      # 物理サスペンドキー（Sleep ボタン）を無効化
      HandleSuspendKey = "ignore";
      HandleLidSwitchDocked = "ignore";

      # ハイバネートキーを無効化
      HandleHibernateKey = "ignore";

      # 蓋クローズイベントを完全に無視
      HandleLidSwitch = "ignore";

      # 外部電源接続時の蓋クローズも無視
      HandleLidSwitchExternalPower = "ignore";

      # アイドル状態になっても何もしない
      # （デフォルトの自動 suspend を防ぐ）
      IdleAction = "ignore";
    };
  };
  powerManagement.enable = false;

  # OOM 対策: カーネル OOM キラーが発動する前にプロアクティブにプロセスを kill する
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 5;
    extraArgs = [
      "--avoid" "^(sshd|tailscaled|systemd)"
    ];
  };

  # rclone mount (FUSE) support
  programs.fuse.userAllowOther = true;

  # Keep user services running after logout (for rclone mount)
  users.users.potsbo.linger = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
