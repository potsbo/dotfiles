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
    hash = "sha256-iuKR+7tfetcNauba/euFiyyvUm2p/Ehv4bUHhJRsp3I=";
  };

  npmDepsHash = "sha256-gt7H6S1zInN1FlZhS3mTQnESSeBH84i+L0wdX00HW+s=";
}
