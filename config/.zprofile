# ~/.zprofile - ログインシェルのみ（zshrc の前）

# 自動で tmux に入る
if [ -z "$TMUX" ] && [[ -t 0 ]] && command -v sesh &> /dev/null; then
  tuicast
  if [ -f /tmp/sesh-exit-ssh ]; then
    rm -f /tmp/sesh-exit-ssh
    exit 0
  fi
fi
