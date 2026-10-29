{ buildGoModule, fetchFromGitHub, go_1_27 }:

let
  # renovate: datasource=github-releases depName=aquaproj/aqua
  version = "2.65.2";
in
# go は固定しない。go_1_XX で override すると nixpkgs の default が進んでも追従せず、
# Renovate も attr 名は書き換えないので手で bump することになる (2026-09 に一度やった)。
# aqua の go.mod が nixpkgs の default より新しい go を要求したときだけ一時的に
# override し、default が追いついたら外す。
# 今は aqua 2.65 の go.mod が 1.27.3 を要求し、default は 1.26.10 (2026-10)。
buildGoModule.override { go = go_1_27; } {
  pname = "aqua";
  inherit version;

  src = fetchFromGitHub {
    owner = "aquaproj";
    repo = "aqua";
    rev = "v${version}";
    hash = "sha256-1YdyVlF4ZyJtRysaHReegOFjFcfSsdJOODnJb4tRV3E=";
  };

  vendorHash = "sha256-xgFQ2iVUbSRupTdCOBe258D5t7kXVP0xEwkuvm+HRgY=";

  # 公式 release (goreleaser) と同じく main.version を埋める。無いと `aqua version` が
  # unknown になり、aqua 自身の update 判定やログの version 表示も効かない。
  # release は main.commit / main.date / main.builtBy も渡すが、main.go に受ける変数が
  # 無く no-op なので付けない。
  ldflags = [ "-s" "-w" "-X main.version=${version}" ];

  # テスト実行をスキップする。
  # aqua のテストが /bin/date をハードコードしており、nix サンドボックスには存在しないため失敗する。
  # aqua 本体の品質は upstream CI で担保されているため、ここでのテストは不要。
  doCheck = false;
}
