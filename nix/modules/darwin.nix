{ pkgs, ... }:

{
  nix.enable = false;
  system.primaryUser = "potsbo";

  environment.etc."sudoers.d/potsbo".text = ''
    potsbo ALL=(ALL) NOPASSWD: ALL
  '';

  # ディスプレイ解像度は nix-darwin では設定できないため、手動で "More Space" に変更する
  # System Settings > Displays > More Space
  system.defaults = {
    dock.autohide = true;

    NSGlobalDomain = {
      KeyRepeat = 1;
      InitialKeyRepeat = 15;
    };

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
    taps = [
      "nikitabobko/tap"
      "felixkratz/formulae"
    ];
    brews = [
      "felixkratz/formulae/borders"
      "libomp" # LightGBM 等の機械学習ライブラリのビルドに必要
    ];
    masApps = {
      "Amphetamine" = 937984704;
      "GoodNotes" = 1444383602;
      "Magnet" = 441258766;
      "Microsoft Excel" = 462058435;
      "Microsoft PowerPoint" = 462062816;
      "Microsoft Word" = 462054704;
      "Slack" = 803453959;
    };
    casks = [
      "nikitabobko/tap/aerospace"
      "akiflow"
      "karabiner-elements"
      "visual-studio-code"
      "google-chrome"
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
      "chatgpt"
      "claude"
    ];
  };

  system.stateVersion = 5;
}
