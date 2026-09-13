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
# - hyprshell (Cmd+Tab): niri は同じものを内蔵の recent-windows で持つ (DMS の
#   dms/alttab.kdl が見た目だけ足す)。
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

    environment.systemPackages = [ place ];
  };
}
