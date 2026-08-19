{ ... }:

# macOS の GUI アプリ (Homebrew cask / Mac App Store) の宣言。
# brew / mas の更新は遅く、`./install` で毎回挟まると鬱陶しいので
# 本体の darwin.nix から切り離し、`./install-apps` から入る
# `<host>-apps` 構成でだけ読み込む。
{
  homebrew = {
    enable = true;
    onActivation = {
      # zap: 宣言から外したアプリを削除する際に設定ファイルも一緒に削除
      # uninstall: アプリのみ削除、設定は残る
      cleanup = "zap";
      # false: `brew update` は手動で実行し、意図したタイミングでのみバージョンを上げる
      autoUpdate = false;
      upgrade = true;
    };
    brews = [
      "libomp" # LightGBM 等の機械学習ライブラリのビルドに必要
    ];
    masApps = {
      "Amphetamine" = 937984704;
      "Magnet" = 441258766;
      "Microsoft Excel" = 462058435;
      "Microsoft PowerPoint" = 462062816;
      "Microsoft Word" = 462054704;
      "Slack" = 803453959;
      "Todoist" = 585829637;
      "Windows App" = 1295203466;
    };
    casks = [
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
      "obsidian"
      "font-monaspice-nerd-font"
      "ghostty"
      # ターミナルの日本語フォールバック (home/.config/ghostty/config)。
      # 未インストールだと一部の漢字が tofu (斜線付き□) になるため必須。
      "font-biz-udgothic"
      "tailscale-app"
      "chatgpt"
      "claude"
      "pgadmin4"
      "plaud"
    ];
  };
}
