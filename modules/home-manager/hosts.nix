# flake.nix の hosts 一覧から、シェル側が使うホスト情報を生やす。
#   host-color <host>  ホストに割り当てた色 ("#rrggbb")。zsh の fzf 枠と tuicast の ssh view が使う
#   host-tags  <host>  OS 種別 (nixos / darwin)。tuicast の ssh view が使う
#   ~/.ssh/config      全ホストの Host ブロック。hosts に足せば ssh 先としても勝手に増える
# 短い名前で照合するので "blizzard" も "blizzard.local" も同じ結果になる。
{ pkgs, lib, hosts, defaultColor, ... }:

let
  caseLines = f: lib.concatStringsSep "\n" (lib.mapAttrsToList (name: h: "  ${name}) ${f h} ;;") hosts);

  host-color = pkgs.writeShellScriptBin "host-color" ''
    case "''${1%%.*}" in
    ${caseLines (h: "echo '${h.color}'")}
      *) echo '${defaultColor}' ;;
    esac
  '';

  host-tags = pkgs.writeShellScriptBin "host-tags" ''
    case "''${1%%.*}" in
    ${caseLines (h: "echo ${h.os}")}
    esac
  '';
in
{
  home.packages = [ host-color host-tags ];

  programs.ssh = {
    enable = true;
    # ssh 本体は OS のものを使う。macOS の ssh だけが UseKeychain を知っていて、
    # nix の openssh を PATH に置くとそれが隠れて毎回パスフレーズを聞かれる。
    package = null;
    # home-manager の既定値 (ControlMaster 等) はいらない。書いたものだけ出す。
    enableDefaultConfig = false;
    # 手で足す一時的な設定の置き場。gitignore 済み。
    includes = [ "~/.ssh/config.d/*" ];

    # ~/.ssh/config は nix store への symlink なので手では書けない。開いた人 (人でも
    # エージェントでも) が生成元と逃げ道にたどり着けるよう、先頭に書いておく。
    # home-manager に見出し用の口はないので、コメント行を directive の名前として流す。
    # extraOptionOverrides だけが Include や Host ブロックより前に出る。
    extraOptionOverrides."#" = [
      "このファイルは home-manager が modules/home-manager/hosts.nix から生成している。"
      "nix store への symlink なので手では編集できない。設定を足すならそちらを直して ./install。"
      "このマシンだけの一時的な設定は ~/.ssh/config.d/ に置けば下の Include で読まれる。"
    ];

    settings =
      # Linux ホスト共通: open/xdg-open を手元の Mac で開くための opener 転送。
      # Mac 側は launchd の opener-listen (home.nix) が 2226 を listen。
      # unix socket 転送と違い、短命な ssh 接続が長寿命接続 (herdr) のフォワードを
      # unlink で壊さない。後続の接続は bind に失敗するだけ (警告のみ) で無害。
      # avalanche は ssh を受け付けないが、ブロックがあっても害はないので除外しない。
      lib.mapAttrs
        (_: h: {
          ForwardAgent = true;
          # ここのホストへは Tailscale (100.64.0.0/10) か Cloudflare WARP 経由で入る。
          # どちらも IPv4 なので、AAAA を候補にする理由がない。
          # 一方 graniteridge は素の名前が Tailscale の A に加えて会社側 DNS が返す
          # Cloudflare プロキシの AAAA 2 件にも解決される。ssh は AAAA を先に試すが
          # そこに sshd はいないので、ConnectTimeout を明示する呼び出しでは死んだ
          # 2 件を待ち切ってからでないと Tailscale のアドレスに到達しない。herdr の
          # SSH ブリッジは ConnectTimeout=10 なので 20 秒かかり、その前に接続を諦める
          # (手打ちの ssh は ConnectTimeout 無指定で即座に落ちるので気付かない)。
          # 同じ罠は他のホストにも増えうるので、1 ホストの例外にせず全ホストで IPv4 に絞る。
          # HostName を Tailscale の FQDN に固定しても直るが、Tailscale を使わず
          # WARP だけで入る経路 (hosts/raptorlake/README.md) を塞ぐので採らない。
          AddressFamily = "inet";
        } // lib.optionalAttrs (h.os == "nixos") {
          RemoteForward = [{
            bind = { address = "127.0.0.1"; port = 2226; };
            host = { address = "127.0.0.1"; port = 2226; };
          }];
        })
        hosts
      // {
        "github.com" = {
          User = "git";
          Port = 22;
          HostName = "github.com";
        };

        "*" = {
          IdentityFile = "~/.ssh/id_ed25519";
          # 初回使用時に鍵を agent (macOS では keychain にも) へ入れる。ForwardAgent と
          # 組み合わせると中継ホストに鍵を置かずに使い回せる。IgnoreUnknown は Linux で
          # UseKeychain がエラーにならないため (home-manager がブロック先頭に出す)。
          AddKeysToAgent = true;
          IgnoreUnknown = "UseKeychain";
          UseKeychain = true;
        };
      };
  };
}
