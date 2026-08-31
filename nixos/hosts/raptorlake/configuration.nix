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
  systemd.tmpfiles.rules = [
    "h /var/lib/vm - - - - +C"
    # Windows のインストーラは virtio の disk/NIC を認識しないので、ドライバ ISO を
    # 2 台目の CD-ROM として食わせる。pkgs.virtio-win 本体は展開済みのドライバツリー
    # なので、CD-ROM に渡せる ISO はその src のほう。
    # リンクにしておけば、ISO の版が上がってもパスを書き直さなくてよい。
    "L+ /var/lib/vm/virtio-win.iso - - - - ${pkgs.virtio-win.src}"
  ];

  # Windows 11 Pro の VM をここで動かす。ディスクは /var/lib/vm (上の +C) に置く。
  #
  # ゲストを tailnet に入れる前提にしていて、ホスト側で RDP の 3389 を転送していない。
  # ゲストに Tailscale を入れれば固有の tailnet IP が付き、ホストの firewall と
  # NAT hairpin を触らずに Mac の Windows App から届く。DNAT を足すと libvirt の
  # NAT ネットワークと firewall の両方にゲスト固有の設定が生えて、VM を作り直す
  # たびに追随が要る。
  virtualisation.libvirtd = {
    enable = true;
    # ホスト再起動でゲストを managed save しない。保存先は /var/lib/libvirt/qemu/save
    # で @vm の外 = CoW のまま、しかもゲストのメモリ全量が毎回書かれる。
    # Windows は素直に shutdown させ、起動は domain 側の autostart に任せる。
    onShutdown = "shutdown";
    qemu = {
      # Windows 11 のインストーラは TPM 2.0 と UEFI Secure Boot を要求する。
      swtpm.enable = true;
      # OVMF (Secure Boot 対応版を含む) は QEMU に同梱されるようになったので、
      # ovmf の指定は要らない (nixpkgs で submodule ごと削除された)。
    };
  };
  programs.virt-manager.enable = true;
  users.users.potsbo.extraGroups = [ "libvirtd" ];

  # docker の storage-driver は指定していない。btrfs 上では btrfs graph driver が
  # 選ばれることを警戒していたが、common.nix の containerd-snapshotter によって
  # overlayfs snapshotter になることを VM で実測した
  # (`Storage Driver: overlayfs`, `containerd-snapshotter=true`)。
}
