# ~/.zprofile - ログインシェルのみ（zshrc の前）

# herdr のペイン内では何も起動しない (HERDR_ENV が立つ)。
# VSCode のターミナルはワークスペースごとの専用 herdr session に入る
# (Remote-SSH でも SSH_CONNECTION より先に判定して同じ挙動にする)。
# ssh されてきたときもローカル端末でも自動で herdr に入る
# (detach-and-reconnect は herdr-attach 側)。herdr が無ければ tuicast にフォールバック。
# 対話シェルに限る: ディスプレイマネージャが wayland-session を `zsh --login <script>` で
# 実行すると stdin が tty になり、-t 0 だけだと herdr が立ち上がって DE が起動せず黒画面で
# 固まる (2026-09-06 に SDDM で踏んだ。SDDM を使っていた Plasma の設定はその後消した)。
if [ -z "$HERDR_ENV" ] && [[ -o interactive ]] && [[ -t 0 ]]; then
  if [ "$TERM_PROGRAM" = "vscode" ] && command -v herdr &> /dev/null; then
    ~/.local/bin/herdr-vscode-attach
  elif command -v herdr &> /dev/null; then
    ~/.local/bin/herdr-attach
  elif command -v tuicast &> /dev/null; then
    tuicast
  fi
fi
