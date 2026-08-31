# github.com/potsbo/notes を Claude Code の Remote Control server として常駐させ、
# スマホ / claude.ai からセッションを生やせるようにする。
#
# `claude --remote-control` (対話セッションに RC を後付けする方) ではなく
# `claude remote-control` (server mode) を使う。前者は 1 プロセス 1 セッションで、
# リモート側からは既にあるセッションに話しかけることしかできない。
{ config, pkgs, lib, dotfilesPath, ... }:

let
  notesDir = "${config.home.homeDirectory}/src/github.com/potsbo/notes";

  notesRemoteControl = pkgs.writeShellScript "notes-remote-control" ''
    set -eu
    # claude は aqua 管理なので PATH に足す。aqua は設定の在り処を
    # AQUA_GLOBAL_CONFIG から知るため、これも渡さないと shim が
    # "command is not found" で落ちる (systemd user unit にはログインシェルの
    # 環境が入っていないので、対話シェルでは再現しない)。
    export PATH="''${XDG_DATA_HOME:-$HOME/.local/share}/aquaproj-aqua/bin:$PATH"
    export AQUA_GLOBAL_CONFIG=${dotfilesPath}/home/.config/aquaproj-aqua/aqua.yaml
    export AQUA_POLICY_CONFIG=${dotfilesPath}/home/.config/aquaproj-aqua/aqua-policy.yaml
    cd ${notesDir}
    # --spawn は既定の same-dir のまま。notes は markdown なので複数セッションが
    # 同じ作業ツリーを触っても壊れにくく、worktree を切ると Obsidian から見える
    # 実体と別の場所を編集することになって困る。
    # セッション名は既定の接頭辞 (ホスト名) に任せる。複数のマシンで常駐させる
    # ので、どのマシンのセッションか一覧で見分けられる方がよい。
    exec claude remote-control
  '';
in
{
  systemd.user = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    services.notes-remote-control = {
      Unit.Description = "Claude Code Remote Control server for potsbo/notes";
      Service = {
        ExecStart = "${notesRemoteControl}";
        # server mode はネットワークが 10 分ほど届かないとプロセスごと exit する
        # (対話モードと違って自力では復帰しない)。スリープ復帰や Wi-Fi 瞬断で
        # 黙って死ぬので、落ちたら上げ直す前提で組む。
        Restart = "always";
        RestartSec = "30s";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };

  launchd.agents = lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
    notes-remote-control = {
      enable = true;
      config = {
        ProgramArguments = [ "${notesRemoteControl}" ];
        RunAtLoad = true;
        KeepAlive = true;
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/notes-remote-control.log";
      };
    };
  };
}
