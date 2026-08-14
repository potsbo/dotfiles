{ buildGoModule, fetchFromGitHub, go_1_26 }:

let
  # renovate: datasource=github-releases depName=aquaproj/aqua
  version = "2.57.1";
in
buildGoModule.override { go = go_1_26; } {
  pname = "aqua";
  inherit version;

  src = fetchFromGitHub {
    owner = "aquaproj";
    repo = "aqua";
    rev = "v${version}";
    hash = "sha256-ZxSRUVhDDW8+GGqLV7gia/zH1wa9e1iU3vG3RCV7cmI=";
  };

  vendorHash = "sha256-kN7FxyVy2QFLkC/fiYGIuf3/6PrUoC2CMY5sQMuBLPE=";

  # テスト実行をスキップする。
  # aqua のテストが /bin/date をハードコードしており、nix サンドボックスには存在しないため失敗する。
  # aqua 本体の品質は upstream CI で担保されているため、ここでのテストは不要。
  doCheck = false;
}
