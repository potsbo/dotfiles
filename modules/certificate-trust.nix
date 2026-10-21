{
  # eMudhra の中間 CA 秘密鍵侵害 (CVE-2026-111943) への対処。
  # 失効確認をしない TLS client も守るため、cross-sign を含む信頼元を除外する。
  # 正常な証明書でもこの CA 群に依存するサイトは接続できなくなる。
  # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/security/ca.nix
  # 対象は OS の CA バンドル。macOS Keychain やアプリ内蔵ストアは各自の更新が必要。
  security.pki.caCertificateBlacklist = [
    "Comodo AAA Services root"
    "emSign ECC Root CA - G3"
    "emSign Root CA - C1"
    "emSign ECC Root CA - C3"
  ];
}
