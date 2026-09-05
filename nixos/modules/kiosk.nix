{ config, pkgs, lib, ... }:

# RDP キオスク (PoC): 電源 ON → ユーザー操作ゼロで Windows デスクトップ表示まで到達させる。
# specialisation として読み込む前提 (ベース構成の上に被せ、ブートメニューで選ぶ)。
#
# --- 手動配置するファイル (どれも root:root 0600、リポジトリ外) ---
#
#   /var/lib/kiosk/rdp-credentials
#     xfreerdp の引数を 1 行 1 引数で書く。/args-from 経由で渡すので、値に空白や
#     記号があってもそのまま書ける (シェルのクォート不要)。
#       /u:USERNAME
#       /p:PASSWORD
#     ドメインユーザーなら /d:DOMAIN を 1 行足す。
#
#   /var/lib/kiosk/tailscale-authkey
#     タグ付き auth key を 1 行。既に tailscaled の state (/var/lib/tailscale) が
#     Running なら読まれない (NeedsLogin / Stopped のときだけ `tailscale up` に使う)。
#     このマシンは通常構成で既にログイン済みなので、いまの PoC ではそちらの node
#     identity をそのまま使い、この鍵は state を消したときの保険になる。
#
#   例:
#     sudo install -d -m 0700 -o root -g root /var/lib/kiosk
#     sudo install -m 0600 -o root -g root /dev/stdin /var/lib/kiosk/rdp-credentials <<'EOT'
#     /u:USERNAME
#     /p:PASSWORD
#     EOT
#     sudo install -m 0600 -o root -g root /dev/stdin /var/lib/kiosk/tailscale-authkey <<<'tskey-auth-...'

let
  # MagicDNS で解決する (resolved に 100.100.100.100 が入る)。IP 固定より名前で追従させる。
  rdpHost = "raptorlake-win";

  credentialsFile = "/var/lib/kiosk/rdp-credentials";
  tailscaleAuthKeyFile = "/var/lib/kiosk/tailscale-authkey";

  # 資格情報は cage-tty1 の LoadCredential= で $CREDENTIALS_DIRECTORY に届く。
  # root:0600 のファイルを、非特権の kiosk ユーザーがそのサービス内でだけ読める
  # 標準の仕組みで、Nix 式 (= 全ユーザー可読の /nix/store) には何も入らない。
  #
  # xfreerdp の /args-from は他の引数と併用できない (3.30 で実測)。そのため全引数を
  # stdin に流す。/p: をコマンドラインに載せないので /proc/<pid>/cmdline にも出ない。
  #
  # 別の端末が同じ Windows に RDP すると、こちらのセッションは「別接続に置き換え」で
  # 切られる (xfreerdp の終了コード 5 = ERRINFO_DISCONNECTED_BY_OTHER_CONNECTION)。
  # そこで即再接続すると相手を蹴り返す往復になるので、この場合だけは再接続せず、
  # キオスク側でキーが押されるまで待つ。サインアウトやネットワーク断は従来どおり
  # 即再接続 (systemd の Restart に任せる)。
  rdpKiosk = pkgs.writeShellApplication {
    name = "rdp-kiosk";
    runtimeInputs = [ pkgs.freerdp pkgs.xterm ];
    text = ''
      cred="''${CREDENTIALS_DIRECTORY:?}/rdp-credentials"
      set +o errexit
      {
        # /f は DesktopWidth/Height をモニタ実サイズ (この機体は 2304x1440) で上書きする
        # (xf_pre_connect: SmartSizing が無いときだけ)。/size を活かして 1920x1080 の
        # セッションを全画面に拡縮するには /smart-sizing が要る。
        printf '%s\n' \
          "/v:${rdpHost}" \
          /f \
          /size:1920x1080 \
          /smart-sizing \
          /gfx:AVC444 \
          /cert:tofu \
          +auto-reconnect \
          -toggle-fullscreen \
          /log-level:INFO
        cat "$cred"
      } | xfreerdp /args-from:stdin
      rc=$?
      set -o errexit

      if [ "$rc" -eq 5 ]; then
        xterm -fa Monospace -fs 20 -bg black -fg white -e bash -c '
          echo; echo "  Session taken over by another client."
          echo "  Press any key to reconnect."
          read -rsn1'
      fi
      exit "$rc"
    '';
  };
