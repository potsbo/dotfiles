# github.com/potsbo/notes を定期的に pull する。
# main 以外を checkout 中や rebase 中は何もしない (ff-only なので壊さない)。
{ config, pkgs, lib, ... }:

let
  notesDir = "${config.home.homeDirectory}/src/github.com/potsbo/notes";

  notesPull = pkgs.writeShellScript "notes-pull" ''
    set -eu
    # fetch の認証は `gh auth git-credential` (git config 済み) に任せる。
    # gh は aqua 管理なので PATH に足す必要がある。
    export PATH="''${XDG_DATA_HOME:-$HOME/.local/share}/aquaproj-aqua/bin:$PATH"
    repo=${notesDir}
    [ -d "$repo/.git" ] || exit 0
    branch=$(${pkgs.git}/bin/git -C "$repo" symbolic-ref --quiet --short HEAD) || exit 0
    [ "$branch" = main ] || exit 0
    exec ${pkgs.git}/bin/git -C "$repo" pull --ff-only
  '';
in
{
  systemd.user = lib.optionalAttrs pkgs.stdenv.isLinux {
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
        OnUnitActiveSec = "15m";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };

  launchd.agents = lib.optionalAttrs pkgs.stdenv.isDarwin {
    notes-pull = {
      enable = true;
      config = {
        ProgramArguments = [ "${notesPull}" ];
        StartInterval = 900;
        RunAtLoad = true;
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/notes-pull.log";
      };
    };
  };
}
