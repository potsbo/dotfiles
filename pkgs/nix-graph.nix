{ lib, buildGoModule, fetchFromGitHub, makeWrapper, nix }:

# upstream の flake を input にせず自前で package する。upstream の flake は systems と
# meta.platforms を linux に絞っていて、そのままでは darwin ホストの eval が通らないため。
# 派生の中身 (subPackages / vendorHash=null / nix の wrap) は upstream の flake.nix に合わせる。
#
# release を切っていないので commit hash で固定する。追従の仕組みは tuicast.nix と同じ。
buildGoModule {
  pname = "nix-graph";
  version = "0-unstable";

  src = fetchFromGitHub {
    owner = "AlexAntonik";
    repo = "nix-graph";
    # renovate: datasource=git-refs depName=https://github.com/AlexAntonik/nix-graph branch=main
    rev = "65a77c03cd8c72bca1cc303b8bee16dc94d79106";
    hash = "sha256-6q6M8n2S3SBYfmgAboIx4aVYsjY3U4yPYn3qYLdGtZc=";
  };

  subPackages = [ "cmd/nix-graph" ];
  # 依存が無く go.sum も無いので vendor しない。
  vendorHash = null;
  env.CGO_ENABLED = "0";

  nativeBuildInputs = [ makeWrapper ];
  # 実行時に nix コマンドを呼ぶ。PATH に無いホストでも動くように前置きする。
  postInstall = ''
    wrapProgram $out/bin/nix-graph --prefix PATH : ${lib.makeBinPath [ nix ]}
  '';

  meta.mainProgram = "nix-graph";
}
