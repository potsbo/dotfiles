# raptorlake-win

raptorlake 上の Windows 11 Pro ゲスト。VM そのもの (libvirt の domain、ホスト側の
マウント) は `../raptorlake/README.md` にある。ここにあるのはゲストの中の設定で、
Excel を使う CI を GitHub Actions の self-hosted runner としてここで動かすためのもの。

Windows には nix が無いので、ゲスト側は PowerShell のスクリプトを冪等に書く形で
持つ。何度流しても同じ状態に収束することを、各スクリプトが自分で保証する
(「入っていなければ入れる」「内容が違えば書き直す」)。

## 使い方

raptorlake の上で:

```sh
./hosts/raptorlake-win/apply
```

ssh が通ればそれで `setup.ps1` を流す。通らなければ (作り直した直後など)、
libvirt の guest agent 経由で `bootstrap.ps1` を SYSTEM として流して ssh を通し、
そのあと `setup.ps1` に進む。guest agent は libvirt ホストの上でしか叩けないので、
bootstrap だけは raptorlake 上で実行する必要がある。ssh が通ったあとは、ゲストに
届くところならどこからでも `apply` できる。

スクリプトはゲストにコピーせず stdin から流す。ゲスト側に「どの版のスクリプトが
置いてあるか」という状態を持たせないため。

### runner の登録

runner の登録先 (リポジトリ) はここに書かない。公開リポジトリなので。
登録トークンは 1 時間で失効する使い捨てで、リポジトリの
Settings → Actions → Runners → New self-hosted runner に出る。

```sh
RUNNER_URL=https://github.com/<owner>/<repo> RUNNER_TOKEN=... ./hosts/raptorlake-win/apply
```

一度登録すれば `C:\actions-runner\.runner` が残るので、以後は環境変数なしでよい。
ラベルは `excel`。ワークフロー側は `runs-on: [self-hosted, windows, excel]`。

## 何をどう決めたか

- **ssh の鍵は GitHub から引く。** `modules/nixos/sshd.nix` と同じ方針で、静的な
  authorized_keys は置かない。理由もそちらのコメントのとおり (失効の反映速度を
  可用性より優先)。ただし `%u` は使わず GitHub のユーザー名を固定し、`AllowUsers` で
  Windows 側のアカウントも 1 つに絞る。このゲストには RDP / SMB 用のローカル
  アカウントが他にもあり、`%u` だとそれらと同名の GitHub ユーザーの鍵で入れてしまう
- **ホスト鍵は guest agent で取り出して known_hosts に固定する。** 初回接続で
  受け入れる (TOFU) 経路を作らない。bootstrap のときは既に信頼している経路
  (virsh) があるので、そこから公開鍵を読めばよい
- **runner は service ではなく、ログオン中のユーザーのセッションで動かす。**
  Excel の COM 自動化は対話セッションでしか安定しない。タスクスケジューラの
  「ログオン時」「ユーザーがログオンしているときのみ実行」で `run.cmd` を起動する。
  自動ログオンは Sysinternals Autologon で済ませてある (`../raptorlake/README.md`)
- **開発ツールはここで入れない。** 入れるのは git (runner の checkout 用) と
  PowerShell 7 だけ。task や uv はワークフローの中で aqua が入れる。ゲストにツールの
  版という状態を増やさない
- **VM が壊れたら作り直すのではなく、スナップショットから戻す。** ライセンス認証が
  domain の構成に紐づくので、domain を作り直すと認証が外れる (`../raptorlake/README.md`)。
  runner まで通った状態で `sudo virsh snapshot-create-as raptorlake-win --name runner-ok`
  を取っておく

## 手で済ませてある (宣言に入っていない) もの

`../raptorlake/README.md` の「ゲスト側の設定」にある、Windows のインストール、
virtio のゲストツール、Tailscale、RDP 用アカウント、自動ログオン、Drive for Desktop、
SMB 共有。いずれも対話が要るか資格情報を含むかで、スクリプトに落としていない。
