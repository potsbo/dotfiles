# nix-daemon の設定のうち NixOS と nix-darwin で共通のもの (オプション名が同じ)。
{ user, ... }:

{
  # サービス用アカウントには daemon を使わせない。root は既定の trusted-users で許可される。
  nix.settings.allowed-users = [ user ];
}
