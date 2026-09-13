# DE に依らないデスクトップ共通部分: 音、フォント、日本語入力、GUI アプリ。
# DE 本体は desktop/<name>.nix にあり、desktop.environment で選ぶ。
{ config, pkgs, lib, ... }:

let
  # Web アプリを Chrome --app モードで起動する .desktop エントリを生成
  #
  # profile は Chrome のプロファイルディレクトリ名 (~/.config/google-chrome/ の下)。渡さないと
  # Chrome は最後に使ったプロファイルで開くので、仕事用を触った後に起動すると仕事用のアカウントで
  # 開いてしまう。個人のアカウントで固定したいものは明示する。
  #
  # wmSlug は Chrome が --app ウィンドウの app-id に使う文字列で、host + "_" + path の非英数字を
  # "_" にした物 (実測: https://music.apple.com/us/home → music.apple.com__us_home)。タスクバーは
  # ウィンドウの app-id から .desktop を引いてアイコンを出すので、これを渡さないと下の icon が
  # 効かずウィンドウ側だけ既定アイコンになる。app-id の末尾にはプロファイル名が付くため、
  # ここで profile から組み立てて両者がずれないようにしている。合わなくなったら
  # `niri msg windows` で実際の app-id を見て直す。
  webApp = { name, desktopName, url, icon ? "google-chrome", profile ? null, wmSlug ? null }:
    pkgs.makeDesktopItem {
      inherit name desktopName icon;
      exec = "${pkgs.google-chrome}/bin/google-chrome-stable"
        + lib.optionalString (profile != null) " --profile-directory=${lib.escapeShellArg profile}"
        + " --app=${url}";
      categories = [ "Network" ];
      startupWMClass = lib.mapNullable
        (slug: "chrome-${slug}-${lib.replaceStrings [ " " ] [ "_" ] (if profile == null then "Default" else profile)}")
        wmSlug;
    };

  # Apple Music のアイコン。Apple の PWA manifest (music.apple.com/manifest.json) が指している
  # ものをビルド時に取ってきて hicolor テーマに入れる。png をリポジトリに commit しないのは、
  # 公開リポジトリに Apple の意匠を持ち込まないため。代償として Apple が差し替えると hash 不一致で
  # ビルドが落ちる (eval では落ちないので task check は素通りする)。落ちたら
  # `nix store prefetch-file <url>` で取り直す。
  appleMusicIcon = pkgs.runCommand "apple-music-icon" { } ''
    install -Dm444 ${pkgs.fetchurl {
      url = "https://music.apple.com/assets/app-icons/pwa-manifest/music-icon_512.png";
      hash = "sha256-8pFrNe2Sb0gbz/ZJ6UpCWpx3jo+++zvJhunMJteFSkk=";
    }} $out/share/icons/hicolor/512x512/apps/apple-music.png
  '';
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
    # これだけでフォールバックカーソルは直る。ただしサイズは直らない: ここで出る
    # XCURSOR_SIZE / XCURSOR_THEME は hm-session-vars.sh 経由でシェルにしか届かず、
    # GDM から起動する compositor 自身には入らない。compositor は自分の既定値
    # (niri ならテーマ "default"、サイズ 24) を使い、それを子プロセスに配り直す。
    # そちら側にも同じ値を書く必要がある (home/.config/niri/user.kdl の cursor ノード)。
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
      appleMusicIcon
      (webApp {
        name = "apple-music";
        desktopName = "Apple Music";
        url = "https://music.apple.com/us/home";
        icon = "apple-music";
        profile = "Default";
        wmSlug = "music.apple.com__us_home";
      })
      freerdp
      slack
      pgadmin4-desktopmode
    ];
  };
}
