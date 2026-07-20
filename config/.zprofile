# ~/.zprofile - ログインシェルのみ（zshrc の前）

# herdr のペイン内では何も起動しない (HERDR_ENV が立つ)。
# ssh されてきたときは自動で herdr に入る (detach-and-reconnect は herdr-attach 側)。
# ローカル端末では tuicast を出す。herdr へは picker の herdr エントリから入る。
if [ -z "$HERDR_ENV" ] && [[ -t 0 ]]; then
  if [ -n "$SSH_CONNECTION" ] && command -v herdr &> /dev/null; then
    ~/.local/bin/herdr-attach
  elif command -v tuicast &> /dev/null; then
    tuicast
  fi
fi
