{ buildNpmPackage, fetchFromGitHub }:

let
  # renovate: datasource=github-releases depName=Doist/todoist-cli
  version = "3.1.9";
in
buildNpmPackage {
  pname = "todoist-cli";
  inherit version;

  src = fetchFromGitHub {
    owner = "Doist";
    repo = "todoist-cli";
    rev = "v${version}";
    hash = "sha256-aJfAyYkevgBX2+BhVhaYCXA4HEwNkZ5axMAbd7D/se0=";
  };

  npmDepsHash = "sha256-99kXulw63VumKlbefi4T0lnkRZs8e9TH9v4vFOvH18Y=";
}
