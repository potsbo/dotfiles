{ lib, ... }:

# 2TB NVMe 2本を 1つのプールとして扱う。設計の経緯と却下した案は
# notes の「NVMe 2本のストレージ構成」にある。ここには判断だけ残す。
#
# - LVM は「2本を 1本に見せる接着剤」としてだけ使う。ストライプ (RAID0) にしないのは
#   欲しかったのが速度ではなくプーリングだから。NVMe ではストライプの利得が小さく、
#   ストライプ LV は後からディスクを 1本足す運用と相性が悪い。
# - btrfs のマルチデバイスを使えば LVM は要らないが、disko が非対応
#   (mkfs 呼び出しが単一 device 前提)。宣言で作り直せることを優先して LVM を下に敷いた。
# - LV は 100% を 1本だけ。用途ごとに LV を切ると、XFS が縮小できず ext4 もオフライン
#   でしか縮まないので、渡した容量が戻らない。「合計では足りるのに使えない」という
#   今の不満が LV 単位で再発する。subvolume はサイズを持たないのでこれが起きない。
# - device を by-id で書くのは /dev/nvme0n1 と nvme1n1 が起動ごとに入れ替わり得るため。
#   destroy を繰り返す使い方では取り違えが致命的になる。
let
  # eui.* ではなく `nvme-<Model>_<Serial>` 形式のほうを使う (モデルが読めて取り違えにくい)。
  diskA = "/dev/disk/by-id/nvme-Seagate_FireCuda_530_ZP2000GM30013_7VR06WET";
  diskB = "/dev/disk/by-id/nvme-Seagate_FireCuda_530_ZP2000GM30013_7VR06X7F";
in
{
  disko.devices = {
    disk = {
      a = {
        type = "disk";
        device = diskA;
        content = {
          type = "gpt";
          partitions = {
            # ESP は a にしか置かない。冗長性は要件ではなく (データはクラウドが正)、
            # 2本に置くと systemd-boot の世代が分裂して同期を気にすることになる。
            # a が死んだら b だけでは起動しないが、その場合どのみち作り直す。
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "fmask=0077" "dmask=0077" ];
              };
            };
            pv = {
              size = "100%";
              content = { type = "lvm_pv"; vg = "pool"; };
            };
          };
        };
      };
      b = {
        type = "disk";
        device = diskB;
        content = {
          type = "gpt";
          partitions.pv = {
            size = "100%";
            content = { type = "lvm_pv"; vg = "pool"; };
          };
        };
      };
    };

    lvm_vg.pool = {
      type = "lvm_vg";
      lvs.main = {
        size = "100%FREE";
        content = {
          type = "btrfs";
          # csum は mkfs 時にしか決められず後から変更できないので、ここだけは
          # install 前に決め切る必要がある。既定の crc32c より xxhash のほうが
          # 最近の CPU では速く衝突耐性も高い。
          extraArgs = [ "-f" "--csum" "xxhash" ];

          # root を必ず subvolume の上に置く (フラットレイアウト)。トップレベル
          # (subvolid=5) に直接展開すると、後から subvolume を切り直すのに
          # 実質作り直しが必要になる。
          subvolumes = {
            "@root" = {
              mountpoint = "/";
              # 圧縮は最初のマウントから効かせる。後から有効にしても以降に書かれた
              # データにしか適用されず、既存分は defragment で書き直しになる。
              mountOptions = [ "compress=zstd:3" "noatime" ];
            };
            # VM イメージのような「大きいファイルへのランダム in-place 書き込み」は
            # CoW だと実消費が論理サイズを超えて膨らむ。その回避 (nodatacow) は
            # ここではなく configuration.nix の tmpfiles で chattr +C としてかける。
            #
            # ここに nodatacow を書いても効かない。btrfs は datacow と compress を
            # superblock 単位で持つので、同じファイルシステムの 2回目以降のマウントでは
            # マウントオプションが無視され、最初のマウント (/) の設定が勝つ。
            # VM テストで実測: disko は mount に -o nodatacow を渡しているのに、
            # 起動後の /var/lib/vm は compress=zstd:3 で nodatacow が消えていた。
            "@vm" = {
              mountpoint = "/var/lib/vm";
              mountOptions = [ "noatime" ];
            };
          };
        };
      };
    };
  };

  # swap は zram のみ (nix/../configuration.nix)。ディスク swap が要るようになったら
  # ここに専用 subvolume を足して `swap."swapfile".size = "64G"` を書けばよい。
  # disko が `btrfs filesystem mkswapfile` で作るので nodatacow は自動で付く。
  # subvolume の追加は後からできるので、今決めなくてよい。
}
