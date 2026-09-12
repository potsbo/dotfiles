_:
{
  imports = [
    ../../modules/nixos/common.nix
  ];

  # 開発機なので未使用イメージ・volume も含めて毎週 prune する
  # (volume を消すのは phoenix 限定の判断。共通モジュールには入れない)
  virtualisation.docker.autoPrune = {
    enable = true;
    dates = "weekly";
    flags = [ "--all" "--volumes" ];
  };

  # niri (スクロール式タイリング) のお試し。ブートメニューで "niri" を選んだときだけ
  # 有効になる。通常起動は Hyprland のまま。設定は home/.config/niri/。
  specialisation.niri.configuration = {
    desktop.environment = "niri";
  };
}
