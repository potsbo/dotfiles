# flake.nix の hosts 一覧から、シェル側が使うホスト情報コマンドを生やす。
#   host-color <host>  ホストに割り当てた色 ("#rrggbb")。zsh の fzf 枠と tuicast の ssh view が使う
#   host-tags  <host>  OS 種別 (nixos / darwin)。tuicast の ssh view が使う
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
}
