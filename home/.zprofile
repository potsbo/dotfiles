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
  # この attach がどこから来たかを記録する。herdr のペインは env がペイン作成時に
  # 凍結されるので、中から見た SSH_CONNECTION は「今どこから見ているか」を表さない
  # (ローカルで作ったペインに Mac から attach しても立たず、ssh 中に作ったペインは
  # 座り直しても残る)。herdr は attach 元を API に出さないので、attach の側で残す。
  # ~/.local/bin/open がこれを見て URL をどちらの画面で開くか決める。
  # 置き場は ssh-auth-sock (.zshenv) と同じ $XDG_RUNTIME_DIR: ホスト固有の tmpfs で、
  # 共有リポジトリへの symlink である ~ 配下に出してはいけない。
  if [ -n "$SSH_CONNECTION" ]; then _opener_origin=ssh; else _opener_origin=local; fi
  print -r -- $_opener_origin > "${XDG_RUNTIME_DIR:-/tmp}/opener-origin" 2>/dev/null
  unset _opener_origin

  if [ "$TERM_PROGRAM" = "vscode" ] && command -v herdr &> /dev/null; then
    ~/.local/bin/herdr-vscode-attach
  elif command -v herdr &> /dev/null; then
    ~/.local/bin/herdr-attach
  elif command -v tuicast &> /dev/null; then
    tuicast
  fi
fi
