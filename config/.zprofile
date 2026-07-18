# ~/.zprofile - ログインシェルのみ（zshrc の前）

# 自動で herdr に入る（herdr のペイン内では起動しない: HERDR_ENV が立つ）。
# ループなのは ssh ピッカーの detach-and-reconnect のため: herdr 内の tuicast で
# ssh 先を選ぶと ssh-connect.sh が /tmp/herdr-ssh-pending を書いて client を
# 落とすので、ここで拾って ssh をフルスクリーン実行し、終わったら re-attach する。
# 素の detach (pending なし) ならループを抜けてシェルに戻る。
if [ -z "$HERDR_ENV" ] && [[ -t 0 ]] && command -v herdr &> /dev/null; then
  while :; do
    herdr
    # mtime 1分以内のものだけ拾う (消し損ねた古い pending で ssh しない)
    if [[ -n $(find /tmp/herdr-ssh-pending -mmin -1 2>/dev/null) ]]; then
      _pending_host=$(cat /tmp/herdr-ssh-pending)
      rm -f /tmp/herdr-ssh-pending
      [ -n "$_pending_host" ] && ~/.config/tuicast/ssh-reconnect.sh "$_pending_host"
      unset _pending_host
    else
      break
    fi
  done
fi
