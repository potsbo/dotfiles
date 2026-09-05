{ lib, ... }:

{
  # ============================================================
  # メモリ枯渇耐性 (最小構成)
  #
  # 方針: 重いジョブ (Python データ分析等) が RAM+swap を食い尽くしても、
  #   kernel / sshd / tailscaled には必ずメモリを残し、
  #   「ssh で入って暴走プロセスを kill する」余力を確保する。
  # 過去事例: ユーザランドの Python ジョブがメモリを食い尽くし、
  #   新規接続を捌くメモリすら確保できず全応答停止 → 物理再起動が必要に。
  #
  # 注意: ここでは swap 構成やユーザジョブの上限には手を入れない。
  #   暴走時はディスクスワップ thrash で「重く」はなるが、救命線のメモリ予約で
  #   ssh 経由の救出はできる状態を保つ、という割り切り。
  #   「重さ」自体も消したい場合は別途 zram 化 / user.slice 上限を検討する。
  # ============================================================

  # --- カーネルの予約 ---
  # min_free_kbytes: カーネルが常に確保しておく空きページ。ネットワーク受信など
  #   割り込み内の atomic 確保に使われ、逼迫時も tailscale/ssh のパケットを捌ける。
  # admin_reserve_kbytes: OOM 寸前でも root が復旧コマンド (ps/kill) を実行できる予約。
  boot.kernel.sysctl = {
    "vm.min_free_kbytes" = 262144;      # 256MiB
    "vm.admin_reserve_kbytes" = 262144; # 256MiB
  };

  # --- 救命線へのメモリ予約 ---
  # system.slice 全体 + sshd/tailscaled 個別に memory.min を与え、逼迫時も
  # カーネルがこれらのページを回収 (swap-out/破棄) しないようにしている。
  #
  # 注意: sshd に systemd の OOMScoreAdjust を設定してはいけない。
  #   oom_score_adj は fork で継承されるため、SSH セッション配下の全プロセス
  #   (shell → claude → python ジョブ...) にまで -900 が伝播し、
  #   暴走したユーザジョブが OOM killer から保護されてしまう。
  #   2026-07-10 の障害はこれが原因: python ジョブ 82 個 (RSS 27GB + swap 全食い)
  #   が -900 で殺せず、代わりに NetworkManager が OOM kill →
  #   restart も OOM kill × 5 で start-limit 到達 → NM 永久停止 →
  #   リンクフラップでルート消失 → 沈黙、物理再起動が必要になった。
  #   sshd 自身は Linux では自力で listener を -1000 にし、セッションには
  #   起動時の値 (=0) を復元するので、systemd 側では何も設定しないのが正解。
  systemd.slices."system".sliceConfig.MemoryMin = "512M";
  systemd.services.sshd.serviceConfig.MemoryMin = "32M";
  systemd.services."sshd@".serviceConfig.MemoryMin = "32M";
  systemd.services.tailscaled.serviceConfig = {
    OOMScoreAdjust = -900;
    MemoryMin = "128M";
  };

  # --- NetworkManager: OOM 保護 + 無限リトライ ---
  # NM は new connection を捌く sshd/tailscaled と同格の救命線。
  # NM が死んで DHCP 更新・リンクフラップ後のルート再設定が行われないと、
  # sshd/tailscaled が生きていても外から到達不能になる。
  systemd.services.NetworkManager = {
    # デフォルトの StartLimitBurst=5/10s は OOM 嵐の中で一瞬で使い切り
    # 「Start request repeated too quickly」で永久停止する。無限にリトライさせる。
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig = {
      Restart = lib.mkForce "always";
      RestartSec = "5s";
      OOMScoreAdjust = -900; # NM はユーザプロセスを spawn しないので継承問題なし
      MemoryMin = "32M";
    };
  };
  # NM の再起動には dbus が必要なので dbus も保護
  systemd.services.dbus.serviceConfig.OOMScoreAdjust = -900;

  # --- earlyoom: カーネル OOM killer 発動前にプロアクティブに kill (バックストップ) ---
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 5;
    extraArgs = [
      "--avoid" "^(sshd|tailscaled|systemd|NetworkManager|dbus)"
      # 過去の障害は毎回 python のデータジョブがメモリを食い尽くしている。
      # 逼迫時はまず python を殺す (ジョブは失敗するがマシンは守る)。
      "--prefer" "^python3"
    ];
  };
}
