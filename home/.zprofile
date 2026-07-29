# ~/.zprofile - ログインシェルのみ（zshrc の前）

# herdr のペイン内では何も起動しない (HERDR_ENV が立つ)。
# VSCode のターミナルはワークスペースごとの専用 herdr session に入る
# (Remote-SSH でも SSH_CONNECTION より先に判定して同じ挙動にする)。
# ssh されてきたときは自動で herdr に入る (detach-and-reconnect は herdr-attach 側)。
# ローカル端末では tuicast を出す。herdr へは picker の herdr エントリから入る。
if [ -z "$HERDR_ENV" ] && [[ -t 0 ]]; then
  if [ "$TERM_PROGRAM" = "vscode" ] && command -v herdr &> /dev/null; then
    ~/.local/bin/herdr-vscode-attach
  elif command -v herdr &> /dev/null; then
    ~/.local/bin/herdr-attach
  elif command -v tuicast &> /dev/null; then
    tuicast
  fi
fi
