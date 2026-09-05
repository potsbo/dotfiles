{ stdenvNoCC, fetchFromGitHub }:

# nixpkgs に無い zsh plugin なので自前でパッケージ化。
# 配置は nixpkgs の zsh-defer と同じ share/<name>/<name>.plugin.zsh 形式に揃える。
stdenvNoCC.mkDerivation {
  pname = "evalcache";
  version = "0-unstable-2025-11-24";

  src = fetchFromGitHub {
    owner = "mroth";
    repo = "evalcache";
    rev = "d6973f8c3ecde3eabd75c17b47e2222e24ab3e87";
    hash = "sha256-CN9dnSt9kc5AEkWnbtjyv+DCQZ08Ifmac5wELqve17U=";
  };

  installPhase = ''
    install -Dm644 evalcache.plugin.zsh $out/share/evalcache/evalcache.plugin.zsh
  '';
}
