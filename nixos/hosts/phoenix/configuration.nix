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
  # 2.5G に戻したければケーブル交換 (Cat6 以上) してこの rule を外す。
  # EEE は NetworkManager にも systemd.link にも設定項目がないので udev で ethtool を叩く
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="net", KERNEL=="enp2s0", RUN+="${pkgs.ethtool}/bin/ethtool --set-eee enp2s0 eee off", RUN+="${pkgs.ethtool}/bin/ethtool -s enp2s0 speed 1000 duplex full autoneg on"
  '';

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
}
