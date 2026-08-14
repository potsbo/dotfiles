{ buildGoModule, fetchFromGitHub }:

buildGoModule {
  pname = "tuicast";
  version = "0-unstable-2026-06-27";

  src = fetchFromGitHub {
    owner = "potsbo";
    repo = "tuicast";
    rev = "0551c8932de61f83014e42a78ecaf184a3e4b378";
    hash = "sha256-VBYaJOa+mZu2kaXeb1gQaS3t1wF72WTif3SNPB0gbFY=";
  };

  vendorHash = "sha256-g+yaVIx4jxpAQ/+WrGKxhVeliYx7nLQe/zsGpxV4Fn4=";
}
