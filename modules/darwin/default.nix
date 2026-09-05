{ pkgs, ... }:

{
  nix.enable = false;
  system.primaryUser = "potsbo";
  # home-manager (darwinModules) がユーザーのホームを要求する
  users.users.potsbo.home = "/Users/potsbo";

  environment.etc."sudoers.d/potsbo".text = ''
    potsbo ALL=(ALL) NOPASSWD: ALL
  '';

  # ディスプレイ解像度は nix-darwin では設定できないため、手動で "More Space" に変更する
  # System Settings > Displays > More Space
  system.defaults = {
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

  system.stateVersion = 5;
}
