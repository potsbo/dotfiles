{ buildNpmPackage, fetchFromGitHub }:

let
  # renovate: datasource=github-releases depName=Doist/todoist-cli
  version = "5.1.0";
in
buildNpmPackage {
  pname = "todoist-cli";
  inherit version;

  src = fetchFromGitHub {
    owner = "Doist";
    repo = "todoist-cli";
    rev = "v${version}";
    hash = "sha256-LfE3K/TPVj5ovOG42ZadsyzOZCceLWl4U2Bwg/JsK8c=";
  };

  npmDepsHash = "sha256-xHoRE//pMm8QNgtjZmhvSGPha4hnEgFc9JmK2Mckuu8=";
}
