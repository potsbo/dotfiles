{ buildNpmPackage, fetchFromGitHub }:

let
  # renovate: datasource=github-releases depName=Doist/todoist-cli
  version = "3.2.0";
in
buildNpmPackage {
  pname = "todoist-cli";
  inherit version;

  src = fetchFromGitHub {
    owner = "Doist";
    repo = "todoist-cli";
    rev = "v${version}";
    hash = "sha256-JOfaWMGvnCk07wDwGo1ce2G21XHz+utW1fhkLt3VEPs=";
  };

  npmDepsHash = "sha256-DHuiICKfpWAlX9BmUhV3tlLsH8KjsO+x1r7sdOiTo3Y=";
}
