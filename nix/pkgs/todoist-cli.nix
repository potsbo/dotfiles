{ buildNpmPackage, fetchFromGitHub }:

let
  # renovate: datasource=github-releases depName=Doist/todoist-cli
  version = "5.2.0";
in
buildNpmPackage {
  pname = "todoist-cli";
  inherit version;

  src = fetchFromGitHub {
    owner = "Doist";
    repo = "todoist-cli";
    rev = "v${version}";
    hash = "sha256-V3apDeMn/K0rvZk7MXsIevlvDrjPace8aSqs0wbyPPU=";
  };

  npmDepsHash = "sha256-Np/e5Ph5IDw0+I0cKK4d7ExMefKJZBGe+yv8sFkvQjs=";
}
