# `pkgs/cascp` を手で触るときの環境。.envrc (direnv) と Taskfile.yml の task が使う。
# toolchain は inputsFrom で build と同じものにし、手元・CI・derivation で版をずらさない。
# fmt / clippy / bacon (test の watch) は derivation に含まれないので足す。RUST_SRC_PATH は nixpkgs の rustc が
# rust-src を同梱せず、rust-analyzer (nvim では mason 管理) が std を引けないため。
# desync / rsync は cascp が手元で呼ぶもの (`cargo run` と e2e テスト用)。ふだんの desync は aqua
# 管理だが、ここでは e2e の image (e2e-image.nix) と同じ nixpkgs の版に揃える。
{ mkShell, callPackage, rustfmt, clippy, bacon, desync, rsync, rustPlatform }:

mkShell {
  inputsFrom = [ (callPackage ./package.nix { }) ];
  packages = [ rustfmt clippy bacon desync rsync ];
  RUST_SRC_PATH = "${rustPlatform.rustLibSrc}";
}
