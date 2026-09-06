# specialisation で起動しているとき、その名前を /etc/specialisation に書く。
# `rebuild` がこれを読んで `nixos-rebuild switch --specialisation <name>` にする。
#
# 無いと rebuild は基本構成を有効化してしまい、specialisation で起動中に打つと
# 動いている system から Hyprland が消えて、次のログインが失敗する (2026-09-06 に踏んだ)。
#
# specialisation option は attrsOf submodule なので、同じ形で宣言し直すと submodule 側が
# マージされ、全 specialisation に自動で付く。各ホストで名前を書き写さずに済む。
{ lib, ... }:
{
  options.specialisation = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
      config.configuration.environment.etc."specialisation".text = name;
    }));
  };
}
