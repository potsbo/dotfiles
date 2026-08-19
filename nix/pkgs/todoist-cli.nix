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
    hash = "sha256-tVgeKHWakydkflgttV/faLCL9S05HQ6Pc7E79qYVtAY=";
  };

  npmDepsHash = "sha256-R3BZSJ/tKpyObpI8x9oYjgecgF9n5m0aUWSLa1IVGxk=";
}
