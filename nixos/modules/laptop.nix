{ lib, ... }:

# ラップトップ用途: 電源管理を有効にし、適宜スリープする
{
  services.upower.enable = lib.mkForce true;
}
