# raptorlake

## Windows 11 Pro VM

ホスト側の設定 (libvirtd / swtpm / virtio-win ISO / VM 置き場) は
`configuration.nix` にある。ここに書くのは、宣言で表せない一度きりの手順。

VM の定義そのものを nix で宣言していないのは、Windows のインストールが
本質的に対話的で、できあがった domain XML (ゲスト側で入れたドライバや
ライセンス認証と対になる状態) をリポジトリで再生成しても意味がないため。
domain の定義は libvirt が `/var/lib/libvirt/qemu/win11.xml` に持つ。

### 1. Windows 11 の ISO を置く

microsoft.com の ISO ダウンロードはブラウザのセッション前提なので、
[Fido](https://github.com/pbatard/Fido) で直リンクを取る。Linux の pwsh では
2 箇所パッチが要る (CPU アーキ検出の `Get-CimInstance`、`$winver` の
プラットフォーム判定)。

```sh
curl -fsSLO https://raw.githubusercontent.com/pbatard/Fido/master/Fido.ps1
perl -0pi -e 's/(function Get-Arch\n\{\n)/$1\treturn "x64"\n/' Fido.ps1
sed -i 's/^\$winver = Get-Platform-Version/$winver = 10.0/' Fido.ps1
nix run nixpkgs#powershell -- -NoProfile -File ./Fido.ps1 \
  -Win 11 -Rel Latest -Ed Pro -Lang English -Arch x64 -GetUrl
```

出てきた URL を `sudo curl -fL -o /var/lib/vm/Win11_<rel>_English_x64.iso ...`
で落とす。URL は 24 時間で失効する。短時間に何度も叩くと MS 側に
`Sentinel marked this request as rejected` で弾かれるので、取れた URL は使い回す。

ISO を `/var/lib/vm` に置くのは、ここが nodatacow の subvolume で、
数 GB のファイルを圧縮もチェックサムもせずに置けるから。

### 2. VM を作る

```sh
sudo virt-install \
  --connect qemu:///system \
  --name win11 \
  --osinfo win11 \
  --vcpus 4 \
  --memory 8192 \
  --cpu host-passthrough \
  --machine q35 \
  --boot firmware=efi,firmware.feature0.name=secure-boot,firmware.feature0.enabled=yes,loader.secure=yes \
  --tpm model=tpm-crb,backend.type=emulator,backend.version=2.0 \
  --disk path=/var/lib/vm/win11.qcow2,size=1024,format=qcow2,bus=virtio,cache=none,discard=unmap \
  --disk device=cdrom,path=/var/lib/vm/Win11_25H2_English_x64.iso,boot.order=1 \
  --disk device=cdrom,path=/var/lib/vm/virtio-win.iso \
  --network network=default,model=virtio \
  --graphics vnc,listen=127.0.0.1 \
  --video qxl \
  --noautoconsole
```

- `size=1024` (GiB) は qcow2 の論理サイズ。sparse なので実消費は書いた分だけ。
  あとで増やすのは `qemu-img resize` + Windows のディスクの管理で拡張、で済むが、
  縮小はイメージを作り直すことになるので最初から大きく取る。
- vCPU とメモリは VM を停止すれば `virsh setvcpus/setmaxmem --config` で変えられる。
- nvram (UEFI 変数) だけは libvirt が `/var/lib/libvirt/qemu/nvram/` に置く。
  128KB なので `/var/lib/vm` に寄せる価値はない。
- VNC を 127.0.0.1 に縛っているのは、認証なしの VNC を tailnet にすら
  出さないため。インストール中しか使わないので ssh のトンネルで足りる。

### 3. コンソールに繋いでインストールする

Mac から:

```sh
ssh -L 5900:127.0.0.1:5900 raptorlake   # 実際の port は virsh vncdisplay win11
```

で `vnc://localhost:5900` を macOS の画面共有 (Screen Sharing) で開く。
raptorlake のデスクトップに座っているなら `virt-manager` でよい。

インストーラでの注意:

- "Press any key to boot from CD or DVD" のタイムアウトは数秒しかない。逃すと
  `BdsDxe: No bootable option or device was found` で止まるので、
  `sudo virsh reset win11` の直後に `sudo virsh send-key win11 KEY_ENTER` を
  連打すればよい (VNC を繋ぐ前でも入る)。

- ディスクが出てこない → 「ドライバーの読み込み」で 2 台目の CD-ROM の
  `amd64\w11\viostor.inf` を選ぶ。ネットワークも同様に `NetKVM\w11\amd64`。
- Microsoft アカウントを避けたい場合は OOBE で `Shift+F10` → `start ms-cxh:localonly`。

### 4. インストール後

```sh
sudo virsh change-media win11 sda --eject       # インストール ISO を外す (device 名は domblklist で確認)
sudo virsh autostart win11                      # ホスト起動時に上げる
```

ゲスト側で:

- virtio-win ISO の `virtio-win-guest-tools.exe` を実行 (残りのドライバ + qemu-ga)。
- Tailscale を入れる。これでゲストが固有の tailnet IP を持つので、
  ホスト側の port 転送なしに Mac の Windows App から RDP できる
  (設定 → システム → リモートデスクトップ を有効化)。
