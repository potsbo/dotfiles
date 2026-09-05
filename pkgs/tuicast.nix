{ buildGoModule, fetchFromGitHub }:

buildGoModule {
  pname = "tuicast";
  version = "0-unstable-2026-08-19";

  src = fetchFromGitHub {
    owner = "potsbo";
    repo = "tuicast";
    rev = "0d6c5b20f0265968ad0cc7fc29523a600604589c";
    hash = "sha256-ePvQ7lPjWmgMD6jjTwpQ/hbWRVhzju/k5NAZU4Yfr2k=";
  };

  vendorHash = "sha256-g+yaVIx4jxpAQ/+WrGKxhVeliYx7nLQe/zsGpxV4Fn4=";
}
