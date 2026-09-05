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

    settings =
      # Linux ホスト共通: open/xdg-open を手元の Mac で開くための opener 転送。
      # Mac 側は launchd の opener-listen (home.nix) が 2226 を listen。
      # unix socket 転送と違い、短命な ssh 接続が長寿命接続 (herdr) のフォワードを
      # unlink で壊さない。後続の接続は bind に失敗するだけ (警告のみ) で無害。
      # avalanche は ssh を受け付けないが、ブロックがあっても害はないので除外しない。
      lib.mapAttrs
        (_: h: {
          ForwardAgent = true;
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
