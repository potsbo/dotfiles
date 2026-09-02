# raptorlake

## Windows 11 Pro VM

ホスト側の設定 (libvirtd / swtpm / virtio-win ISO / VM 置き場) は
`configuration.nix` にある。ここに書くのは、宣言で表せない一度きりの手順。

VM の定義そのものを nix で宣言していないのは、Windows のインストールが
本質的に対話的で、できあがった domain XML (ゲスト側で入れたドライバや
ライセンス認証と対になる状態) をリポジトリで再生成しても意味がないため。
domain の定義は libvirt が `/var/lib/libvirt/qemu/raptorlake-win.xml` に持つ。

**domain を作り直さないこと。** Windows のデジタルライセンスは VM の
「ハードウェア構成」(domain UUID, machine type, CPU モデル) に紐づく。
`undefine` して `virt-install` し直すと UUID が変わって認証が外れる。
設定を変えるときは既存の domain を `virsh edit` / `virsh update-device` で編集する。

### 1. Windows 11 の ISO を置く

microsoft.com の ISO ダウンロードはブラウザのセッション前提。
[Fido](https://github.com/pbatard/Fido) で直リンクを取れるが、**同じ IP から
続けて叩くと `Sentinel marked this request as rejected` で弾かれる** (実際に
1 回目は通り、2 回目以降はその日のうちは通らなかった)。ブラウザから普通に
ページを開いてリンクをコピーするほうが確実で、弾かれたときはテザリング等で
IP を変えれば取れる。

Fido を使う場合、Linux の pwsh では 2 箇所パッチが要る:

```sh
curl -fsSLO https://raw.githubusercontent.com/pbatard/Fido/master/Fido.ps1
perl -0pi -e 's/(function Get-Arch\n\{\n)/$1\treturn "x64"\n/' Fido.ps1
sed -i 's/^\$winver = Get-Platform-Version/$winver = 10.0/' Fido.ps1
nix run nixpkgs#powershell -- -NoProfile -File ./Fido.ps1 \
  -Win 11 -Rel Latest -Ed Pro -Lang Japanese -Arch x64 -GetUrl
```

得た URL を `sudo curl -fL -o /var/lib/vm/Win11_<rel>_Japanese_x64.iso ...` で落とす
(URL は 24 時間有効、8GB 弱)。

ISO を `/var/lib/vm` に置くのは、ここが nodatacow の subvolume で、
数 GB のファイルを圧縮もチェックサムもせずに置けるから。

### 2. VM を作る

```sh
sudo virt-install \
  --connect qemu:///system \
  --name raptorlake-win \
  --osinfo win11 \
  --vcpus 4 \
  --memory 8192 \
  --cpu host-passthrough \
  --machine q35 \
  --boot firmware=efi,firmware.feature0.name=secure-boot,firmware.feature0.enabled=yes,loader.secure=yes \
  --tpm model=tpm-crb,backend.type=emulator,backend.version=2.0 \
  --disk path=/var/lib/vm/raptorlake-win.qcow2,size=1024,format=qcow2,bus=virtio,cache=none,discard=unmap \
  --disk device=cdrom,path=/var/lib/vm/Win11_25H2_Japanese_x64.iso,boot.order=1 \
  --disk device=cdrom,path=/var/lib/vm/virtio-win.iso \
  --network network=default,model=virtio \
  --channel type=unix,target.type=virtio,target.name=org.qemu.guest_agent.0 \
  --graphics vnc,listen=127.0.0.1,passwd=<8文字> \
  --video qxl \
  --noautoconsole
```

- **ディスクサイズはここで大きく取る。** qcow2 は sparse なので論理サイズを
  大きくしても実消費は書き込んだぶんだけ (1TB の image が 161MB だった)。
  一方あとから C: を伸ばすのは面倒で、Windows のセットアップが回復
  パーティションを C: の後ろに作るため、増えた領域が C: と連続しない。
  伸ばすには `reagentc /disable` → 回復パーティション削除 → 拡張 → 再作成 →
  `reagentc /enable` の手術が要る。容量が足りなくなったら、C: を伸ばすより
  2 台目のディスクを `virsh attach-disk --live` で足すほうが速い。
  ディスク自体の拡張は稼働中にできる (`virsh blockresize raptorlake-win --path vda --size 2T`)。
- このホストのイメージは `win11.qcow2` のまま。domain は後から `raptorlake-win` に
  リネームしたが、ファイル名は追随させていない (実害がなく、改名には停止が要るため)。
- vCPU とメモリは VM を停止すれば `virsh setvcpus/setmaxmem --config` で変えられる
  (ホットプラグ用の枠は取っていない)。
- nvram (UEFI 変数) だけは libvirt が `/var/lib/libvirt/qemu/nvram/` に置く。
  128KB なので `/var/lib/vm` に寄せる価値はない。
- **`--channel` を忘れないこと。** これがないとゲストエージェントとの経路が無く、
  `virsh shutdown` が ACPI にフォールバックする。ACPI はウィンドウが開いていると
  無視されることがあり (実際に効かなかった)、ホスト停止時にゲストが
  タイムアウト後に強制切断される。しかも後から足すには virtio-serial
  コントローラごと必要で、コントローラはホットプラグできないので VM の停止が要る。
- **VNC にパスワードを付けるのは macOS の画面共有のため。** 認証なしの VNC には
  繋いでくれない。QEMU は起動時にパスワード認証を有効にしていないと後から
  付けられない (`set_password` が `VNC password authentication is disabled` で失敗する)
  ので、最初から付けておく。
- listen を 127.0.0.1 に縛るのは、8 文字 DES の VNC 認証を tailnet にすら
  出さないため。実際の防御は ssh の鍵認証が担う。

### 3. コンソールに繋いでインストールする

Mac から:

```sh
ssh -L 15900:127.0.0.1:5900 raptorlake
open vnc://localhost:15900
```

**転送先のローカルポートを 5900 以外にすること。** macOS の画面共有は接続先が
ローカルアドレス かつ 5900 番だと「You cannot control your own screen.」で
弾く。127.0.0.2 のエイリアスを作る手は同じチェックに引っかかる (全ローカル
インターフェースを見ている) が、ポートをずらせば通る。

raptorlake のデスクトップに座れるなら `virt-manager` でよいが、この機械は
モニタを繋がない運用なので、実質この経路が唯一のコンソールになる。

インストーラでの注意:

- "Press any key to boot from CD or DVD" のタイムアウトは数秒しかない。逃すと
  `BdsDxe: No bootable option or device was found` で止まるので、
  `sudo virsh reset raptorlake-win` の直後に `sudo virsh send-key raptorlake-win KEY_ENTER` を
  連打すればよい (VNC を繋ぐ前でも入る)。
- **ディスクが 1 台も出てこない**。virtio のストレージドライバが標準に無いため。
  「ドライバーの読み込み」→ 参照 → virtio-win の CD の `viostor\w11\amd64` を選ぶ
  (同じものが `amd64\w11` にもあるので、候補が 2 つ並ぶ。どちらでもよい)。
- 未割り当て領域はそのまま「次へ」でよい。ESP / MSR / 回復 / C: を Windows が作る。
- **OOBE のネットワーク画面でアダプタが出てこない**。NetKVM も同様に標準に無い。
  `Shift+F10` → `devmgmt.msc` → 「イーサネット コントローラー」→ ドライバーの更新 →
  CD の `NetKVM\w11\amd64`。入ったかはホスト側から
  `sudo virsh net-dhcp-leases default` で lease を見れば分かる。
- ネットワークを繋がずローカルアカウントで進めたい場合は `Shift+F10` →
  `start ms-cxh:localonly`。

### 4. インストール後

ホスト側:

```sh
sudo virsh change-media raptorlake-win sda --eject --live --config   # インストール ISO を外す
sudo virsh autostart raptorlake-win                                  # ホスト起動時に上げる
```

virtio-win の CD (`sdb`) は挿したままにしてある (ゲストツールの導入に使う)。

ゲスト側:

- virtio-win の `virtio-win-guest-tools.exe` を実行 (残りのドライバ + qemu-ga)。
- Tailscale を入れる。これでゲストが固有の tailnet IP を持つので、
  ホスト側の port 転送なしに Mac の Windows App から RDP できる
  (設定 → システム → リモートデスクトップ を有効化)。
- **RDP のログインにはパスワードが要る。** Windows Hello の PIN では入れず、
  Microsoft アカウントがパスワードレス (メールのコードやパスキーだけ) だと
  そのアカウントでは RDP できない。RDP 用のローカルアカウントを作るのが早い:

  ```
  net user rdpuser * /add
  net localgroup "Remote Desktop Users" rdpuser /add
  net localgroup Administrators rdpuser /add
  ```

- ライセンス認証は後からでよい。未認証で制限されるのは個人用設定だけで、
  RDP もネットワークも動く。Microsoft アカウントに紐づいたデジタルライセンスを
  移すなら、そのアカウントを「その他のユーザー」に**管理者として**追加して
  サインインしてから、設定 → システム → ライセンス認証 → トラブルシューティング →
  「このデバイスのハードウェアを最近変更しました」。
  「メールとアカウント」に足しても Windows のユーザーは増えないので効かない。

## Google 共有ドライブを Linux から読む

共有ドライブ (Shared drives) は Drive for Desktop が**ストリーミング固定**で扱う。
ミラー (ローカルに実体を置く) ができるのはマイドライブと「パソコンからのフォルダ」
だけなので、Linux から直接読めるファイルは存在しない。rclone の Drive バックエンドは
データ量が多いと性能が出ず断念した経緯がある。

そこで Windows VM を橋渡しにして、ゲストの Drive を SMB で出し、ホストが cifs で
読み抜く。マウント定義は `configuration.nix` の `fileSystems` にある。

**ホストにコピーを持つ案 (robocopy + btrfs スナップショット) は却下した。**
コピーを持つと「同期が完了するまで待つ」というゲートが生まれる。実際の運用は
「アップロード完了の連絡を受けたらすぐ処理を始める」なので、待ち時間は処理の前ではなく
処理中に混ざってくれないと困る。読み抜きなら転送は処理に混ざり、古いコピーを掴む
余地もない (ディレクトリ一覧が常に Drive の現在の状態になる)。

### ホストを作り直したときに手で用意するもの

宣言に入れられないのは資格情報だけ。公開リポジトリなので置けない。

```sh
sudo install -d -m 700 /etc/smb-credentials
sudo install -m 600 /dev/null /etc/smb-credentials/gdrive
sudoedit /etc/smb-credentials/gdrive   # username= と password= の 2 行
```

パスワードは Windows のローカルアカウントのもの。Microsoft アカウントは
パスワードレスだと SMB にも RDP にも使えないので、ローカルアカウントに寄せてある。

### ゲスト側の設定

**Drive のマウント先はドライブレターではなくフォルダにする。** Drive for Desktop の
環境設定 → 詳細設定 → 「Google ドライブのマウント ポイント」で、ユーザープロファイル
配下のフォルダ (`C:\Users\<user>\gdrive`) を指定する。Drive はその下にアカウントごとの
フォルダ (`<メールアドレス>`) を自分で作るので、Google アカウントが増えても
Windows 側でマウント先を足すだけで済み、共有もホストの設定も増えない。

**共有するのはユーザープロファイルそのもの** (`C:\Users\<user>`) 1 つきり。
共有名は `configuration.nix` に載って公開リポジトリに入るので、共有ドライブ名や
施設名は使わない。プロファイル全体を共有すると `AppData` (Drive の OAuth トークン、
ブラウザのプロファイル) も読める範囲に入るが、読み取り専用で、到達できるのは
NAT 側のホストだけ、という前提で許容している。範囲を絞りたければ受け渡し用の
フォルダを 1 つ作ってそれだけを共有してもよい (仕組みは同じ)。

- 設定 → ネットワークとインターネット → ネットワークの詳細設定 → 共有の詳細設定 で
  「ファイルとプリンターの共有」をオン。ネットワークの種類は「プライベート」にする
  (libvirt の NAT は既定でパブリック扱いになり、共有がブロックされる)
- 共有のアクセス許可は Everyone ではなく専用アカウント 1 つに絞り、読み取りだけ与える。
  さらに Windows Defender ファイアウォールの受信規則
  「ファイルとプリンターの共有 (SMB 受信)」のスコープを `192.168.122.0/24` に限定する。
  **この tailnet には他人の端末もいる**ので、絞らないと tailnet から到達できる全員が
  共有ドライブを読める
- **自動ログオンは必須。** Sysinternals の Autologon を使う (`netplwiz` やレジストリ
  直書きと違い、パスワードを LSA シークレットとして保存する)。Drive はユーザー
  セッションでしか動かないので、サインインしていないとマウント先のフォルダが空になり、
  ホストからは共有は見えるのに中身が無い、という状態になる
- Linux 側から書き込みたくなったら、そのアカウントのフォルダだけを別の共有にして
  `rw` でマウントする。プロファイルの共有は読み取り専用のまま残す。禁止したい側に
  何も足さない形なので、設定漏れで書けてしまう方向には転ばない。なお NTFS の ACL で
  アカウントごとに差を付けることはできない (`gdrive` 配下は DriveFS の仮想 FS で、
  Windows のアクセス許可に従わない)

### ハマった点

- **`mount.cifs` が無いと `credentials=` が無視される。** ユーザ空間ヘルパーが解釈する
  オプションなので、helper が無いとカーネルに素通しされ、匿名セッションとして
  `STATUS_ACCESS_DENIED` になる。`fileSystems` で宣言すれば NixOS が入れる
- **`noserverino` が要る。** Drive for Desktop の仮想 FS は一意な inode 番号を返さず、
  既定の `serverino` では `readdir` が EINVAL で落ちる (`ls: Invalid argument`)
- **名前解決の順序。** 既定の `hosts:` は `resolve [!UNAVAIL=return]` が先頭近くにあり、
  systemd-resolved が「見つからない」と答えた時点で打ち切られる。libvirt の NSS
  モジュールは `mkBefore` でその前に置かないと引かれない
- **ゲストのホスト名を使うと Tailscale の MagicDNS が先に応答する。** SMB が tailnet
  経由になってしまうので、参照するのは libvirt の domain 名にしてある
- **ドライブレターを指す共有は再起動を生き延びない。** LanmanServer は起動時に共有の
  パスを検証し、実在しないものを削除する。Drive のドライブレターはサインイン後に
  しか生えないので必ずこれに当たり、サインインしてもレターが戻るだけで共有定義は
  戻らない (`net share` から消える / `NT_STATUS_BAD_NETWORK_NAME`)。常に実在する
  フォルダを共有することで回避している
- **`virsh domrename` は nvram のファイル名を追随させない。** domain を
  `win11` から `raptorlake-win` に改名したが、`/var/lib/libvirt/qemu/nvram/win11_VARS.fd`
  はそのまま。XML が絶対パスで指しているので動作に影響はない
- **domain 名とゲストの hostname は別物。** どちらも `raptorlake-win` にしてあるが、
  解決経路が違う (前者が `libvirt_guest`、後者が `libvirt` と MagicDNS)

### 検証済みの挙動

VM を再起動して、以下を実測した。

- `virsh shutdown` (モード指定なし) でゲストがきれいに落ちる。ゲストエージェントが
  あるとそちらが使われるため。エージェントが無かったときは ACPI にフォールバックし、
  ウィンドウが開いた状態では落ちなかった
- 共有が再起動後も残り、自動ログオンで Drive がマウントされ、ホストの automount が
  繋ぎ直して `/srv/raptorlake-win/shimp/gdrive/<アカウント>/共有ドライブ/` が読める

ホスト再起動の経路も、部品としては確認済み: `libvirt-guests.service` が有効
(`ON_SHUTDOWN=shutdown`, `SHUTDOWN_TIMEOUT=300`)、domain は autostart 有効、
automount は `remote-fs.target` の WantedBy にある。ホスト起動直後の 1〜2 分は
VM の起動とサインインを待つので読めない (マウントのタイムアウトは 30 秒)。
