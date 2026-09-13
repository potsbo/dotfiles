# DMS のランチャーが起動するコマンドの前に付く launch prefix (desktop/dms.nix)。
# macOS / Raycast の「既に開いているアプリは新しく起動せずそのウィンドウに移る」を再現する。
# 使い方: dms-focus-or-launch <cmd> [args...]
#
# DMS からは実行コマンドしか渡ってこない (.desktop の id は来ない) ので、ウィンドウの
# class は実行ファイル名から推測する。class と実行ファイル名は完全一致しないことが多い
# (google-chrome-stable と google-chrome、ghostty と com.mitchellh.ghostty、slack と Slack)
# ので、大文字小文字を無視してどちらかがもう一方を含めば同じアプリとみなす。
# Chrome の --app=URL (desktop.nix の webApp) は class がホスト名を含むので、ホスト名で探す。
set -euo pipefail

[ $# -gt 0 ] || exit 0
# 起動に回すときのために、渡された引数をそのまま取っておく
orig=("$@")

# `env VAR=val cmd` 形式の Exec は env と代入を飛ばしてコマンド名を取る
while [ $# -gt 0 ]; do
  case "$1" in
    env) shift ;;
    *=*) shift ;;
    *) break ;;
  esac
done
[ $# -gt 0 ] || exit 0
key=$(basename "$1")
for arg in "$@"; do
  case "$arg" in
    --app=*)
      key=${arg#--app=}
      key=${key#*://}
      key=${key%%/*}
      break
      ;;
  esac
done

# .desktop の %U/%F が展開された引数 (URL・ファイル) が付いているか。付いていれば
# 「このアプリを出せ」ではなく「これを開け」なので、フォーカスだけで終わらせず必ず起動に回す。
# 書き換え済みの .desktop は DMS から起動したアプリにも XDG_DATA_DIRS 経由で見えるので、
# その中の xdg-open が引く https ハンドラもここを通る。フォーカスして終わると Slack や
# Obsidian のリンクが握り潰され、何も起きないように見える。
#
# 引数の見た目で判定する。`dms ipc call notepad openFile` や `systemsettings kcm_fcitx5` の
# ようにサブコマンドを取る Exec があるので、「位置引数があるか」では区切れない。
# --app=URL は `-` 始まりなのでここには掛からず、従来どおりフォーカス対象のまま。
opens_document=
shift
for arg in "$@"; do
  case "$arg" in
    -*) ;;
    *://*) opens_document=1 ;;
    *)
      if [ -e "$arg" ]; then
        opens_document=1
      fi
      ;;
  esac
done

# niri は compositor ごとに問い合わせ先が違うだけで、探し方は同じ。NIRI_SOCKET が
# 立っているかで見分ける (niri がセッションの全プロセスに渡す)。
if [ -n "${NIRI_SOCKET:-}" ]; then
  # niri の window には Hyprland の focusHistoryID にあたるものが無いので、最初に
  # 見つかったものにする
  id=$(niri msg -j windows | jq -r --arg k "$key" '
    ($k | ascii_downcase) as $key
    | [ .[]
        | ((.app_id // "") | ascii_downcase) as $c
        | select($c != "" and (($c | contains($key)) or ($key | contains($c))))
      ]
    | .[0].id // empty')

  if [ -n "$id" ]; then
    if [ -n "$opens_document" ]; then
      "${orig[@]}" >/dev/null 2>&1 &
    fi
    niri msg action focus-window --id "$id" >/dev/null
    exit 0
  fi

  exec "${orig[@]}"
fi

# 直近にフォーカスしていたものを選ぶ (focusHistoryID が小さいほど最近)
addr=$(hyprctl clients -j | jq -r --arg k "$key" '
  ($k | ascii_downcase) as $key
  | [ .[]
      | select(.mapped)
      | ((.class // "") | ascii_downcase) as $c
      | select($c != "" and (($c | contains($key)) or ($key | contains($c))))
    ]
  | sort_by(.focusHistoryID)
  | .[0].address // empty')

if [ -n "$addr" ]; then
  # 既に起動しているので、URL・ファイルは走らせた側 (Chrome なら既存セッションへの
  # ハンドオフ) が開く。すぐ終わるがフォーカスを待たせる必要も無いので後ろに流す。
  if [ -n "$opens_document" ]; then
    "${orig[@]}" >/dev/null 2>&1 &
  fi
  # 設定が Lua のときの hyprctl dispatch は Lua 式を受け取る (旧来の "focuswindow ..." は通らない)
  hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" >/dev/null
  # 浮動ウィンドウはフォーカスしても重なり順が変わらず、他のウィンドウの下に残ることがある
  hyprctl dispatch "hl.dsp.window.alter_zorder({ window = \"address:$addr\", mode = \"top\" })" >/dev/null
  exit 0
fi

exec "${orig[@]}"
