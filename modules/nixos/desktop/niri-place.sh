#!/usr/bin/env bash
# docs/keymap.md §3.4 の格子配置 (P1〜P6) を niri で実現する。
# 使い方: niri-place <left|right|tl|tr|bl|br>
#
# niri は 1 つのバインドに 1 つの action しか書けないので、複数の action をここで束ねる。
#
# §4.1 のとおりタイリング流に寄せる。窓を浮動にして絶対座標に置くのではなく、列の幅と
# 列の中での位置で表現する。そのため空いた枠には隣の窓が入り、窓を閉じると残りが広がる。
#
# 「左」「右」は列の並びの端という意味 (move-column-to-first / -last)。画面の絶対座標では
# ない。列が 3 本以上あるときに画面上どこに見えるかはスクロール位置しだいで、これは
# §4.1 で許容すると決めてある。
#
# 列に自分しかいないときの高さ:
#   - 上半分を狙うとき (tl / tr) は高さを半分にする。列は上から詰めるので上半分に座る。
#   - 下半分を狙うとき (bl / br) は高さを変えない。半分にしても上に詰められてしまい、
#     「下」にならないため。相方の窓を同じ列に入れて初めて下半分になる。
set -euo pipefail

target=${1:?usage: niri-place <left|right|tl|tr|bl|br>}

act() { niri msg action "$@" >/dev/null; }

# フォーカスしている窓と、同じワークスペースのタイル窓の並びを読む。
# pos_in_scrolling_layout は [列番号, 列の中での番号] で、どちらも 1 始まり。
read_state() {
  local windows me
  windows=$(niri msg --json windows)
  me=$(jq -c '.[] | select(.is_focused)' <<<"$windows")
  [ -n "$me" ] || exit 0
  # 浮動の窓は並びに乗っていないので対象外
  [ "$(jq -r '.is_floating' <<<"$me")" = "false" ] || exit 0

  local ws peers
  ws=$(jq '.workspace_id' <<<"$me")
  peers=$(jq -c --argjson ws "$ws" \
    '[.[] | select(.workspace_id == $ws and .is_floating == false)]' <<<"$windows")

  col=$(jq '.layout.pos_in_scrolling_layout[0]' <<<"$me")
  row=$(jq '.layout.pos_in_scrolling_layout[1]' <<<"$me")
  ncols=$(jq '[.[].layout.pos_in_scrolling_layout[0]] | max // 1' <<<"$peers")
  colsize=$(jq --argjson c "$col" \
    '[.[] | select(.layout.pos_in_scrolling_layout[0] == $c)] | length' <<<"$peers")
}

read_state

case "$target" in
  left | right)
    # 半分は列に 1 枚だけ。列に相方がいるなら追い出して独立した列にする
    if [ "$colsize" -gt 1 ]; then
      act consume-or-expel-window-left
      read_state
    fi
    ;;
esac

case "$target" in
  left | tl | bl) act move-column-to-first ;;
  right | tr | br) act move-column-to-last ;;
esac

case "$target" in
  tl | bl)
    # 左側の 1/4 は、右隣の窓を同じ列に引き込んで上下に分ける (§4.1 の「隣が追従する」)。
    # 右側 (tr / br) に同じことはできない。niri の consume は右からしか取り込めないので、
    # 一番右の列に相方を入れる操作が無い。相方の側で tr / br を押せば揃う。
    if [ "$colsize" -eq 1 ] && [ "$ncols" -gt 1 ]; then
      act consume-window-into-column
      read_state
    fi
    ;;
esac

# 列の中での上下。move-window-up / -down は 1 つずつ動くので、端に着くまで繰り返す。
# 列の枚数を上限にして、動かなくなったら抜ける。
case "$target" in
  tl | tr)
    for ((i = 0; i < colsize; i++)); do
      [ "$row" -le 1 ] && break
      act move-window-up
      read_state
    done
    ;;
  bl | br)
    for ((i = 0; i < colsize; i++)); do
      [ "$row" -ge "$colsize" ] && break
      act move-window-down
      read_state
    done
    ;;
esac

case "$target" in
  left | right)
    act set-column-width "50%"
    act reset-window-height
    ;;
  tl | tr)
    act set-column-width "50%"
    act set-window-height "50%"
    ;;
  bl | br)
    act set-column-width "50%"
    if [ "$colsize" -gt 1 ]; then
      act set-window-height "50%"
    else
      act reset-window-height
    fi
    ;;
esac
