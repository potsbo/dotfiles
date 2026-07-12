# ~/.zprofile - ログインシェルのみ（zshrc の前）

# 自動で tmux に入る（herdr のペイン内では起動しない: HERDR_ENV が立つ）
if [ -z "$TMUX" ] && [ -z "$HERDR_ENV" ] && [[ -t 0 ]] && command -v sesh &> /dev/null; then
  tuicast
  if [ -f /tmp/sesh-exit-ssh ]; then
    rm -f /tmp/sesh-exit-ssh
    exit 0
  fi
fi
