# `pkgs/cascp` を手で触るときの環境。.envrc (direnv) と `task cargo` が使う。
# toolchain は inputsFrom で build と同じものにし、手元・CI・derivation で版をずらさない。
# fmt / clippy は derivation に含まれないので足す。RUST_SRC_PATH は nixpkgs の rustc が
# rust-src を同梱せず、rust-analyzer (nvim では mason 管理) が std を引けないため。
{ mkShell, callPackage, rustfmt, clippy, rustPlatform }:

mkShell {
  inputsFrom = [ (callPackage ./package.nix { }) ];
  packages = [ rustfmt clippy ];
  RUST_SRC_PATH = "${rustPlatform.rustLibSrc}";
}
