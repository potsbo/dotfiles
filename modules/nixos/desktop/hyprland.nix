# Hyprland + DankMaterialShell (DMS)。desktop.environment (modules/nixos/desktop.nix) が
# "hyprland" のときだけ有効で、GNOME (gnome.nix) と入れ替わる。hosts/phoenix の
# specialisation から選ぶ。
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
  };
}
