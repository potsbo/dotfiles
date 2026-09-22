# 端末間のファイル共有。各機のデスクトップクライアントが実体を落とし、iPhone は
# 純正アプリから同じものを見る。
#
# Syncthing (P2P、サーバ不要) ではなく Nextcloud を採ったのは iPhone のため。
# 機械どうしを揃えるだけなら Syncthing のほうが軽く、競合にも強く、他のコピーから
# 再生成できない state を持たない。しかし iOS には有料の Möbius Sync しか無く、
# Taildrive は iOS 側の不具合が開いたまま (共有内にディレクトリを作れない、
# 開くとルートに戻る)、WebDAV を直に出しても iOS Files の実装が弱い。
# iPhone をまともに扱えるのはこれだけだった。
#
# 代わりに背負うのが Postgres で、ファイルが無事でも DB を失うと共有・タグ・版が
# 消える。このホストは冗長性を持たない設計 (disk-config.nix) なので、
# 実データを預ける前に restic などで外に逃がす口が要る。まだ無い。
{ config, pkgs, lib, ... }:

let
  # 管理者パスワード。Nix store は world-readable なのでここには書かず、
  # root 0600 で実機に置く。cloudflare-access.nix のトークンと同じ形。
  adminpassFile = "/srv/nextcloud/admin-pass";

  # nginx はループバックでしか待ち受けない。外向きの口と TLS は tailscale serve が持つ。
  # 80 を避けるのは、この番号に他のものが来たときに黙って奪い合わないため。
  backendPort = 8080;
