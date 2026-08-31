{ config, pkgs, lib, ... }:
{
  imports = [
    ../../modules/common.nix
    # オフィス据え置きで、家から Tailscale 越しに使う。サスペンドされると
    # 到達できなくなるので laptop ではなく server 扱いにする。
    ../../modules/server.nix
  ];

  networking.hostName = "raptorlake";

  # GeForce RTX 4070 (Ada)。Ada 以降は open kernel module が NVIDIA 推奨で、
  # proprietary module より kernel 更新への追従が速い。
  # modesetting は Wayland (GDM/GNOME) に必須。
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    open = true;
    modesetting.enable = true;
    nvidiaSettings = true;
  };

  # swap はディスクに置かず zram のみ。btrfs 上の swapfile は専用の nodatacow
  # subvolume が要るうえ、プールから容量を固定的に取る。メモリ不足の実害が出たら
  # disk-config.nix に swap subvolume を足す (disko が mkswapfile で作る)。
  zramSwap.enable = true;

  # 冗長性がないのでチェックサム不一致は自動修復されないが、どのファイルが
  # 壊れたかは分かる。壊れたものはクラウドから取り直す。
  #
  # fileSystems を明示するのは、既定だと btrfs な fileSystems を全部拾って
  # / と /var/lib/vm の 2本ぶんの timer が立つため。実体は同じデバイスなので
  # 同じものを 2回 scrub することになる。
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };

  # VM イメージ置き場を nodatacow にする。CoW のままだと、大きいファイルへの
  # ランダム in-place 書き込みでエクステントが解放されず実消費が論理サイズを超える。
  #
  # subvolume のマウントオプションではこれができない (disk-config.nix の @vm を見よ)。
  # 属性は空のディレクトリに先に付ける必要があり、既存ファイルには後付けできないので、
  # イメージを置く前に必ず通る tmpfiles でかける。+C は CoW と一緒に圧縮と
  # チェックサムも切るが、VM イメージにはどれも惜しくない。
  systemd.tmpfiles.rules = [ "h /var/lib/vm - - - - +C" ];

  # docker の storage-driver は指定していない。btrfs 上では btrfs graph driver が
  # 選ばれることを警戒していたが、common.nix の containerd-snapshotter によって
  # overlayfs snapshotter になることを VM で実測した
  # (`Storage Driver: overlayfs`, `containerd-snapshotter=true`)。
}
