# DankMaterialShell (DMS) と、その周りの DE に依らない部分: greeter (GDM)、ランチャー、
# 日本語入力の起動。compositor 本体は desktop/hyprland.nix と desktop/niri.nix にある。
#
# DMS は Hyprland でも niri でも同じものが動く (bar・ランチャー・通知・ロック画面)。
# compositor を試すたびにこの一式を書き写さずに済むよう、ここに集めてある。
#
# DMS 本体は NixOS module 側で入れ、home-manager module は使わない (両方入れると
# systemd unit が二重定義になる)。
#
# omarchy (nixarchy) は試したうえでやめた。見た目は良かったが、初回ログインの provisioning が
# ~ に shim・.desktop・gsettings・mise 設定を撒く設計で、~ を dotfiles で管理している
# この構成とは折り合わなかった。DMS は手を出す範囲が compositor の設定ディレクトリと
# 自分の設定ディレクトリに限られる。
{ config, pkgs, lib, ... }:

let
  focusOrLaunch = pkgs.writeShellApplication {
    name = "dms-focus-or-launch";
    runtimeInputs = [ pkgs.jq ]
      ++ lib.optional (config.desktop.environment == "hyprland") config.programs.hyprland.package
      ++ lib.optional (config.desktop.environment == "niri") config.programs.niri.package;
    text = builtins.readFile ./dms-focus-or-launch.sh;
  };

  # DMS のランチャーに見せる .desktop の写し。[Desktop Entry] の Exec を dms-focus-or-launch で
  # 包む ([Desktop Action] の "New Window" などは新規起動が目的なので包まない)。
  # DMS の launch prefix (設定・環境変数) は 1.6.0 では効かなかった: strace で見ると起動は
  # `systemd-run --user --scope <Exec>` で prefix が付かない。PATH の shim は google-chrome や
  # slack のように Exec が絶対パスのものに効かないので、.desktop 自体を差し替える。
  #
  # runCommandLocal にしておく。入力に system-path と home-manager-path 全体を持つので、
  # remote builder に出ると cache.nixos.org に無い unfree アプリ (1password, chrome, slack
  # など合計 1 GB 強) を builder に送ることになる。awk で .desktop を書き換えるだけなので
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
  config = lib.mkIf (config.host.desktop && config.desktop.environment != "none") {
    services = {
      # greeter は GDM。compositor のセッションが一覧に並ぶ。DMS にも greeter
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
      # 無いので、user unit で起動する。niri は xdg-desktop-autostart.target を持つが、そちらに
      # 任せると compositor ごとに起動経路が変わるので、両方ともこの unit に寄せる
      # (fcitx5 は二重起動しても後発が終了するだけ)。
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

    environment.systemPackages = [
      focusOrLaunch
      # キーボードバックライト (XF86KbdBrightnessUp/Down、compositor 側の設定から呼ぶ)。
      # DMS の brightness IPC は画面のバックライトしか扱わない。brightnessctl は logind の
      # SetBrightness 経由で leds クラスも書けるので、udev 規則も root も要らない。
      pkgs.brightnessctl
    ];
  };
}
