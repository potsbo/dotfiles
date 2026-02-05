# ~/.zprofile - ログインシェルのみ（zshrc の前）

# 自動で tmux に入る
if [ -z "$TMUX" ] && command -v sesh &> /dev/null; then
  ~/.config/tmux/sesh-connect.sh
  if [ -f /tmp/sesh-exit-ssh ]; then
    rm -f /tmp/sesh-exit-ssh
    exit 0
  fi
fi
