# Hyprland + DankMaterialShell (DMS)。desktop.environment (modules/nixos/desktop.nix) の
# 既定で、GUI ありの NixOS ホスト全部で有効になる。GNOME (gnome.nix) は phoenix の
# specialisation に残している。
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
  launcherEntries = pkgs.runCommand "dms-launcher-entries" { } ''
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

    # DMS の雛形 (home/.config/hypr/hyprland.lua) は起動時に hyprland-session.target を start して
    # graphical-session.target (DMS、xremap、portal が紐づく) を上げる。upstream の Hyprland は
    # この target を同梱するが nixpkgs は UWSM 無しだと入れないので、同じ中身を自前で定義する。
    # UWSM (programs.hyprland.withUWSM) にしない理由: セッションの起動経路とアプリ起動
    # (uwsm-app) が変わり、DMS の雛形と食い違う部分が増える。target 1 つで足りる。
    systemd.user.targets.hyprland-session = {
      description = "Hyprland compositor session";
      documentation = [ "man:systemd.special(7)" ];
      bindsTo = [ "graphical-session.target" ];
      wants = [ "graphical-session-pre.target" ];
      after = [ "graphical-session-pre.target" ];
    };

    # greeter は GNOME と同じ GDM。Hyprland のセッションが一覧に並ぶ。DMS にも greeter
    # (dank-greeter) はあるが、ログイン画面のために input を増やすほどではない
    services.displayManager.gdm.enable = true;

    programs.dank-material-shell = {
      enable = true;
      systemd.enable = true;
    };

    # DMS の unit は graphical-session.target に紐づくので、GDM の greeter (gdm ユーザーの
    # GNOME Shell) でも起動して /var/lib/gdm に設定を書こうとする。システムユーザーでは走らせない。
    systemd.user.services.dms.unitConfig.ConditionUser = "!@system";

    # fcitx5 (日本語入力)。GNOME は XDG autostart (/etc/xdg/autostart) で起動していたが、Hyprland
    # にはそれを走らせる仕組みが無い。omarchy と同じく user unit で起動する。
    # `--disable notificationitem` はトレイに fcitx5 のアイコンを出さないため (DMS が持つ)。
    systemd.user.services.fcitx5 = {
      description = "Fcitx5 input method";
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      unitConfig.ConditionUser = "!@system";
      serviceConfig = {
        ExecStart = "${config.i18n.inputMethod.package}/bin/fcitx5 --disable notificationitem";
        Restart = "on-failure";
        RestartSec = 2;
      };
    };

    # Cmd+Tab: macOS のようにアイコンが並び、Cmd を押している間に Tab で選んで離すと切り替わる。
    # Hyprland にも DMS にもこの UI は無いので hyprshell (旧 hyprswitch) を使う。切り替えの
    # 候補は最近使った順、全モニタ・全ワークスペース (macOS と同じ)。Super+` は同じアプリの
    # ウィンドウだけを回す (macOS の Cmd+`)。Ctrl+Down は App Exposé 相当で、いまのアプリの
    # ウィンドウを並べる。hyprshell は起動時にこれらのキーを Hyprland に自分で登録する。
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
        overview = {
          modifier = "ctrl";
          key = "Down";
          filter_by = [ "same_class" ];
          # overview にはランチャーが付くが、ランチャーは DMS を使うので出さない
          launcher.max_items = 0;
        };
      };
    };

    # ランチャーからの起動を dms-focus-or-launch (同名の .sh) で包み、開いているアプリなら
    # 起動せずフォーカスする。DMS の設定画面 (Launcher > launch prefix) が空のときの既定値。
    systemd.user.services.dms.environment.DMS_DEFAULT_LAUNCH_PREFIX = lib.getExe focusOrLaunch;
    # 差し替えた .desktop を XDG_DATA_DIRS の先頭で DMS に見せる。unit の Environment= では
    # 既存の XDG_DATA_DIRS に足せないので、起動スクリプトで前置してから DMS を exec する。
    systemd.user.services.dms.serviceConfig.ExecStart = lib.mkForce (pkgs.writeShellScript "dms-session" ''
      export XDG_DATA_DIRS="${launcherEntries}/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
      exec ${lib.getExe config.programs.dank-material-shell.package} run --session
    '');
    environment.systemPackages = [ focusOrLaunch ];
  };
}
