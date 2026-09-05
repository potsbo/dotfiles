{ config, pkgs, lib, ... }:
{
  imports = [
    ../../modules/nixos/common.nix
    # オフィス据え置きで、家から Tailscale 越しに使う。サスペンドされると
    # 到達できなくなるので laptop ではなく server 扱いにする。
    # WARP 接続中の Mac から入るための Cloudflare 経路 (Tailscale と併存)
    ./cloudflare-access.nix
  ];

  networking.hostName = "raptorlake";

  # GeForce RTX 4070 (Ada)。Ada 以降は open kernel module が NVIDIA 推奨で、
  # proprietary module より kernel 更新への追従が速い。
  # headless (host.desktop = false) だが、ollama の CUDA にドライバが要る。videoDrivers は
  # X 用の名前だが、NixOS では nvidia ドライバを有効にする入口がこれしかない。
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    open = true;
  };

  # ローカル LLM。llama.cpp を直に叩くより数% 遅いが、モデルの取得・切り替え・
  # アイドル時のアンロードまで標準 module が面倒を見る。
  #
  # package を明示するのは、既定の `ollama` が nixpkgs.config.cudaSupport を見て
  # 中身を決めるため。そのフラグはシステム全体に効き、CUDA 込みの再ビルドを
  # 引き起こす。CUDA が要るのはここだけなので、パッケージ側で差す。
  #
  # 127.0.0.1 のまま tailnet には出していない。ollama の API には認証がなく、
  # 出した瞬間に tailnet の全ノードからモデルの実行と削除ができる。
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    # VRAM 12GB に対する上下の当たりを取るための 2本。Q4_K_M で 14B (~9GB) が
    # 全層 GPU に載る上限で、8B (~5GB) は長いコンテキストでも KV cache が
    # 溢れない基準値。ここを超えると CPU オフロードが混ざり、測っているものが
    # GPU の性能ではなくなる。
    loadModels = [ "qwen3:8b" "qwen3:14b" ];
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

  # libvirt の NSS モジュール。ゲストを名前で解決できるようにする (fileSystems が依存)。
  #
  # mkBefore で systemd-resolved (`resolve [!UNAVAIL=return]`) より前に置く。既定の
  # 順序では resolved が「見つからない」と答えた時点で探索が打ち切られ、後ろに
  # 並べても永久に引かれない。
  #
  # 引くのは libvirt の domain 名であって、ゲストが DHCP で申告する hostname では
  # ない。同じ綴りだが解決経路が違う。ゲスト側の名前は Tailscale の MagicDNS も
  # 応答するので、libvirt を前に置いていなければ SMB が tailnet 経由になる。
  # ホストとゲストは NAT (virbr0) で直結しているのだから、そこを通す必然性がない。
  # 逆に言うと、ホスト上では tailnet 名より NAT 側の IP が優先される。
  system.nssModules = [ pkgs.libvirt ];
  system.nssDatabases.hosts = lib.mkBefore [ "libvirt" "libvirt_guest" ];

  # virt-manager (GUI) は入れない。VM の操作は virsh か、別マシンの virt-manager から
  # qemu+ssh://raptorlake/system で繋ぐ。
  users.users.potsbo.extraGroups = [ "libvirtd" ];

  # Google の共有ドライブを Linux から読むための経路。共有ドライブは Drive for
  # Desktop がストリーミング固定で扱う (ミラーできるのはマイドライブだけ) ので、
  # ローカル実体を持てない。ゲストの G: を SMB で出し、ここから読み抜く。
  #
  # ホスト側にコピーを持つ案 (robocopy + スナップショット) は却下した。あれは
  # 「同期が完了するまで待つ」というゲートを作る。実際の運用は「アップロード完了の
  # 連絡を受けたらすぐ処理を始める」なので、待たされるのは処理の前ではなく処理中で
  # ないと困る。読み抜きなら転送は処理に混ざり、古いコピーを掴む余地も無い。
  #
  # 相手は IP ではなく libvirt の domain 名で引く。IP を書くと、それを固定している
  # DHCP 予約 (libvirt 側の状態でリポジトリには入らない) が失われた瞬間に、
  # 気づけない形でマウントが壊れる。domain 名はこちらが付けた名前なので、
  # ゲストの hostname が変わっても影響を受けない。
  #
  # 資格情報はリポジトリに置けないので、root だけが読める /etc/smb-credentials/gdrive
  # (username= と password= の 2 行) を参照する。ホスト再インストール時は手で作る。
  # マウント先は /srv/<VM 名>/<共有名>。橋渡しの VM が増えても同じ形で並ぶ。
  #
  # 共有しているのはゲストのユーザープロファイル 1 つきり。Drive のマウント先を
  # その配下 (~/gdrive/<アカウント>) に置いてあるので、Google アカウントが増えても
  # Windows でフォルダを 1 つ足すだけで、ここは触らなくてよい。
  #
  # ドライブレターを共有していたときは、再起動のたびに共有定義ごと消えた。
  # LanmanServer は起動時に実在しないパスを指す共有を削除するが、Drive の
  # ドライブレターはサインイン後にしか生えないため必ずこれに当たる。
  # 常に実在するフォルダを共有することでこれを回避している。
  #
  # 共有ドライブ名や施設名を共有名に使わないのは、ここが公開リポジトリで、
  # その情報を載せる必然性がないから。
  fileSystems."/srv/raptorlake-win/shimp" = {
    device = "//raptorlake-win/shimp";
    fsType = "cifs";
    options = [
      "credentials=/etc/smb-credentials/gdrive"
      # 書き戻す用途はない。読み取り専用にしておけば、バッチの事故が
      # 共有ドライブに波及しない。
      "ro"
      "uid=1000" "gid=100" "iocharset=utf8" "vers=3.1.1"
      # Drive for Desktop の仮想 FS は一意な inode 番号を返さないので、
      # serverino のままだと readdir が EINVAL で落ちる (ls が Invalid argument)。
      "noserverino"
      # VM が落ちていてもホストの boot を止めない。最初にアクセスした時点で
      # mount し、使わなくなれば外れる。
      "nofail" "x-systemd.automount" "x-systemd.idle-timeout=600"
      "x-systemd.mount-timeout=30s" "_netdev"
    ];
  };

  # docker の storage-driver は指定していない。btrfs 上では btrfs graph driver が
  # 選ばれることを警戒していたが、common.nix の containerd-snapshotter によって
  # overlayfs snapshotter になることを VM で実測した
  # (`Storage Driver: overlayfs`, `containerd-snapshotter=true`)。
}
