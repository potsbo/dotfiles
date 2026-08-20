{ buildNpmPackage, fetchFromGitHub }:

let
  # renovate: datasource=github-releases depName=Doist/todoist-cli
  version = "3.2.2";
in
buildNpmPackage {
  pname = "todoist-cli";
  inherit version;

  src = fetchFromGitHub {
    owner = "Doist";
    repo = "todoist-cli";
    rev = "v${version}";
    hash = "sha256-S8SL0uudACIWEesjW4cwaGJrzQSYc4gHX5Kb8BTRFlI=";
  };

  npmDepsHash = "sha256-Vyf1MFk1KE6s3Jw0mUQ527kSe84ch9w+5GdB5jRVgTM=";
}
