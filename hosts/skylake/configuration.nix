{ config, pkgs, lib, ... }:
{
  imports = [
    ../../modules/nixos/common.nix
    ../../modules/nixos/laptop.nix
  ];

  networking.hostName = "skylake";

  # サスペンドを s2idle にする。既定の deep (ACPI S3) だと、このマシン
  # (MacBook9,1 + Apple SSD AP0256J) は復帰時に NVMe が戻らず、`/` への書き込みが
  # 全部失敗して journald が "failed to write entry" を吐き続け、強制再起動が要る。
  # 2026-09-05 に 2 回起きた。journal の全履歴を見ても deep からの復帰が成功した
  # 記録 (PM: suspend exit) が一度もない。
  boot.kernelParams = [ "mem_sleep_default=s2idle" ];

  # RDP キオスク PoC。ブートメニューで "kiosk" を選んだときだけ有効になる。
  # 通常起動には影響しない。
  specialisation.kiosk.configuration = {
    imports = [ ../../modules/nixos/kiosk.nix ];
  };
}