in
{
  # ブートメニュー上の表示名
  system.nixos.tags = [ "kiosk" ];

  # GNOME/GDM は tty1 と DRM を取り合うので kiosk 側では止める。X も不要
  # (xfreerdp は cage の Xwayland 上で動く)。
  services.xserver.enable = lib.mkForce false;
  services.displayManager.gdm.enable = lib.mkForce false;
  services.desktopManager.gnome.enable = lib.mkForce false;

  users.users.kiosk = {
    isNormalUser = true;
    description = "RDP kiosk";
    # パスワードは置かない。cage は PAMName= 経由で systemd がセッションを開くだけで
    # 認証はしないので不要。seat/DRM/input の権限は logind セッションから得るため
    # video/input グループも不要。
  };

  services.cage = {
    enable = true;
    user = "kiosk";
    program = lib.getExe rdpKiosk;
    # 既定では VT 切替を禁止する。Ctrl+Alt+F2 で tty2 に出るために許可する。
    extraArguments = [ "-s" ];
    environment.XKB_DEFAULT_LAYOUT = "us";
  };

  # xremap は potsbo のユーザーサービスだが linger で GNOME 終了後も生き残り、
  # キーボードを grab したまま Ctrl 単押し→Esc などを RDP に流してしまう。
  # GNOME 拡張が無い環境ではアプリ単位の除外 (xfreerdp) も効かない。
  services.xremap.enable = lib.mkForce false;

  systemd.services.cage-tty1 = {
    # Tailscale が Running になってから繋ぎに行く。失敗しても起動自体は止めない
    # (after のみ) — その場合は下の Restart ループで追いつく。
    after = [ "tailscaled-autoconnect.service" ];
    serviceConfig = {
      LoadCredential = [ "rdp-credentials:${credentialsFile}" ];
      # 切断・Windows 側サインアウト・xfreerdp 異常終了からの自動復帰
      Restart = "always";
      RestartSec = 3;
    };
    # 既定の StartLimitBurst=5/10s だと、Windows 側が落ちている間に 3 秒間隔の再起動が
    # 上限に当たって cage が永久停止する。無制限にしておく。
    unitConfig.StartLimitIntervalSec = 0;
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/kiosk 0700 root root -"
  ];

  # 無人認証。tailscaled 自体はシステムサービスで NetworkManager にしか依存せず、
  # Wi-Fi 接続も system 接続 (permissions 空、psk-flags=0) なので、誰もログイン
  # しなくても接続が立つ。tailscaled-autoconnect は Running を見届けるまで待つ。
  services.tailscale.authKeyFile = tailscaleAuthKeyFile;

  # スリープ・休止を丸ごと無効化 (蓋閉じ・アイドルを含む)
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };
  # laptop.nix が suspend にしているのを上書き
  services.logind.settings.Login = {
    HandleLidSwitch = lib.mkForce "ignore";
    HandleLidSwitchExternalPower = lib.mkForce "ignore";
    HandleLidSwitchDocked = lib.mkForce "ignore";
    IdleAction = "ignore";
  };
  # 画面消灯: cage/wlroots は自前でアイドル消灯しないので、ここでは何もしない。

  # tty2 の getty は非常口 (SSH が死んだときの現地ログイン)。logind の autovt でも
  # VT 切替時に立つが、常駐させて確実にしておく。cage 側で Ctrl+Alt+F2 が VT 切替に
  # なるので、その操作だけはローカルで食われる (意図した非常口)。
  systemd.services."getty@tty2" = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
  };

  # SSH は common.nix で有効 (鍵は GitHub から取得)。
}
