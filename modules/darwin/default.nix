{ user, pkgs, ... }:

{
  # nix は公式 installer で入れているので nix-darwin に nix.conf ごと管理させる
  # (Determinate installer なら nix.enable = false が要る)。初回 switch は既存の
  # /etc/nix/nix.conf があると止まるので、手で退避してから rebuild を流す:
  #   sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.before-nix-darwin
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # ログインシェルを NixOS (modules/nixos/common.nix) と同じ nix の zsh にする。
  # 宣言しないと Apple の /bin/zsh のままで、PATH 上の zsh (nix) と版がずれる。
  # nix-darwin が UserShell を書くのは knownUsers に入れたユーザーだけ。既存ユーザーに
  # 対しては UserShell と PrimaryGroupID (既定 20 = staff、macOS の既定と同じ) を
  # 書き直すだけで、作り直しはしない。uid が実機と食い違うと警告を出して飛ばすので、
  # そのときは `id -u` の値に合わせる (doctor の login shell が missing になる)。
  users.knownUsers = [ user ];
  users.users.${user} = {
    # home-manager (darwinModules) がユーザーのホームを要求する
    home = "/Users/${user}";
    uid = 501; # macOS で最初に作ったユーザー
    shell = pkgs.zsh;
  };
  # /etc/shells に載せる (NixOS は programs.zsh.enable が載せる)。chsh などは載っていない
  # シェルを不正扱いする。nix-darwin は /etc/shells が macOS 標準の中身のときだけ
  # 置き換えるので、手で書き足してあると activation が止まる。そのときは退避してから rebuild。
  environment.shells = [ pkgs.zsh ];

  # /etc/zshrc で compinit を走らせない。NixOS (modules/nixos/common.nix) と同じ理由で、
  # -d なしの compinit が ~/.zcompdump を作り、.zshrc の compinit と二重になる。
  # bashcompinit も NixOS の既定 (off) に揃える。.zshrc は bash 形式の補完を使っていないし、
  # compinit 抜きで bashcompinit だけ走らせると compdef が無い状態で呼ばれる。
  programs.zsh = {
    enableGlobalCompInit = false;
    enableBashCompletion = false;
  };

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
            # 52 = "Turn Dock hiding on/off" (Cmd+Option+D)。docs/keymap.md の G1 に充てる。
            # Karabiner が先にキーを食うので通常は届かないが、Karabiner が止まっているときに
            # 押して Dock が黙って隠れる事故を防ぐ。
            "52" = { enabled = false; };
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
