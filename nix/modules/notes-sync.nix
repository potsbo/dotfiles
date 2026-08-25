# github.com/potsbo/notes を定期的に pull する。
# main 以外を checkout 中や rebase 中は何もしない (ff-only なので壊さない)。
{ config, pkgs, lib, dotfilesPath, ... }:

let
  notesDir = "${config.home.homeDirectory}/src/github.com/potsbo/notes";

  notesPull = pkgs.writeShellScript "notes-pull" ''
    set -eu
    # fetch の認証は `gh auth git-credential` (git config 済み) に任せる。
    # gh は aqua 管理なので PATH に足す。さらに aqua は設定の在り処を
    # AQUA_GLOBAL_CONFIG から知るため、これも渡さないと shim が
    # "command is not found" で落ちる (systemd user unit にはログインシェルの
    # 環境が入っていないので、対話シェルでは再現しない)。
    export PATH="''${XDG_DATA_HOME:-$HOME/.local/share}/aquaproj-aqua/bin:$PATH"
    export AQUA_GLOBAL_CONFIG=${dotfilesPath}/home/.config/aquaproj-aqua/aqua.yaml
    export AQUA_POLICY_CONFIG=${dotfilesPath}/home/.config/aquaproj-aqua/aqua-policy.yaml
    repo=${notesDir}
    [ -d "$repo/.git" ] || exit 0
    branch=$(${pkgs.git}/bin/git -C "$repo" symbolic-ref --quiet --short HEAD) || exit 0
    [ "$branch" = main ] || exit 0
    exec ${pkgs.git}/bin/git -C "$repo" pull --ff-only
  '';
in
{
  systemd.user = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    services.notes-pull = {
      Unit.Description = "Pull potsbo/notes if on main";
      Service = {
        Type = "oneshot";
        ExecStart = "${notesPull}";
      };
    };
    timers.notes-pull = {
      Unit.Description = "Periodically pull potsbo/notes";
      Timer = {
        OnBootSec = "2m";
        OnUnitActiveSec = "5m";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };

  launchd.agents = lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
    notes-pull = {
      enable = true;
      config = {
        ProgramArguments = [ "${notesPull}" ];
        StartInterval = 300;
        RunAtLoad = true;
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/notes-pull.log";
      };
    };
  };
}
