{ buildNpmPackage, fetchFromGitHub }:

let
  # renovate: datasource=github-releases depName=Doist/todoist-cli
  version = "3.3.1";
in
buildNpmPackage {
  pname = "todoist-cli";
  inherit version;

  src = fetchFromGitHub {
    owner = "Doist";
    repo = "todoist-cli";
    rev = "v${version}";
    hash = "sha256-JtEidrFolaGxf/fSKGgLgPdlBlmhpNl9BvOz0zhDIts=";
  };

  npmDepsHash = "sha256-dyPBS4EmmLR0P7MrstXWHD2mB6ROTIOUcBPotiL0EXQ=";
}
