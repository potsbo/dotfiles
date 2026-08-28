{ buildNpmPackage, fetchFromGitHub }:

let
  # renovate: datasource=github-releases depName=Doist/todoist-cli
  version = "5.1.2";
in
buildNpmPackage {
  pname = "todoist-cli";
  inherit version;

  src = fetchFromGitHub {
    owner = "Doist";
    repo = "todoist-cli";
    rev = "v${version}";
    hash = "sha256-uGr+V14m8NLG5DnLKM7wMAj9l1XN6hNMmaThQA+09qc=";
  };

  npmDepsHash = "sha256-y8g9P/HPHRG4jjufbfyYsDremuq3GuUAJrmvn6HWV5M=";
}
