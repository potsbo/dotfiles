# Hyprland。desktop.environment (modules/nixos/desktop.nix) の既定で、GUI ありの NixOS
# ホスト全部で有効になる。bar・ランチャー・通知・ロック画面 (DMS) と greeter は
# desktop/dms.nix 側にあり、niri と共有する。
#
# Hyprland の設定は home/.config/hypr/ (DMS の `dms setup` が配る雛形を元に、上書きは
# dms/binds-user.lua に集める)。
{ config, lib, ... }:
{
  config = lib.mkIf (config.host.desktop && config.desktop.environment == "hyprland") {
    programs.hyprland.enable = true;

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
    };

    # Cmd+Tab: macOS のようにアイコンが並び、Cmd を押している間に Tab で選んで離すと切り替わる。
    # Hyprland にも DMS にもこの UI は無いので hyprshell (旧 hyprswitch) を使う。切り替えの
    # 候補は最近使った順、全モニタ・全ワークスペース (macOS と同じ)。Super+` は同じアプリの
    # ウィンドウだけを回す (macOS の Cmd+`)。hyprshell は起動時にこれらのキーを Hyprland に
    # 自分で登録する。(niri は同じものを compositor 内蔵の recent-windows で持つ)
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
  };
}
