{ config, pkgs, lib, ... }:
{
  imports = [
    ../../modules/nixos/common.nix
    ../../modules/nixos/server.nix
  ];

  networking.hostName = "phoenix";

  # 開発機なので未使用イメージ・volume も含めて毎週 prune する
  # (volume を消すのは phoenix 限定の判断。共通モジュールには入れない)
  virtualisation.docker.autoPrune = {
    enable = true;
    dates = "weekly";
    flags = [ "--all" "--volumes" ];
  };

  # 症状は「SSH が頻繁にストールする」として現れる。リンクが落ちるたびに tailscaled が
  # rebind し、直結経路が DERP 経由へフォールバックするため。原因は Tailscale ではない。
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

  # RDP 越しの GNOME セッションで使う端末。設定は symlink 済みの
  # home/.config/ghostty/config をそのまま共有する。
  # common.nix (全 NixOS ホスト) には入れていない: 現状 GUI を日常的に触るのは
  # phoenix だけで、必要になったホストから足す方が安い。
  environment.systemPackages = [
    pkgs.ghostty
    # macOS 側は cask (darwin-apps.nix)。notes リポジトリ (notes-sync.nix) を
    # phoenix の GUI セッションでも直接開くため。
    pkgs.obsidian
  ];
}
