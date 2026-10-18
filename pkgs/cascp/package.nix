{ lib, rustPlatform, callPackage }:

# desync / rsync / ssh は wrap せず PATH から引く。desync は aqua 管理で、リモート側も
# 同じものを PATH で見つける前提なので、手元だけ nix で固定しても揃わない。
rustPlatform.buildRustPackage {
  pname = "cascp";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [ ./Cargo.toml ./Cargo.lock ./src ];
  };

  cargoLock.lockFile = ./Cargo.lock;

  # e2e テスト用の image。`task e2e` が build する。derivation 本体の build には含めない
  # (docker が要り、sandbox の中では走らせられないため)。
  passthru.e2eImage = callPackage ./e2e-image.nix { };

  meta.mainProgram = "cascp";
}
