# ~/.zprofile - ログインシェルのみ（zshrc の前）

# ログインシェルでは tuicast (worktree / ssh ピッカー) を出す。
# 対話シェルに限る: ディスプレイマネージャが wayland-session を `zsh --login <script>` で
# 実行すると stdin が tty になり、-t 0 だけだと tuicast が立ち上がって DE が起動せず黒画面で
# 固まる (2026-09-06 に SDDM で踏んだ。SDDM を使っていた Plasma の設定はその後消した)。
# Rex のペイン内 (REX_SESSION が立つ) では出さない。Rex 自体がセッション/ペインを
# 持つので、ペインを開くたびにピッカーが割り込むと邪魔になる。
if [ -z "$REX_SESSION" ] && [[ -o interactive ]] && [[ -t 0 ]] && command -v tuicast &> /dev/null; then
  tuicast
fi
