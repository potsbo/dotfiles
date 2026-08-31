# nixos-generate-config の出力ではなく手で書いている。ディスク周り
# (fileSystems / swapDevices) は disko が ./disk-config.nix から導出するので、
# ここに残るのはカーネルモジュールと CPU 由来の設定だけ。
#
# 手で書くのは、生成物を実機からコピーして commit する往復を挟まずに
# 最初から pure な flake として install するため (--impure が要らない)。
# 実機で足りないモジュールが判明したらここに足す。
{ config, lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;
}
