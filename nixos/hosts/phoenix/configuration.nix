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

  # 古い worktree の週次 GC (クリーン & push 済み & 30日超のみ削除)
  systemd.user.services.worktree-gc = {
    description = "GC old git worktrees";
    path = [ pkgs.git pkgs.openssh ];
    serviceConfig.Type = "oneshot";
    script = ''exec "$HOME"/src/github.com/potsbo/dotfiles/script/worktree-gc.sh'';
  };
  systemd.user.timers.worktree-gc = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };

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
