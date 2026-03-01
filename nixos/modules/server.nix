{ lib, ... }:

# 常時稼働サーバ用途: suspend/sleep を完全に無効化
{
  services.displayManager.gdm.autoSuspend = false;

  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };

  services.logind.settings.Login = {
    HandleSuspendKey = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandleHibernateKey = "ignore";
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    IdleAction = "ignore";
  };

  powerManagement.enable = false;

  # GNOME の自動サスペンドも無効化
  # (systemd 側とは別に gsd-power が独自にサスペンドを発動するのを防ぐ)
  programs.dconf.profiles.user.databases = [{
    settings."org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-type = "nothing";
      sleep-inactive-battery-type = "nothing";
    };
  }];
}
