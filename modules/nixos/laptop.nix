{ lib, ... }:

# ラップトップ用途: 電源管理を有効にし、適宜スリープする
{
  services.upower.enable = lib.mkForce true;

  # Asahi Linux (Apple Silicon) では Apple SMC の lid switch デバイスに
  # power-switch タグが付かず logind が認識しないため、udev ルールで補う
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="input", ATTRS{name}=="Apple SMC power/lid events", TAG+="power-switch"
  '';

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
}
