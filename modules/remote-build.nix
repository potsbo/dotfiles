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
  # builder 自身は委譲しない。nix は builder に空きがある限りローカルより remote を
  # 選ぶので、放っておくと raptorlake (28 コア) の build まで phoenix に飛ぶ。
  builders = lib.optionalAttrs (!isBuilder) (lib.filterAttrs (_: h: h ? builder) hosts);
in
{
  nix = {
    distributedBuilds = builders != { };
    buildMachines = lib.mapAttrsToList
      (name: h: {
        hostName = name;
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
