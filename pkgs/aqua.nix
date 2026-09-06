{ buildGoModule, fetchFromGitHub, go_1_26 }:

let
  # renovate: datasource=github-releases depName=aquaproj/aqua
  version = "2.62.3";
in
buildGoModule.override { go = go_1_26; } {
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
