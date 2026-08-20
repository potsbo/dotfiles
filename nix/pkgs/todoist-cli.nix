{ buildNpmPackage, fetchFromGitHub }:

let
  # renovate: datasource=github-releases depName=Doist/todoist-cli
  version = "3.2.3";
in
buildNpmPackage {
  pname = "todoist-cli";
  inherit version;

  src = fetchFromGitHub {
    owner = "Doist";
    repo = "todoist-cli";
    rev = "v${version}";
    hash = "sha256-7c1gsvtkYLBzgutE2QPGFs31rl9p5/AVZwf45tP0yZ0=";
  };

  npmDepsHash = "sha256-Ecg65k289KE2X6R4iXmkmdLEW4vl8h+DRTeisbzpLh0=";
}
