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
    rev ="7479c02bb524801bb898f7447ea14fd4f5478fa9";
    hash = "sha256-o8x/dw+wZPhE+VFrV4Zh6xONTqXIcktvNWBxnkrQOXY=";
  };

  installPhase = ''
    install -Dm644 evalcache.plugin.zsh $out/share/evalcache/evalcache.plugin.zsh
  '';
}
