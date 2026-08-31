{ buildNpmPackage, fetchFromGitHub }:

let
  # renovate: datasource=github-releases depName=Doist/todoist-cli
  version = "5.1.3";
in
buildNpmPackage {
  pname = "todoist-cli";
  inherit version;

  src = fetchFromGitHub {
    owner = "Doist";
    repo = "todoist-cli";
    rev = "v${version}";
    hash = "sha256-gyI3FO8A5dHBBJP4CdS7RYKZzbRjIQ2GUFUmWKZuytk=";
  };

  npmDepsHash = "sha256-UC1HQw36tEvsRpyuHOHyS57iuUTmnadg0odHFlal0LU=";
}
