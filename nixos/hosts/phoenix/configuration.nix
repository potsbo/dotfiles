{ config, pkgs, lib, ... }:
{
  imports = [
    ../../modules/common.nix
    ../../modules/server.nix
  ];

  networking.hostName = "phoenix";

  # 開発機なので未使用イメージ・volume も含めて毎週 prune する
  # (volume を消すのは phoenix 限定の判断。共通モジュールには入れない)
  virtualisation.docker.autoPrune = {
    enable = true;
    dates = "weekly";
    flags = [ "--all" "--volumes" ];
  };

  # RTL8125 の 2.5Gbps リンクが数十回/日フラップする (EEE off だけでは止まらず、
  # 1Gbps 固定で解消 → ケーブルかスイッチ側の 2.5G 信号品質の問題)。
  # 2.5G に戻したければケーブル交換 (Cat6 以上) してこの dispatcher を外す。
  #
  # udev の ACTION=="add" は起動時 1 回しか発火しない。フラップのたびに autoneg が
  # 2.5G+EEE の既定値へ戻り、以後 udev は再発火しないので設定が失われて再びフラップした
  # (実測: 効かなくなって 1 日 22 回フラップ)。NetworkManager dispatcher なら
  # リンクが up するたびに再適用されるので、フラップ後も 1G+EEE off を維持できる。
  networking.networkmanager.dispatcherScripts = [{
    type = "basic";
    source = pkgs.writeShellScript "enp2s0-pin-1g" ''
      iface="$1"; action="$2"
      [ "$iface" = "enp2s0" ] || exit 0
      case "$action" in up|connectivity-change) ;; *) exit 0 ;; esac
      ethtool="${pkgs.ethtool}/bin/ethtool"
      # 既に 1G + EEE off なら何もしない (再適用が余計なリンクリセットを起こさないため)
      need=0
      "$ethtool" enp2s0 | grep -q "Speed: 1000Mb/s" || need=1
      "$ethtool" --show-eee enp2s0 | grep -qw disabled || need=1
      [ "$need" = 0 ] && exit 0
      "$ethtool" --set-eee enp2s0 eee off || true
      "$ethtool" -s enp2s0 speed 1000 duplex full autoneg on || true
    '';
  }];

  # Thunderbolt Bridge: 対向 (10.0.0.1) への静的 IP
  networking.networkmanager.ensureProfiles.profiles.thunderbolt0 = {
    connection = {
      id = "thunderbolt0";
      type = "ethernet";
      interface-name = "thunderbolt0";
      autoconnect = "true";
    };
    ipv4 = {
      method = "manual";
      addresses = "10.0.0.2/24";
    };
    ipv6 = {
      method = "link-local";
    };
  };

  # ===========================================================================
  # ⚠ これは「いつか消すべき」設定です — 単なる歴史的経緯の暫定ピン
  # ===========================================================================
  #
  # nixpkgs 26.11 で services.dbus.implementation のデフォルトが dbus →
  # broker に変わった。dbus-broker が upstream/他ディストロの標準であり、
  # 本来は何も書かずデフォルトに従うのが正しい。ここで dbus を選び続けている
  # のは技術的な理由ではなく、単に「切り替えに再起動が要る」からだけ。
  #
  # NixOS は稼働中システムと新システムで D-Bus 実装が異なると switch を
  # 拒否する (system.switch.inhibitors.dbus-implementation)。生きたまま
  # dbus-daemon を dbus-broker に差し替えるのは危険なので妥当な挙動。
  # なので broker に移るには nixos-rebuild boot + 再起動が必須になる。
  #
  # phoenix は再起動が高リスク:
  #   - ディスプレイが 1 枚も繋がっておらず、起動に失敗しても systemd-boot の
  #     メニューで前世代を選べない (モニタとキーボードの物理接続が要る)
  #   - SSH の鍵は AuthorizedKeysCommand で毎回 github.com から取得しており、
  #     静的な authorized_keys が無い。名前解決か外向き通信が死ぬと sshd が
  #     正常でもログインできない
  #
  # このピンにより inhibitor が一致し、再起動なしで nixos-rebuild switch が
  # 通る = 26.11 への移行と再起動リスクを切り離せる。
  #
  # 消す条件: phoenix に物理アクセスできるタイミングを確保できたら、この
  # ブロックごと削除して nixos-rebuild boot + 再起動するだけ。上記 2 つの
  # 弱点 (モニタ無し / 鍵が外部依存) のどちらかを潰してからでも良い。
  # ===========================================================================
  services.dbus.implementation = "dbus";
}
