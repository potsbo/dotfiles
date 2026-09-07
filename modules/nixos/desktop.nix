# DE に依らないデスクトップ共通部分: 音、フォント、日本語入力、GUI アプリ。
# DE 本体は desktop/<name>.nix にあり、desktop.environment で選ぶ。
{ config, pkgs, lib, ... }:

let
  # Web アプリを Chrome --app モードで起動する .desktop エントリを生成
  webApp = { name, desktopName, url, icon ? "google-chrome" }:
    pkgs.makeDesktopItem {
      inherit name desktopName icon;
      exec = "${pkgs.google-chrome}/bin/google-chrome-stable --app=${url}";
      categories = [ "Network" ];
    };
in
{
  imports = [ ./desktop/plasma.nix ./desktop/hyprland.nix ];

  options.desktop.environment = lib.mkOption {
    type = lib.types.enum [ "plasma" "hyprland" "none" ];
    # 2026-09-06 に GNOME から Hyprland + DMS に切り替えた (見た目と macOS との操作の近さ)。
    # GNOME の設定 (gnome.nix) は同日に消した。戻すなら git 履歴から。
    default = "hyprland";
    description = "どの DE を有効にするか。specialisation で差し替えて別の DE を試す。";
  };

  config = lib.mkIf config.host.desktop {
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
    };

    programs.dconf.enable = true;

    # fcitx5 用の GTK_IM_MODULE / QT_IM_MODULE / XMODIFIERS はここに書かない。
    # i18n.inputMethod.fcitx5 が waylandFrontend の有無を見て必要な分だけ設定する
    # (Wayland ネイティブなら XMODIFIERS だけ)。手で GTK/QT_IM_MODULE を足すと、fcitx5 が
    # ログインごとに "Wayland Diagnose" の通知で外せと言ってくる (2026-09-07)。
    environment.sessionVariables = {
      # GTK Emacs keybindings (Ctrl+A/E/K/D/H etc.) — like macOS Cocoa
      GTK_KEY_THEME = "Emacs";
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

    programs._1password-gui = {
      enable = true;
      polkitPolicyOwners = [ "potsbo" ];
    };

    environment.systemPackages = with pkgs; [
      google-chrome
      # 端末。設定は symlink 済みの home/.config/ghostty/config を共有する。
      ghostty
      # macOS 側は cask (darwin/apps.nix)。notes リポジトリ (notes-sync.nix) を
      # GUI セッションでも直接開くため。
      obsidian
      vscode
      (webApp { name = "notion"; desktopName = "Notion"; url = "https://www.notion.so"; })
      zotero
      freerdp
      slack
      zoom-us
      code-cursor
      pgadmin4-desktopmode
    ];
  };
}
