# DE に依らないデスクトップ共通部分: 音、フォント、日本語入力、GUI アプリ。
# DE 本体は desktop/<name>.nix にあり、desktop.environment で選ぶ。
{ config, pkgs, lib, ... }:

let
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

  # Web アプリを Chrome/Chromium --app モードで起動する .desktop エントリを生成
  webApp = { name, desktopName, url, icon ? browser.icon }:
    pkgs.makeDesktopItem {
      inherit name desktopName icon;
      exec = "${browser.binary} --app=${url}";
      categories = [ "Network" ];
    };
in
{
  imports = [ ./desktop/gnome.nix ];

  options.desktop.environment = lib.mkOption {
    type = lib.types.enum [ "gnome" "none" ];
    default = "gnome";
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
      alsa.support32Bit = isX86;
      pulse.enable = true;
    };

    # Disable tap-to-click on touchpad
    services.libinput.touchpad.tapping = false;

    programs.dconf.enable = true;

    environment.sessionVariables = {
      # GTK Emacs keybindings (Ctrl+A/E/K/D/H etc.) — like macOS Cocoa
      GTK_KEY_THEME = "Emacs";
      # fcitx5 input method
      GTK_IM_MODULE = "fcitx";
      QT_IM_MODULE = "fcitx";
      XMODIFIERS = "@im=fcitx";
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
      browser.package
      # 端末。設定は symlink 済みの home/.config/ghostty/config を共有する。
      ghostty
      # macOS 側は cask (darwin/apps.nix)。notes リポジトリ (notes-sync.nix) を
      # GUI セッションでも直接開くため。
      obsidian
      vscode
      vicinae
      (webApp { name = "notion"; desktopName = "Notion"; url = "https://www.notion.so"; })
      zotero
      freerdp
    ] ++ lib.optionals isX86 (with pkgs; [
      slack
      zoom-us
      code-cursor
      pgadmin4-desktopmode
    ]);
  };
}
