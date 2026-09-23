# raptorlake-win

raptorlake 上の Windows 11 Pro ゲスト。VM そのもの (libvirt の domain、ホスト側の
マウント) は `../raptorlake/README.md` にある。ここにあるのはゲストの中の設定で、
目的は **Excel の入った Windows で、手元の変更を ssh 越しにテストできる状態を保つ**こと。

Windows には nix が無いので、ゲスト側は PowerShell のスクリプトを冪等に書く形で
持つ。何度流しても同じ状態に収束することを、各スクリプトが自分で保証する
(「入っていなければ入れる」「内容が違えば書き直す」)。

## 使い方

raptorlake の上で:

```sh
./hosts/raptorlake-win/apply
```

`bootstrap.ps1` (SYSTEM で当てる sshd の設定) と `setup.ps1` (ユーザーとして当てる
残り) を毎回この順に流す。bootstrap は libvirt の guest agent 経由なので raptorlake の
上でしか流せない。ssh が無い状態 (作り直した直後) を起こせるのは guest agent だけ
なので、1 回目は必ず raptorlake の上で実行する。

スクリプトはゲストにコピーせず、`-EncodedCommand` で丸ごと渡す。ゲスト側に「どの版が
置いてあるか」という状態を持たせない。

### Excel でテストを回す

`potsbo` は管理者なので、ssh のセッション (デスクトップ無し) からでも Excel の COM が動く。

```sh
scp -r anonymizer raptorlake-win:C:/Users/shimp/src/one/
ssh raptorlake-win 'cd C:\Users\shimp\src\one\anonymizer; uv run pytest'
```

## 何をどう決めたか

- **ssh の鍵は GitHub から引く。** `modules/nixos/sshd.nix` と同じ方針で、静的な
  authorized_keys は置かない。理由もそちらのコメントのとおり (失効の反映速度を
  可用性より優先)。ただし `%u` は使わず GitHub のユーザー名を固定し、`AllowUsers` で
  Windows 側のアカウントも 1 つに絞る。このゲストには RDP / SMB 用のローカル
  アカウントが他にもあり、`%u` だとそれらと同名の GitHub ユーザーの鍵で入れてしまう
- **ホスト鍵は guest agent で取り出して known_hosts に固定する。** 初回接続で
  受け入れる (TOFU) 経路を作らない。bootstrap のときは既に信頼している経路
  (virsh) があるので、そこから公開鍵を読めばよい
- **CI (GitHub Actions の self-hosted runner) にはしない。** 一度組んで動くところまで
  確かめたが撤去した。runner はリポジトリに書ける人全員のコードをこの VM で実行する
  口になり、この VM は共有ドライブの橋渡し (`potsbo` のセッションで Drive が動いている)
  も兼ねている。専用の非管理者アカウントで動かしても、ローカル権限昇格と VM の
  ネットワーク経由の到達は残る。テストの実行頻度に対して、常設の口を開けておく
  釣り合いが取れない。加えて、非管理者からの Excel の COM 起動は DCOM の起動許可
  (既定は Administrators / INTERACTIVE / SYSTEM) で拒まれ、Excel の CLSID には AppID が
  紐づいていないので Excel だけに許可を足す手段も素直ではなかった
- **開発ツールは git、uv、PowerShell 7 だけ。** task や aqua はテストの実行に要らない
  (`uv run pytest` で足りる)
- **VM が壊れたら作り直すのではなく、スナップショットから戻す。** ライセンス認証が
  domain の構成に紐づくので、domain を作り直すと認証が外れる (`../raptorlake/README.md`)

## 手で済ませてある (宣言に入っていない) もの

`../raptorlake/README.md` の「ゲスト側の設定」にある、Windows のインストール、
virtio のゲストツール、Tailscale、RDP 用アカウント、自動ログオン、Drive for Desktop、
SMB 共有。いずれも対話が要るか資格情報を含むかで、スクリプトに落としていない。
