{ config, lib, ... }:

# ラップトップ (host.laptop): 電源管理を有効にし、適宜スリープする
{
  config = lib.mkIf config.host.laptop {
    services.upower.enable = lib.mkForce true;
  
    # lid を閉じたらサスペンドする
    services.logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "suspend";
      HandleLidSwitchDocked = "ignore";
    };
  
    # GNOME の gsd-power が logind の lid switch を inhibit するため、
    # GNOME 側でも lid close 時にサスペンドするよう設定する
    programs.dconf.profiles.user.databases = [{
      settings."org/gnome/settings-daemon/plugins/power" = {
        lid-close-ac-action = "suspend";
        lid-close-battery-action = "suspend";
      };
    }];
  };
}
