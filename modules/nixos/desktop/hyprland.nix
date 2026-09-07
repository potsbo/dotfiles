# Hyprland + DankMaterialShell (DMS)。desktop.environment (modules/nixos/desktop.nix) の
# 既定で、GUI ありの NixOS ホスト全部で有効になる。
#
# omarchy (nixarchy) は試したうえでやめた。見た目は良かったが、初回ログインの provisioning が
# ~ に shim・.desktop・gsettings・mise 設定を撒く設計で、~ を dotfiles で管理している
# この構成とは折り合わなかった。DMS は手を出す範囲が ~/.config/hypr と自分の設定
# ディレクトリに限られる。
#
# Hyprland の設定は home/.config/hypr/ (DMS の `dms setup` が配る雛形を元に、上書きは
# dms/binds-user.lua に集める)。DMS 本体は NixOS module 側で入れ、home-manager module は
# 使わない (両方入れると systemd unit が二重定義になる)。
{ config, pkgs, lib, ... }:

let
  focusOrLaunch = pkgs.writeShellApplication {
    name = "dms-focus-or-launch";
    runtimeInputs = [ pkgs.jq config.programs.hyprland.package ];
    text = builtins.readFile ./dms-focus-or-launch.sh;
  };

  # DMS のランチャーに見せる .desktop の写し。[Desktop Entry] の Exec を dms-focus-or-launch で
  # 包む ([Desktop Action] の "New Window" などは新規起動が目的なので包まない)。
  # DMS の launch prefix (設定・環境変数) は 1.6.0 では効かなかった: strace で見ると起動は
  # `systemd-run --user --scope <Exec>` で prefix が付かない。PATH の shim は google-chrome や
  # slack のように Exec が絶対パスのものに効かないので、.desktop 自体を差し替える。
  #
  # runCommandLocal にしておく。入力に system-path と home-manager-path 全体を持つので、
  # remote builder に出ると cache.nixos.org に無い unfree アプリ (vscode, zoom, cursor など
  # 合計 6 GB 弱) を builder に送ることになる。awk で .desktop を書き換えるだけなので
  # ローカルで十分。パス全体を入力に取る runCommand は同じ罠になる。
  launcherEntries = pkgs.runCommandLocal "dms-launcher-entries" { } ''
    mkdir -p $out/share/applications
    for dir in ${config.system.path}/share/applications ${config.home-manager.users.potsbo.home.path}/share/applications; do
      [ -d "$dir" ] || continue
      for f in "$dir"/*.desktop; do
        name=$(basename "$f")
        [ -e "$out/share/applications/$name" ] && continue
        awk -v w='${lib.getExe focusOrLaunch}' '
          /^\[/ { entry = ($0 == "[Desktop Entry]") }
          entry && /^Exec=/ { sub(/^Exec=/, "Exec=" w " ") }
          { print }
        ' "$f" > "$out/share/applications/$name"
      done
    done
  '';
in
{
  config = lib.mkIf (config.host.desktop && config.desktop.environment == "hyprland") {
    programs.hyprland.enable = true;

    services = {
      # greeter は GDM。Hyprland のセッションが一覧に並ぶ。DMS にも greeter
      # (dank-greeter) はあるが、ログイン画面のために input を増やすほどではない
      displayManager.gdm.enable = true;

      # greeter の画面消灯は gsd-power (gnome-settings-daemon) がやる。GDM の module が入れる
      # unit は gnome-session と gnome-shell だけで、GNOME デスクトップ無しだと greeter が
      # wants する org.gnome.SettingsDaemon.*.target が not-found のまま、ログイン画面を
      # 放置しても画面が消えない。
      gnome.gnome-settings-daemon.enable = true;
      # gsd-power は org.gnome.ScreenSaver の ActiveChanged を待って 15 秒後に消灯する。
      # この名前を持つのは gnome-shell 本体ではなく、D-Bus 起動される中継サービス
      # (gnome-shell 同梱の org.gnome.ScreenSaver.service) で、GDM の module は gnome-shell を
      # bus の検索パスに載せないため greeter では「not activatable」になり、shell が
      # スクリーンセーバーを有効にしても gsd-power に届かなかった。
      dbus.packages = [ pkgs.gnome-shell ];
    };

    programs.dank-material-shell = {
      enable = true;
      systemd.enable = true;
    };

    systemd.user = {
      # DMS の雛形 (home/.config/hypr/hyprland.lua) は起動時に hyprland-session.target を start して
      # graphical-session.target (DMS、xremap、portal が紐づく) を上げる。upstream の Hyprland は
      # この target を同梱するが nixpkgs は UWSM 無しだと入れないので、同じ中身を自前で定義する。
      # UWSM (programs.hyprland.withUWSM) にしない理由: セッションの起動経路とアプリ起動
      # (uwsm-app) が変わり、DMS の雛形と食い違う部分が増える。target 1 つで足りる。
      targets.hyprland-session = {
        description = "Hyprland compositor session";
        documentation = [ "man:systemd.special(7)" ];
        bindsTo = [ "graphical-session.target" ];
        wants = [ "graphical-session-pre.target" ];
        after = [ "graphical-session-pre.target" ];
      };

      services.dms = {
        # DMS の unit は graphical-session.target に紐づくので、GDM の greeter (GNOME Shell) でも
        # 起動する。そこで org.gnome.ScreenSaver を gnome-shell から横取りするため gsd-power に
        # スクリーンセーバー有効の通知が届かず、ログイン画面の画面消灯が効かなくなる。
        # `ConditionUser=!@system` では止まらない: GDM 50 の greeter は gdm-greeter-N という
        # 通常 uid 帯のユーザーで走る。greeter かどうかはセッションの class で見る
        # (xremap.nix の同じ条件も同じ理由)。
        unitConfig.ConditionEnvironment = "!XDG_SESSION_CLASS=greeter";

        # ランチャーからの起動を dms-focus-or-launch (同名の .sh) で包み、開いているアプリなら
        # 起動せずフォーカスする。DMS の設定画面 (Launcher > launch prefix) が空のときの既定値。
        environment.DMS_DEFAULT_LAUNCH_PREFIX = lib.getExe focusOrLaunch;
        # 差し替えた .desktop を XDG_DATA_DIRS の先頭で DMS に見せる。unit の Environment= では
        # 既存の XDG_DATA_DIRS に足せないので、起動スクリプトで前置してから DMS を exec する。
        serviceConfig.ExecStart = lib.mkForce (pkgs.writeShellScript "dms-session" ''
          export XDG_DATA_DIRS="${launcherEntries}/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
          exec ${lib.getExe config.programs.dank-material-shell.package} run --session
        '');
      };

      # fcitx5 (日本語入力)。XDG autostart (/etc/xdg/autostart) を走らせる仕組みが Hyprland には
      # 無いので、user unit で起動する。
      # `--disable notificationitem` はトレイに fcitx5 のアイコンを出さないため (DMS が持つ)。
      services.fcitx5 = {
        description = "Fcitx5 input method";
        after = [ "graphical-session.target" ];
        partOf = [ "graphical-session.target" ];
        wantedBy = [ "graphical-session.target" ];
        unitConfig.ConditionEnvironment = "!XDG_SESSION_CLASS=greeter";
        serviceConfig = {
          ExecStart = "${config.i18n.inputMethod.package}/bin/fcitx5 --disable notificationitem";
          Restart = "on-failure";
          RestartSec = 2;
        };
      };
    };

    # Cmd+Tab: macOS のようにアイコンが並び、Cmd を押している間に Tab で選んで離すと切り替わる。
    # Hyprland にも DMS にもこの UI は無いので hyprshell (旧 hyprswitch) を使う。切り替えの
    # 候補は最近使った順、全モニタ・全ワークスペース (macOS と同じ)。Super+` は同じアプリの
    # ウィンドウだけを回す (macOS の Cmd+`)。hyprshell は起動時にこれらのキーを Hyprland に
    # 自分で登録する。
    home-manager.users.potsbo.services.hyprshell = {
      enable = true;
      # 設定ファイルの版。無いと hyprshell は設定を読まず (移行判定で止まる)、バインドも登録
      # されない。hyprshell を上げたら `hyprshell config check` で確かめる
      settings.version = 4;
      settings.windows = {
        switch = {
          modifier = "super";
          key = "Tab";
          filter_by = [ ];
        };
        switch_2 = {
          modifier = "super";
          key = "grave";
          filter_by = [ "same_class" ];
        };
        # Ctrl+Up: 全ウィンドウを縮小して並べる (macOS の Mission Control でウィンドウが並ぶ部分)。
        # DMS の俯瞰はワークスペース単位で、ウィンドウを並べる形ではなかった。overview は
        # 1 つしか持てないので App Exposé (同じアプリだけ) はここでは出さない。
        overview = {
          modifier = "ctrl";
          key = "Up";
          filter_by = [ ];
          # overview にはランチャーが付くが、ランチャーは DMS を使うので出さない
          launcher.max_items = 0;
        };
      };
    };

    environment.systemPackages = [
      focusOrLaunch
      # キーボードバックライト (XF86KbdBrightnessUp/Down、home/.config/hypr/dms/binds-user.lua)。
      # DMS の brightness IPC は画面のバックライトしか扱わない。brightnessctl は logind の
      # SetBrightness 経由で leds クラスも書けるので、udev 規則も root も要らない。
      pkgs.brightnessctl
    ];
  };
}
