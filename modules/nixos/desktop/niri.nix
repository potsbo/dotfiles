# niri (スクロール式タイリング)。desktop.environment (modules/nixos/desktop.nix) が "niri" の
# ときだけ有効になる。まずは specialisation で Hyprland と並べて試す段階 (hosts/phoenix)。
#
# bar・ランチャー・通知・ロック画面 (DMS) と greeter は desktop/dms.nix で共有する。DMS は
# niri を一級で見ていて、設定の雛形 (niri.kdl / niri-binds.kdl) も同梱している。
#
# 設定は home/.config/niri/config.kdl。DMS が書く dms/*.kdl を include し、自分の上書きは
# binds-user.kdl に置く (Hyprland 側の dms/binds-user.lua と同じ分け方)。
#
# Hyprland 側との違いで、移し替えていないもの:
# - hyprshell (Cmd+Tab): niri 側は niriswitcher (下記) と内蔵の recent-windows で分担する。
# - Magnet 風の格子配置 (binds-user.lua の place): Hyprland では絶対座標に置いていたが、
#   niri では列の幅と列の中の位置で表現する (niri-place.sh)。docs/keymap.md §4.1。
# - hyprland.lua が Hyprland の子プロセスに足している PATH と AQUA_* : niri の
#   environment ノードは値を literal にしか書けず ~ や $HOME が展開されないので、
#   同じことができない。ランチャーから起動したアプリが aqua 管理のツールを見つけられない
#   が、試用の範囲では実害が出ていない。必要になったら systemd の environment.d
#   (home-manager の systemd.user.sessionVariables) に寄せる。
{ config, pkgs, lib, ... }:

let
  # docs/keymap.md §3.4 の格子配置。niri は 1 バインド 1 action なので、複数の action を
  # まとめるスクリプトを噛ませる。バインドは home/.config/niri/user.kdl。
  place = pkgs.writeShellApplication {
    name = "niri-place";
    runtimeInputs = [ pkgs.jq config.programs.niri.package ];
    text = builtins.readFile ./niri-place.sh;
  };
in

{
  config = lib.mkIf (config.host.desktop && config.desktop.environment == "niri") {
    # セッションは niri 自身が持つ (niri-session が graphical-session.target を上げる) ので、
    # Hyprland のような target の自前定義は要らない。
    programs.niri.enable = true;

    # A3 (Cmd+Tab) のアプリ切り替えだけ niri 内蔵の recent-windows から外して niriswitcher に
    # 渡す。内蔵はウィンドウのプレビューを並べるが、端末もエディタもブラウザも全面が同系色で
    # 見分けがつかない。macOS の Cmd+Tab と同じくアイコンで探せることを優先した。
    # 同じアプリの中を切り替える W2 (Option+Tab) は内蔵のまま: アイコンが全部同じになるので、
    # あちらはプレビューの方が手掛かりになる。バインドは home/.config/niri/{config,user}.kdl。
    environment.systemPackages = [ place pkgs.niriswitcher ];

    # 修飾キーを押している間だけ出る UI なので、キーを押してから起動していては間に合わない。
    # 常駐させて niriswitcherctl が D-Bus で叩く。NIRI_SOCKET は niri がセッション開始時に
    # systemd の user manager へ渡すので、unit 側で用意する必要はない。
    # greeter を除くのは dms.nix の fcitx5 と同じ理由 (GDM の greeter も user unit を起動する)。
    systemd.user.services.niriswitcher = {
      description = "niriswitcher application switcher";
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      unitConfig.ConditionEnvironment = "!XDG_SESSION_CLASS=greeter";
      serviceConfig = {
        ExecStart = lib.getExe pkgs.niriswitcher;
        Restart = "on-failure";
      };
    };
  };
}
