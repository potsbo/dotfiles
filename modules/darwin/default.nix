{ user, ... }:

{
  # nix は公式 installer で入れているので nix-darwin に nix.conf ごと管理させる
  # (Determinate installer なら nix.enable = false が要る)。初回 switch は既存の
  # /etc/nix/nix.conf があると止まるので、手で退避してから rebuild を流す:
  #   sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.before-nix-darwin
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # home-manager (darwinModules) がユーザーのホームを要求する
  users.users.${user}.home = "/Users/${user}";

  environment.etc."sudoers.d/${user}".text = ''
    ${user} ALL=(ALL) NOPASSWD: ALL
  '';

  system = {
    primaryUser = user;
    stateVersion = 5;

    # ディスプレイ解像度は nix-darwin では設定できないため、手動で "More Space" に変更する
    # System Settings > Displays > More Space
    defaults = {
      dock.autohide = true;
      finder.AppleShowAllFiles = true;

      NSGlobalDomain = {
        KeyRepeat = 1;
        InitialKeyRepeat = 15;
      };

      menuExtraClock.ShowSeconds = true;

      trackpad.Clicking = true;

      CustomUserPreferences = {
        ".GlobalPreferences" = {
          "com.apple.trackpad.scaling" = 2;
          AppleLanguages = [ "en-US" "ja-JP" ];
        };
        "com.apple.AppleMultitouchTrackpad" = {
          Clicking = true;
        };
        "com.apple.dock" = {
          showAppExposeGestureEnabled = true;
          expose-group-apps = true;
        };
        # Chrome 内蔵の DNS client を切って macOS の resolver (mDNSResponder) に戻す。
        # 内蔵 client は起動時に読んだ resolver 設定を持ち続けるので、Tailscale の
        # split DNS (MagicDNS の 100.100.100.100) が付いたり外れたりすると古い設定の
        # まま NXDOMAIN を返し続け、回線が戻っても Chrome だけ名前を引けない状態が残る。
        # DoH も MagicDNS 名を引けなくなるので併せて切る。
        "com.google.Chrome" = {
          BuiltInDnsClientEnabled = false;
          DnsOverHttpsMode = "off";
        };
        # Cmd+Shift+Space の入力ソース切り替えを無効化 (WezTerm QuickSelect で使うため)
        "com.apple.symbolichotkeys" = {
          AppleSymbolicHotKeys = {
            # 61 = "Select next source in Input menu"
            "61" = { enabled = false; };
            # 64 = "Show Spotlight search"
            "64" = { enabled = false; };
          };
        };
      };
    };
  };

  # GitHub の公開鍵で SSH できるようにする (NixOS の common.nix と同等)
  services.openssh = {
    enable = true;
    extraConfig = ''
      PubkeyAuthentication yes
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      AuthorizedKeysCommand /usr/bin/curl -fsSL https://github.com/%u.keys
      AuthorizedKeysCommandUser nobody
    '';
  };
}
