# ~/.zprofile - ログインシェルのみ（zshrc の前）

# herdr のペイン内では何も起動しない (HERDR_ENV が立つ)。
# VSCode のターミナルはワークスペースごとの専用 herdr session に入る
# (Remote-SSH でも SSH_CONNECTION より先に判定して同じ挙動にする)。
# ssh されてきたときもローカル端末でも自動で herdr に入る
# (detach-and-reconnect は herdr-attach 側)。herdr が無ければ tuicast にフォールバック。
# 対話シェルに限る: SDDM は wayland-session を `zsh --login <script>` で実行し、stdin が
# tty なので -t 0 だけだと herdr が立ち上がって KWin が起動せず黒画面で固まる (2026-09-06)。
if [ -z "$HERDR_ENV" ] && [[ -o interactive ]] && [[ -t 0 ]]; then
  if [ "$TERM_PROGRAM" = "vscode" ] && command -v herdr &> /dev/null; then
    ~/.local/bin/herdr-vscode-attach
  elif command -v herdr &> /dev/null; then
    ~/.local/bin/herdr-attach
  elif command -v tuicast &> /dev/null; then
    tuicast
  fi
fi
