{ pkgs, ... }:

{
  nix.enable = false;
  system.primaryUser = "potsbo";

  environment.etc."sudoers.d/potsbo".text = ''
    potsbo ALL=(ALL) NOPASSWD: ALL
  '';

  system.defaults = {
    dock.autohide = true;

    NSGlobalDomain = {
      KeyRepeat = 1;
      InitialKeyRepeat = 15;
      AppleLanguages = [ "en-US" "ja-JP" ];
      AppleLocale = "en_US";
    };

    trackpad.Clicking = true;

    CustomUserPreferences = {
      ".GlobalPreferences" = {
        "com.apple.trackpad.scaling" = 2;
      };
    };
  };

  homebrew = {
    enable = true;
    onActivation = {
      # zap: 宣言から外したアプリを削除する際に設定ファイルも一緒に削除
      # uninstall: アプリのみ削除、設定は残る
      cleanup = "zap";
      autoUpdate = true;
      upgrade = true;
    };
    casks = [
      "akiflow"
      "karabiner-elements"
      "visual-studio-code"
      "google-japanese-ime"
      "raycast"
      "keyboard-cleaner"
      "zoom"
      "dash"
      "docker-desktop"
      "1password"
      "notion"
      "notion-calendar"
      "font-monaspice-nerd-font"
      "tailscale-app"
      "ghostty"
      "cursor"
      "zotero"
    ];
  };

  system.stateVersion = 5;
}
