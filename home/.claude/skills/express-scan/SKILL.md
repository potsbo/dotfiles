---
name: express-scan
description: raptorlake-win で、最新の定義でのフルスキャンをできる限り早く済ませる。定義を更新し、取り直せるキャッシュを消し（Drive は止めて起こし直す）、CPU の上限を外してフルスキャンを流す。「express-scan」「フルスキャンして」と言われたときに使う。
---

# express-scan

手順は `~/src/github.com/potsbo/dotfiles/hosts/raptorlake-win/express-scan` にある。
何をなぜやるかはそのスクリプトと `express-scan.ps1` の冒頭に書いてある。

## 流し方

1. raptorlake の上にいることを確かめる（`hostname` が `raptorlake`）。違えば流さずにそう伝える
2. `~/src/github.com/potsbo/dotfiles/hosts/raptorlake-win/express-scan` を Bash の `run_in_background` で流す。
   出力は終わってからまとめて出る
3. 流し始めたら、終わるまで /srv/raptorlake-win（共有ドライブ）が空に見えることを一言伝える
4. 終わったら、出力の「定義」「フルスキャン」の行と、段階ごとの時間をそのまま伝える。時刻は VM の時計（JST）

## 失敗したとき

- 終了コードが 0 でなければ、出力の最後の行をそのまま伝える。Drive は finally で起こし直しているが、
  「起動しない」で落ちたときは potsbo がログオンしていない。RDP でログオンしてもらう
- 「スキャンで N 件検出した」で落ちたら、検出の内容を伝えて止まる。勝手に駆除や除外をしない
- 流し直しは何度でもしてよい（冪等）
