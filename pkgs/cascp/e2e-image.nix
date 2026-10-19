# e2e テスト (tests/e2e.rs) でリモート役を務める image。中身は cascp がリモートに要求する
# ものだけにする: sshd、POSIX sh と script が使う基本コマンド、desync、rsync。
#
# 基本コマンドは、使う applet とオプションだけを有効にした busybox で入れる。/bin に並ぶのは
# 下の extraConfig で有効にしたものだけなので、script が新しいコマンドやオプションを使い
# 始めたら、ここに足すまで e2e が落ちる。この一覧がリモートの要件の正になる。
# 普通のマシンには coreutils が揃っているので、実用上ここまで絞る必要は無い。要件を
# 書き出しておくためにやっている。
#
# 鍵は image に焼かず、起動時に受け取る (AUTHORIZED_KEY)。ホスト鍵も起動のたびに作るので、
# テストの ssh_config では known_hosts を見ない。
{ dockerTools, buildEnv, writeText, writeScript, busybox, desync, rsync, openssh }:

let
  # allnoconfig から始めるので、applet の下のオプション (stat の -c など) も既定値では
  # 入らない。使うものは明示的に有効にする。名前は busybox のソースの `//config:config` に
  # ある。この文字列は nixpkgs 側で引用符なしのヒアドキュメントに流し込まれるので、`$` を書くと
  # シェルに展開される。値と同じ行にコメントを書くと値として読まれるので、コメントは別の行に置く。
  minimalBusybox = busybox.override {
    enableMinimal = true;
    extraConfig = ''
      # sh: script を走らせ、sshd のログインシェルにもなる
      CONFIG_ASH y
      CONFIG_SH_IS_ASH y
      # 算術展開 (INSPECT の大きさの計算)
      CONFIG_FEATURE_SH_MATH y
      CONFIG_ASH_PRINTF y
      CONFIG_ASH_ECHO y
      # [ ... ]
      CONFIG_ASH_TEST y

      # cascp の script (src/script.rs) が使うもの
      # PRELUDE
      CONFIG_MKDIR y
      # INSPECT (mode)、SIZES。-c で書式を指定する
      CONFIG_STAT y
      CONFIG_FEATURE_STAT_FORMAT y
      # INSPECT (大きさとファイル数。表示だけに使う)
      CONFIG_DU y
      CONFIG_CUT y
      CONFIG_FIND y
      CONFIG_FEATURE_FIND_TYPE y
      CONFIG_WC y
      # SIZES、TOUCH。一覧を NUL 区切りにして xargs -0 に渡す
      CONFIG_TR y
      CONFIG_XARGS y
      CONFIG_FEATURE_XARGS_SUPPORT_ZERO_TERM y
      # TOUCH
      CONFIG_TOUCH y
      # ASSEMBLE (と entrypoint)
      CONFIG_CHMOD y

      # e2e テスト自身が準備と確認に使うもの。cascp の要件ではない
      # head -c
      CONFIG_HEAD y
      CONFIG_FEATURE_FANCY_HEAD y
      CONFIG_CAT y
      # symlink を含む木 (regress/scp.sh の forest) を作る
      CONFIG_LN y
    '';
  };

  sshdConfig = writeText "sshd_config" ''
    Port 22
    HostKey /etc/ssh/ssh_host_ed25519_key
    PermitRootLogin prohibit-password
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    AuthorizedKeysFile /root/.ssh/authorized_keys
    PidFile none
    # sshd の既定の PATH は /usr/bin などで、この image のコマンドは /bin にしか無い
    SetEnv PATH=/bin
  '';

  entrypoint = writeScript "cascp-e2e-entrypoint" ''
    #!${minimalBusybox}/bin/sh
    set -e
    printf '%s\n' "$AUTHORIZED_KEY" > /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    ${openssh}/bin/ssh-keygen -q -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key
    exec ${openssh}/bin/sshd -D -e -f ${sshdConfig}
  '';
in
dockerTools.buildLayeredImage {
  name = "cascp-e2e";
  tag = "latest";

  contents = buildEnv {
    name = "cascp-e2e-root";
    paths = [ minimalBusybox desync rsync openssh ];
    pathsToLink = [ "/bin" ];
  };

  # /etc などは store への symlink だと書けないので、実体のディレクトリとして作る。
  # sshd は privsep 用の sshd ユーザーと /var/empty が無いと起動しない。
  # ここは image を作る側の sh で走るので、busybox の applet の制限は受けない。
  extraCommands = ''
    mkdir -p etc/ssh root/.ssh var/empty tmp
    chmod 700 root root/.ssh
    chmod 1777 tmp
    printf '%s\n' 'root:x:0:0:root:/root:/bin/sh' 'sshd:x:74:74:sshd:/var/empty:/bin/false' > etc/passwd
    printf '%s\n' 'root:x:0:' 'sshd:x:74:' > etc/group
  '';

  config = {
    Entrypoint = [ entrypoint ];
    ExposedPorts."22/tcp" = { };
  };
}
