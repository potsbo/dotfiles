# rex サーバを systemd user service で常駐させる (Linux ホストのみ。macOS は Rex.app が
# サーバを持つので home-manager モジュール側が Linux 限定)。
# 無いと最初の rex コマンドがフラグ無しでサーバを自動起動し、Tailscale 無効・ノード名 rex
# の状態で立ち上がって他ホストから繋がらなくなる (`rex server tailscale on` / `rename` は
# 実行時だけの変更で、再起動で消える)。起動フラグをここで固定する。
#
# manage の別で分けない: manage = home のホスト (graniteridge) でも standalone home-manager が
# systemd user unit を書けるので、同じ設定が要る。差は linger だけ。
# - manage = system: modules/nixos/common.nix で linger を有効にしてあり、boot 時から常駐する。
# - manage = home:   linger は OS 側の状態で、共有マシンなので勝手には立てない。unit は
#   ログインで起動しログアウトで止まる。それでも「繋がらない既定値で上がる」のは防げる。
#   常駐させたくなったら本人が `loginctl enable-linger` を打つ (モジュールが activation で
#   同じ警告を出す)。
#
# 繋がるのは「ノード所有者の identity」からだけ (既定)。allowTailnetMembers は開けない:
# tailnet には社内の他アカウントのノードが並んでいる。この判定は tailscaled のノード側に
# かかるので、tag:server が付いたホスト (graniteridge) から他ホストの rex へは弾かれる
# ("tagged tailscale nodes are not the node owner identity")。所有者ノードである Mac 等から
# そのホストへ繋ぐ向きは通るので、用途 (手元の Mac からサーバの rex に入る) は満たせる。
#
# Tailscale ノードの初回 enroll はブラウザ認証が要る。auth key を repo に置けないので、
# 新しいホストでは一度 `rex server status` にログイン URL が出るのを踏む。
{ lib, hosts, hostname, rex, ... }:

{
  imports = [ rex.homeManagerModules.default ];

  config = lib.mkIf (hosts.${hostname}.os == "nixos") {
    services.rex = {
      enable = true;
      tailscale = {
        enable = true;
        # 他ホストはこの名前 (<host>-rex.<tailnet>.ts.net) で繋ぐ。既定の rex だと
        # ホスト間で衝突するうえ、既存の接続先と食い違う。
        hostname = "${hostname}-rex";
      };
    };

    # デスクトップホストではセッション起動が hm-session-vars.sh の include guard ごと環境を
    # systemd の user 環境に流す (経緯は home/.zshenv)。server がそれを継ぐと、配下の pane は
    # hm-session-vars を読まず、./install 後も再ログインまで古い値のままになる。気づきにくいので
    # server からだけ guard を落とす。home-manager の内部の名前なので、改名されたら空振りして
    # 再ログイン待ちに戻るだけで壊れはしない。
    systemd.user.services.rex.Service.UnsetEnvironment = [ "__HM_SESS_VARS_SOURCED" ];
  };
}
