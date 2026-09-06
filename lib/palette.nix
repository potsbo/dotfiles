# 自分用のカラーパレット。hex を書くのはここだけ。
#
# 使う側: flake.nix (ホスト色)、starship.nix、lazygit.nix。
# 命名は Monokai Classic を基準にした色名で、用途名 (accent, warning) は
# 使う側で付ける。
#
# 統合の履歴 (元の値が欲しくなったとき用):
#   gray   #797979 (host 既定色) と #75715e (lazygit 非アクティブ枠) → Monokai comment の #75715e
#   white  #eeeeee (starship) → #f8f8f2
#   red    #ff0087 (starship peach) → #f92672
#   green  #AFD760 (starship yellow) → #a6e22e
# starship にあった Catppuccin の red/green (#f38ba8/#a6e3a1) は未使用だったので捨てた。
#
# ここに入れていないもの:
#   gh-dash の紺系テーマ、nvim の rainbow-delimiters (VSCode の括弧色をそのまま)、
#   claude-powerline (Anthropic のブランド色)。どれもツール固有のテーマで
#   このパレットの色を共有しないので、無理に寄せない。
{
  black = "#11111b";   # 明るい背景に乗せる文字色
  surface = "#5c5a50"; # 選択行の背景
  gray = "#75715e";
  white = "#f8f8f2";
  red = "#f92672";
  orange = "#d7875f";
  yellow = "#e6db74";
  green = "#a6e22e";
  cyan = "#55bed2";
  blue = "#6796e6";
  purple = "#ae81ff";
}
