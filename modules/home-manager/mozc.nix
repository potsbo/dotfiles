# Mozc に anpan (potsbo/anpan) のローマ字テーブルを適用する。
#
# 以前は NixOS の activation が root で ~/.config/mozc に書いていた。それだと
# 新規マシンで home-manager より先に ~/.config が実ディレクトリとしてでき、
# dotfiles.nix の symlink と衝突する。ユーザー側 (home-manager) でやれば順序の問題が消える。
#
# home.file (store への symlink) ではなくコピーなのは、Mozc が設定変更時に
# config1.db を書き換える (rename で置き換える) ため。symlink だと次の activation で
# 「管理外のファイルが在る」と止まる。コピーなら Mozc が上書きでき、次の activation で
# また anpan 版に戻る。
{ config, pkgs, lib, ... }:

let
  anpanRelease = pkgs.fetchzip {
    url = "https://github.com/potsbo/anpan/releases/download/0.1.0/tables-0.1.0.zip";
    sha256 = "sha256-oyfVfoJppTUs0DFgwLStEykjePNnoIsYNng+qLYLJ8Q=";
    stripRoot = true;
  };
  mozcConfigProto = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/google/mozc/2.30.5544.102/src/protocol/config.proto";
    sha256 = "0d6jms4hwhagfdskmgyyijpdbix6rhaxxiq4277zcnflpiv783yg";
  };
  mozcConfigDb = pkgs.runCommand "mozc-config1-db" {
    nativeBuildInputs = [ pkgs.protobuf pkgs.python3 ];
  } ''
    python3 ${./mozc-romantable-to-config.py} ${anpanRelease}/anpan.txt config.textproto
    protoc --proto_path=$(dirname ${mozcConfigProto}) \
      --encode=mozc.config.Config $(basename ${mozcConfigProto}) \
      < config.textproto > $out
  '';
in
{
  # Mozc (fcitx5-mozc) は NixOS 側でしか使っていない。macOS は Google 日本語入力。
  config = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    home.activation.mozcAnpanTable = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run install -D -m 644 ${mozcConfigDb} "${config.home.homeDirectory}/.config/mozc/config1.db"
    '';
  };
}
