{ pkgs, ... }:

{
  networking.networkmanager.enable = true;

  services.resolved = {
    enable = true;
    settings.Resolve.LLMNR = "true";
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    extraUpFlags = [];
  };

  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # --- ネットワーク自己修復 watchdog ---
  # 見るのはデフォルトルートだけ。Tailscale の node key 失効のように「経路は生きて
  # いるが到達できない」障害は検知できない (2026-07-30 に取り逃がした実績あり)。
  #
  # デフォルトルートが消えたら NetworkManager を叩き直し、
  # それでも 30 分回復しなければ最終手段として再起動する。
  # (再起動すれば必ず到達可能な状態に戻る = 物理アクセス不要の保険)
  # ISP 障害ではデフォルトルート自体は残るので、誤発動で再起動ループにはならない。
  systemd.services.network-watchdog = {
    description = "Restart NetworkManager (and eventually reboot) if default route is lost";
    serviceConfig.Type = "oneshot";
    path = [ pkgs.iproute2 ];
    script = ''
      state=/run/network-watchdog-down-since
      if ip route show default | grep -q .; then
        rm -f "$state"
        exit 0
      fi
      now=$(date +%s)
      if [ ! -f "$state" ]; then
        echo "$now" > "$state"
      fi
      echo "no default route; kicking NetworkManager"
      systemctl reset-failed NetworkManager.service 2>/dev/null || true
      systemctl restart NetworkManager.service || true
      first=$(cat "$state")
      if [ "$((now - first))" -gt 1800 ]; then
        echo "no default route for 30+ minutes; rebooting as last resort"
        systemctl reboot
      fi
    '';
  };
  systemd.timers.network-watchdog = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "2min";
    };
  };
}
