{ buildGoModule, fetchFromGitHub }:

let
  # renovate: datasource=github-releases depName=aquaproj/aqua
  version = "2.62.3";
in
# go は固定しない。go_1_XX で override すると nixpkgs の default が進んでも追従せず、
# Renovate も attr 名は書き換えないので手で bump することになる (2026-09 に一度やった)。
# aqua の go.mod が nixpkgs の default より新しい go を要求したときだけ一時的に
# override し、default が追いついたら外す。
buildGoModule {
  pname = "aqua";
  inherit version;

  src = fetchFromGitHub {
    owner = "aquaproj";
    repo = "aqua";
    rev = "v${version}";
    hash = "sha256-SrkSel+hiUIRAip/U3ODFkLBkqFjVKjar6TbkQab+lE=";
  };

  vendorHash = "sha256-PLtYXYpbZKHDzvK589wZtpVcv2YIBxLruHLHKbRjM30=";

  # テスト実行をスキップする。
  # aqua のテストが /bin/date をハードコードしており、nix サンドボックスには存在しないため失敗する。
  # aqua 本体の品質は upstream CI で担保されているため、ここでのテストは不要。
  doCheck = false;
}