in
{
  services = {
    nextcloud = {
      enable = true;
      # 版は明示する。Nextcloud はメジャーの飛び越しを許さず (30 → 32 は不可)、
      # nixpkgs は EOL になった版を消す。既定は system.stateVersion (25.11) から
      # 決まるので 31 になるが、それは「25.11 の頃から居る instance」の想定であって、
      # 新規に建てるここでは最新を入れるのが正しい。以後 33 → 34 と 1つずつ上げる。
      package = pkgs.nextcloud34;

      # nginx の vhost 名になる。tailnet の FQDN を書かないのは、ここが公開リポジトリで
      # tailnet 名を載せる必然性がないため。実際に届く名前は trusted_domains 側で受ける。
      hostName = "raptorlake";

      # 生成するリンクを https にする。TLS を終端するのは tailscale serve なので、
      # nginx から見た接続は平文のループバックであり、これを立てないと
      # Nextcloud が http のリンクを撒いてクライアントが混在コンテンツで転ぶ。
      https = true;

      # sqlite は同時アクセスで詰まる。mysql との差は運用上ほぼ無いが、
      # このリポジトリで他に DB を持っていないので素直なほうを選ぶ。
      database.createLocally = true;
      config = {
        dbtype = "pgsql";
        adminuser = "potsbo";
        inherit adminpassFile;
      };

      # ファイルロックを Redis に持たせる。DB ロックのままだと、大きいディレクトリを
      # 複数クライアントが同時に触ったときにロックが残って "file is locked" で止まる。
      configureRedis = true;

      # これは php の memory_limit も同じ値に引き上げる (module が連動させている)。
      # 上限であって確保ではないので 4G でも実害は無いが、青天井にはしない。
      maxUploadSize = "4G";

      settings = {
        # 実際に届く Host は raptorlake.<tailnet>.ts.net。tailnet 名を書かずに受けるため
        # ワイルドカードにしている。到達経路が tailscale serve だけである以上、
        # ここを広く取っても届く相手は増えない。
        trusted_domains = [ "*.ts.net" ];

        # 電話番号の既定の国。無いと管理画面が設定不足として警告を出し続ける。
        default_phone_region = "JP";
        # 重い定期ジョブを回す時間帯 (UTC の時)。18 UTC = 深夜 3 時。同じく未設定だと警告。
        maintenance_window_start = 18;
      };
    };

    # postgres に TCP を持たせない。Nextcloud は unix socket (/run/postgresql) で
    # 繋ぐので、TCP を要る者が居ない。既定のまま 5432 を握らせると、このホストで
    # 動いている docker の postgres (0.0.0.0:5432 を publish している) と衝突して
    # "could not create any TCP/IP sockets" で起動に失敗する。実際に踏んだ。
    # ポートをずらす手もあるが、ずらした先がまた別のコンテナと当たる。
    # module 側が "localhost" を素の定義として置いているので mkForce が要る。
    postgresql.settings.listen_addresses = lib.mkForce "";

    # nginx をループバックに縛る。firewall に穴を開けないので、tailnet からも
    # 直接は届かない。入口は下の tailscale serve だけになる。
    nginx.virtualHosts.raptorlake.listen = [
      {
        addr = "127.0.0.1";
        port = backendPort;
      }
    ];
  };

  systemd = {
    tmpfiles.rules = [
      "d /srv/nextcloud 0700 root root -"
    ];

    services = {
      # パスワードを置くまでは setup を走らせない。置き忘れたまま rebuild しても
      # switch は通り、unit が条件待ちで止まっているだけになる (cloudflared と同じ形)。
      nextcloud-setup.unitConfig.ConditionPathExists = adminpassFile;

      # tailnet に出す口。tailscale serve が MagicDNS 名で本物の証明書を取り、
      # 443 を上の backendPort に中継する。
      #
      # nginx を直接 tailscale0 に出して自前で証明書を取る手もあるが、それだと
      # 証明書の更新を acme なり tailscale cert なりで別途回すことになる。
      # serve なら tailscaled が持っているものをそのまま使う。
      #
      # --bg の設定は tailscaled の state に永続するので毎回打つ必要はないが、
      # unit にしておけばホストを作り直しても宣言から戻る。
      tailscale-serve-nextcloud = {
        description = "Expose Nextcloud on the tailnet via Tailscale Serve";
        after = [ "tailscaled.service" "nginx.service" ];
        requires = [ "tailscaled.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg ${toString backendPort}";
          # 起動直後は tailscaled がまだ認証を終えていないことがある。
          Restart = "on-failure";
          RestartSec = "10s";
        };
        # 恒常的な失敗でも諦めさせない (cloudflared と同じ理由)。
        unitConfig.StartLimitIntervalSec = 0;
      };

      # Nextcloud が「自分を指す URL」として使う値を入れる。
      #
      # 実行時に tailscaled から引くのは、これが tailnet の FQDN でなければならず、
      # かつその名前を公開リポジトリに書きたくないため。AWS の profile 名を
      # 実行時ファイルから引いているのと同じ理由 (CLAUDE.md の「Personal identifiers」)。
      #
      # 無くても同期は動くが、管理画面のセットアップチェックが自分自身に接続できず
      # (WebDAV の疎通、データディレクトリの保護、.mjs の MIME 型) 「確認できません
      # でした」を出し続ける。警告が常に出ている状態にすると、本物の警告が埋もれる。
      nextcloud-tailnet-url = {
        description = "Point Nextcloud's overwrite.cli.url at this node's MagicDNS name";
        after = [ "nextcloud-setup.service" "tailscaled.service" ];
        requires = [ "nextcloud-setup.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "nextcloud";
          # tailscaled が認証を終えるまで DNSName が空で返る。
          Restart = "on-failure";
          RestartSec = "10s";
        };
        script = ''
          fqdn=$(${pkgs.tailscale}/bin/tailscale status --json \
            | ${lib.getExe pkgs.jq} -r '.Self.DNSName' | sed 's/\.$//')
          case "$fqdn" in
            ""|null) echo "tailscale has no MagicDNS name yet" >&2; exit 1 ;;
          esac
          ${lib.getExe config.services.nextcloud.occ} \
            config:system:set overwrite.cli.url --value="https://$fqdn"
        '';
        unitConfig.StartLimitIntervalSec = 0;
      };
    };
  };
}
