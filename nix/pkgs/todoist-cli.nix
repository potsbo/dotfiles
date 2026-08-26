{ buildNpmPackage, fetchFromGitHub }:

let
  # renovate: datasource=github-releases depName=Doist/todoist-cli
  version = "3.3.2";
in
buildNpmPackage {
  pname = "todoist-cli";
  inherit version;

  src = fetchFromGitHub {
    owner = "Doist";
    repo = "todoist-cli";
    rev = "v${version}";
    hash = "sha256-zXBSwN5PRc/Dvwmm8ReNeC6KlbFvFQ1a8flop1y72P0=";
  };

  npmDepsHash = "sha256-iIUStlPISrsb+jJ0y8pllZXhRRrkpgaAEG3SwnYbAH4=";
}
