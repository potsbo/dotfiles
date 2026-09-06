{ buildGoModule, fetchFromGitHub }:

# release を切っていないので commit hash で固定し、Renovate (git-refs) が digest を進める。
# hash と vendorHash は autofix.ci の nix-update が追従する。version に日付を入れないのは、
# Renovate も nix-update --version=skip も書き換えず、取り残されて嘘になるため。
buildGoModule {
  pname = "tuicast";
  version = "0-unstable";

  src = fetchFromGitHub {
    owner = "potsbo";
    repo = "tuicast";
    # renovate: datasource=git-refs depName=https://github.com/potsbo/tuicast branch=main
    rev ="0d6c5b20f0265968ad0cc7fc29523a600604589c";
    hash = "sha256-ePvQ7lPjWmgMD6jjTwpQ/hbWRVhzju/k5NAZU4Yfr2k=";
  };

  vendorHash = "sha256-g+yaVIx4jxpAQ/+WrGKxhVeliYx7nLQe/zsGpxV4Fn4=";
}
