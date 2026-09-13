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
  imports = [ ./desktop/dms.nix ./desktop/hyprland.nix ./desktop/niri.nix ];

  options.desktop.environment = lib.mkOption {
    type = lib.types.enum [ "hyprland" "niri" "none" ];
    # 2026-09-06 に GNOME から Hyprland + DMS に切り替えた (見た目と macOS との操作の近さ)。
    # GNOME の設定 (gnome.nix) は同日に消し、試用していた Plasma (plasma.nix) も 2026-09-08 に
    # 使っていないので消した。戻すなら git 履歴から。
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

    # マウスカーソル。Hyprland でも niri でも同じものを使うのでここに置く。
    #
    # 指定しないと壊れる: compositor が引く xcursor テーマ名の既定値は "default" で、
    # NixOS はその名前のテーマ (/usr/share/icons/default/index.theme) を作らない。
    # 結果どの形も解決できず compositor 組み込みのフォールバックカーソルが出る
    # (niri なら journal に "error loading xcursor default@24: no default icon" が並ぶ)。
    # home.pointerCursor が ~/.icons/default/index.theme を Inherits 付きで置くので、
    # compositor 側の設定 (niri の cursor ノード等) には何も書かなくてよい。
    #
    # dconf に残っていた Bibata-Modern-Ice は、やめた omarchy 試用 (desktop/dms.nix の
    # 冒頭) が gsettings に書いた名残で、パッケージはもう入っていない。GTK/GNOME の
    # 既定である Adwaita に寄せて、dconf 側も同じ値で上書きする。
    home-manager.users.potsbo = {
      home.pointerCursor = {
        enable = true;
        package = pkgs.adwaita-icon-theme;
        name = "Adwaita";
        # 4K を等倍 (約 160dpi) で使っているので、96dpi 前提の 24 では物理的に小さすぎる。
        size = 32;
      };

      # GNOME はもう無いが、この 3 つだけは GNOME 以外も読む: color-scheme は GTK4/
      # libadwaita アプリと portal が、cursor-* は GTK と XSETTINGS 側が見る。
      # 残りの org/gnome/** (mutter・gnome-shell・gsd・各 GNOME アプリ) は読む物が
      # 居ないので 2026-09-13 に dconf から消した。GNOME を消したときに dconf だけ
      # 生き残っていて、その中の cursor-theme が上の事故の元になっている。
      dconf.settings."org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        cursor-theme = "Adwaita";
        cursor-size = 32;
      };
    };

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
      (webApp { name = "notion"; desktopName = "Notion"; url = "https://www.notion.so"; })
      freerdp
      slack
      pgadmin4-desktopmode
    ];
  };
}
