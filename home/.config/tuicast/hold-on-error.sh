#!/usr/bin/env bash
# tuicast run ターゲットのラッパ。herdr の popup (type="popup") はコマンドが
# 終了した瞬間に閉じるため、run が失敗するとエラーが一瞬見えるだけで消える。
# 失敗したらキー入力があるまで popup を開いたままにする (何かキー / ctrl-c で閉じる)。
#
# - 成功 (exit 0) と ctrl-c 終了 (130) はそのまま閉じる
# - herdr の外 (HERDR_ENV なし) は popup ではなく普通の端末で、エラーは画面に
#   残るので hold しない
#
# Usage: hold-on-error.sh <command> [args...]
set -u

"$@"
status=$?

if [ "$status" -eq 0 ] || [ "$status" -eq 130 ] || [ -z "${HERDR_ENV:-}" ]; then
  exit "$status"
fi

printf '\n\033[31m%s failed (exit %d)\033[39m\n' "$1" "$status" >&2
printf 'press any key to close\n' >&2
# popup の stdin が tty でない場合に備えて /dev/tty から読む。tty が取れない
# 環境では待たずに閉じる (|| true)。
read -rsn1 2>/dev/null </dev/tty || true
exit "$status"
