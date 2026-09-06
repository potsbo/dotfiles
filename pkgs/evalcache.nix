{ stdenvNoCC, fetchFromGitHub }:

# nixpkgs に無い zsh plugin なので自前でパッケージ化。
# 配置は nixpkgs の zsh-defer と同じ share/<name>/<name>.plugin.zsh 形式に揃える。
# release が無いので commit hash 固定。追従の仕組みは tuicast.nix と同じ。
stdenvNoCC.mkDerivation {
  pname = "evalcache";
  version = "0-unstable";

  src = fetchFromGitHub {
    owner = "mroth";
    repo = "evalcache";
    # renovate: datasource=git-refs depName=https://github.com/mroth/evalcache branch=master
    rev ="d6973f8c3ecde3eabd75c17b47e2222e24ab3e87";
    hash = "sha256-CN9dnSt9kc5AEkWnbtjyv+DCQZ08Ifmac5wELqve17U=";
  };

  installPhase = ''
    install -Dm644 evalcache.plugin.zsh $out/share/evalcache/evalcache.plugin.zsh
  '';
}
