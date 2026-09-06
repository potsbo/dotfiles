{ config, lib, ... }:

# role = laptop (host.laptop): 電源管理を有効にし、適宜スリープする
{
  config = lib.mkIf config.host.laptop {
    services.upower.enable = lib.mkForce true;
  
    # lid を閉じたらサスペンドする
    services.logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "suspend";
      HandleLidSwitchDocked = "ignore";
    };
    };
}
