{ buildNpmPackage, fetchFromGitHub }:

let
  # renovate: datasource=github-releases depName=Doist/todoist-cli
  version = "5.2.1";
in
buildNpmPackage {
  pname = "todoist-cli";
  inherit version;

  src = fetchFromGitHub {
    owner = "Doist";
    repo = "todoist-cli";
    rev = "v${version}";
    hash = "sha256-RYk1MSL15dt8aTeRxNPcVNYXnaDRURiITfMEBqR4DIA=";
  };

  npmDepsHash = "sha256-JDFKNVm8G/s4fVsXjKzh0DWmqXDbTJ7huv3LO5mq+rU=";
}
