{ buildNpmPackage, fetchFromGitHub }:

let
  # renovate: datasource=github-releases depName=Doist/todoist-cli
  version = "3.2.1";
in
buildNpmPackage {
  pname = "todoist-cli";
  inherit version;

  src = fetchFromGitHub {
    owner = "Doist";
    repo = "todoist-cli";
    rev = "v${version}";
    hash = "sha256-vZo7li0GGPMdSXDQ/fB7o5AJaRbXYNnb4QekZBZJON8=";
  };

  npmDepsHash = "sha256-e6WMIJst8M1lINulDyLphYOgAM4cmojHld0sGpriGRg=";
}
