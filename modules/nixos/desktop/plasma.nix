# KDE Plasma 6。desktop.environment (modules/nixos/desktop.nix) が "plasma" の
# ときだけ有効になる。まずは specialisation で GNOME と並べて試す段階。
#
# GNOME 側 (gnome.nix) で拡張機能や dconf に頼っていたものは Plasma では次のとおり:
# - フォーカス中アプリの検出: xremap の withKDE (xremap.nix) が KWin スクリプトを
#   入れるので拡張機能は不要。
# - トレイアイコン (appindicator)、Vicinae: Plasma 標準で動くので拡張機能は不要。
# - Magnet 風の四分割 (Super+U/I/J/K): KWin に "Quick Tile Window to the Top Left"
#   等のアクションはあるが既定では未割り当て。kglobalshortcutsrc を宣言的に書く
#   仕組み (plasma-manager) はまだ入れていないので、試用中はシステム設定 >
#   ショートカット > KWin で手で割り当てる。Super+矢印の半分/最大化は既定で動く。
# - フォント・タッチパッド設定: 同じく試用中は GUI で設定する。採用が決まったら
#   plasma-manager を入れるか判断する。
{ config, pkgs, lib, ... }:
{
  config = lib.mkIf (config.host.desktop && config.desktop.environment == "plasma") {
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };
    services.desktopManager.plasma6.enable = true;
  };
}
