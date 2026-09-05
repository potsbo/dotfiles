{ pkgs, ... }:

{
  # 認証鍵は毎回 GitHub から引く。静的な authorized_keys は意図的に置いていない。
  # GitHub 側で鍵を消したら即座に全ホストから締め出したいので、失効の反映速度を
  # 可用性より優先する。静的鍵はまさに「消しても残る鍵」なので目的に反する。
  #
  # 代償として、名前解決か外向き通信が死ぬと sshd が正常でもログインできない。
  # モニタ未接続のヘッドレス機 (phoenix) ではこれが現地作業を意味するため、
  # 再起動を伴う変更では bootCounting 等で別途保険をかけること。
  #
  # curl が 1 回失敗しただけで鍵は拒否される (sshd がこの command を見るのは
  # authorized_keys と証明書 CA の後で、どちらにも何も置いていない)。だから上限時間は
  # 「遅いだけの回線では通り、詰まった回線では待たされない」ところを狙う。この待ちは
  # クライアントが出す鍵 1 本ごとに乗り MaxAuthTries (既定 6) 回まで繰り返されるので、
  # 合計が LoginGraceTime (既定 120 秒) を超えると鍵が正しくても接続ごと切られる。
  # 6 回 × 10 秒ならその内側に収まる。
  #
  # 失敗時は curl の stderr が sshd に捨てられるので、原因は journal に出る終了コード
  # ("AuthorizedKeysCommand ... failed, status N") で切り分ける。
  environment.etc."ssh/gh-authorized-keys".text = ''
    #!/bin/sh
    exec ${pkgs.curl}/bin/curl -fsSL --connect-timeout 5 --max-time 10 "https://github.com/$1.keys"
  '';
  environment.etc."ssh/gh-authorized-keys".mode = "0555";
  environment.etc."ssh/gh-authorized-keys".user = "root";
  environment.etc."ssh/gh-authorized-keys".group = "root";

  services.openssh = {
    enable = true;
    settings = {
      PubkeyAuthentication = true;
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      StreamLocalBindUnlink = true;

      AuthorizedKeysCommand = "/etc/ssh/gh-authorized-keys %u";
      AuthorizedKeysCommandUser = "nobody";

      # Mosh アプリ等 etm 非対応の SSH クライアント向けに etm なしの MAC も許可
      Macs = [
        "hmac-sha2-512-etm@openssh.com"
        "hmac-sha2-256-etm@openssh.com"
        "umac-128-etm@openssh.com"
        "hmac-sha2-512"
        "hmac-sha2-256"
      ];
    };
  };
}
