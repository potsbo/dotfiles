{ config, lib, ... }:

# role = workstation / server (host.alwaysOn): suspend/sleep を完全に無効化
{
  config = lib.mkIf config.host.alwaysOn {
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
    };
}
