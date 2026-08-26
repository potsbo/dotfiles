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
    hash = "sha256-vkLqq76NmPrNZ411K98fc7tXB4O1KyuZRhes6wCgoZM=";
  };

  npmDepsHash = "sha256-/aP5URXvyTNzRuEIPgcIOh222jfvoAdMmLWGzVplqhQ=";
}
