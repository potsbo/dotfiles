# ~/.zprofile - ログインシェルのみ（zshrc の前）

# 自動で herdr に入る（herdr のペイン内では起動しない: HERDR_ENV が立つ）
if [ -z "$HERDR_ENV" ] && [[ -t 0 ]] && command -v herdr &> /dev/null; then
  herdr
fi
