# ============================================================
# Cloudflare Access for Infrastructure 経由の SSH
#
# 手元の Mac で WARP を接続している間は tailnet への経路が通らない (macOS の既知の
# 非互換、tailscale/tailscale#5631)。graniteridge に WARP で入る運用になった
# ので、そのままこのホストにも届くように同じ経路を持つ。Tailscale は撤去しない。
# 干渉するのはクライアント側だけで、ホスト側では tailscaled と cloudflared が
# 普通に共存する (graniteridge で実証済み)。
#
# 構成は medicu-inc/one の computers/0008-graniteridge を写している。
# Cloudflare 側 (tunnel, route, infrastructure target, Access policy) は
# medicu-inc/one の terraform/main/cloudflare.tf にあり、ホスト側は
# 「トークンで cloudflared を run する」以外のことを知らない。
#
# 入れるのは本人 (potsbo) だけ。Access policy が email と Unix ユーザ名の対応を
# 1 本だけ持つ。Unix 側の名簿 (team.json 相当) は要らない。
# ============================================================
{ pkgs, ... }:

let
  # cloudflared が TUNNEL_TOKEN として読む。Nix store は world-readable なので
  # トークンはここに書かず、root 0600 で実機に置く。パスは graniteridge と揃える。
  envFile = "/srv/cloudflared/env";

  # WARP から届く宛先。graniteridge の 192.0.2.8 と同じ理由で RFC 5737 TEST-NET-1
  # を使う (WARP の split tunnel が既定で除外する RFC1918 / CGNAT に入らない)。
  # 末尾は会社の computers 台帳の番号 (0002-raptorlake)。
  # terraform 側の tunnel route と infrastructure target が同じアドレスを持つ。
  accessAddress = "192.0.2.2";
in
{
  # graniteridge は systemd-networkd で dummy を作るが、このホストは NetworkManager
  # なので NM のプロファイルとして持つ。networkd を併走させると同じ interface を
  # 2 つの管理者が見ることになる。
  networking.networkmanager.ensureProfiles.profiles.cfaccess = {
    connection = {
      id = "cfaccess";
      type = "dummy";
      interface-name = "cfaccess";
      autoconnect = true;
    };
    ipv4 = {
      method = "manual";
      addresses = "${accessAddress}/32";
    };
    ipv6.method = "disabled";
  };

  systemd.tmpfiles.rules = [
    "d /srv/cloudflared 0700 root root -"
  ];

  # NixOS 標準の services.cloudflared は credentials JSON とローカルの ingress を
  # 要求するので、ingress を Cloudflare 側に持つ remotely-managed tunnel には
  # 合わない。ここだけ自作 unit にしている。
  systemd.services.cloudflared = {
    description = "Cloudflare Tunnel connector";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig = {
      # トークンが置かれるまで起動しない。設定を先に反映しても rebuild が通る
      ConditionPathExists = envFile;
      # トークン失効などの恒常的な失敗でも諦めさせない。入口が消えたままになるより
      # 10 秒ごとに試み続けて復旧に自動で追従する方がよい
      StartLimitIntervalSec = 0;
    };
    serviceConfig = {
      EnvironmentFile = envFile;
      Restart = "always";
      RestartSec = "10s";
      # --no-autoupdate: バイナリは Nix が持つ。store は read-only で自己更新できない
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared --no-autoupdate tunnel run";
      # outbound の接続と ${accessAddress}:22 への proxy しかしないので特権が要らない
      DynamicUser = true;
    };
  };

  # Access はクライアントの鍵をサーバまで運ばない。ログインをもとに Cloudflare が
  # 短命証明書を発行し、それで sshd に再認証する。CA は Cloudflare アカウント単位
  # なので graniteridge と同じ鍵。
  environment.etc."ssh/cloudflare-ca.pub" = {
    mode = "0444";
    text = ''
      ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBE5k93zapQrW9mTITH3AaD8G72ffrrk3uxLYGTX6pPtiBGPHz1/EIC2kW0O8yK80AOlMzmr63Wd0L3NjbQ1D0N0= open-ssh-ca@cloudflareaccess.org
    '';
  };
  # common.nix の AuthorizedKeysCommand (GitHub 鍵) はそのまま。tailnet からは
  # 従来どおり GitHub 鍵で入る。sshd は CA を AuthorizedKeysCommand より先に見るので、
  # この経路は GitHub への到達性に依存しない。
  services.openssh.settings.TrustedUserCAKeys = "/etc/ssh/cloudflare-ca.pub";
}
