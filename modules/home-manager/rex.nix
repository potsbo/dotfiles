# rex サーバを systemd user service で常駐させる (NixOS ホストのみ)。
# 無いと最初の rex コマンドがフラグ無しでサーバを自動起動し、Tailscale 無効・ノード名 rex
# の状態で立ち上がって他ホストから繋がらなくなる (`rex server tailscale on` / `rename` は
# 実行時だけの変更で、再起動で消える)。起動フラグをここで固定する。
# boot 時の起動に要る linger は modules/nixos/common.nix で有効化済み。
#
# graniteridge (manage = home の Linux) は対象外: OS を管理しておらず linger を保証できない。
{ lib, hosts, hostname, rex, ... }:

{
  imports = [ rex.homeManagerModules.default ];

  services.rex = lib.mkIf (hosts.${hostname}.os == "nixos" && hosts.${hostname}.manage == "system") {
    enable = true;
    tailscale = {
      enable = true;
      # 他ホストはこの名前 (<host>-rex.<tailnet>.ts.net) で繋ぐ。既定の rex だと
      # ホスト間で衝突するうえ、既存の接続先と食い違う。
      hostname = "${hostname}-rex";
    };
  };
}
