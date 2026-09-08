# nix の distributed builds。flake.nix の hosts で builder を持つホストへ、他ホストの
# build を委譲する。NixOS と nix-darwin の両方で同じオプション名なので共有モジュール。
#
# 使う鍵は新しく作らず、ユーザーの ~/.ssh/id_ed25519 を root (nix-daemon) にも読ませる。
# builder 側の sshd は GitHub の公開鍵だけを受ける (modules/nixos/sshd.nix) ので、
# root 専用の鍵を作ると GitHub に登録するか静的 authorized_keys を置くかになり、
# 「GitHub で消したら即締め出し」の方針から外れる。鍵にパスフレーズが無いことが前提。
#
# builder 側でユーザーを trusted-users に入れるのは、client が署名の無い store path を
# 送り込むのに要るから。wheel で NOPASSWD sudo なので権限としては増えていない。
{ lib, config, user, hosts, hostname, ... }:

let
  isBuilder = hosts.${hostname} ? builder;
  # 委譲先は「自分より speedFactor の大きい builder」だけ。builder 同士は一方通行に
  # したい (raptorlake の build が phoenix に飛んだり、互いに投げ合ったりしない) ので、
  # speedFactor を優先順位としても使う。builder でないホストは 0 扱いで全 builder に出す。
  mySpeed = hosts.${hostname}.builder.speedFactor or 0;
  builders = lib.filterAttrs (_: h: h ? builder && h.builder.speedFactor > mySpeed) hosts;
in
{
  nix = {
    distributedBuilds = builders != { };
    buildMachines = lib.mapAttrsToList
      (name: h: {
        # ?compress=true は ssh に -C を付けさせる (ssh-ng の既定は無圧縮)。ここを通るのは
        # build 出力の NAR で、ソースツリーやバイナリなので圧縮がよく効く。herdr の
        # zig cache (486 MiB) は gzip -6 で 120 MiB、24.6% になった。NixOS module に
        # 専用オプションが無いので store URI の query として hostName に混ぜている
        # (URI は "${protocol}://${sshUser}@${hostName}" で組まれる)。
        hostName = "${name}?compress=true";
        inherit (h) system;
        inherit (h.builder) maxJobs speedFactor;
        sshUser = user;
        sshKey = "${config.users.users.${user}.home}/.ssh/id_ed25519";
        protocol = "ssh-ng";
        supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
      })
      builders;
    settings = {
      # builder に無い依存は client 経由で送らず builder が直接 cache から取る。
      builders-use-substitutes = true;
      trusted-users = lib.mkIf isBuilder [ user ];
    };
  };

  # nix-daemon は root として ssh するので、ユーザーの known_hosts は使えない。
  programs.ssh.knownHosts = lib.mapAttrs (_: h: { publicKey = h.sshHostKey; }) builders;
}
