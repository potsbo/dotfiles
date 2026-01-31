{ pkgs, ... }:

{
  nix.enable = false;
  system.primaryUser = "potsbo";

  system.defaults = {
    dock.autohide = true;

    NSGlobalDomain = {
      KeyRepeat = 1;
      InitialKeyRepeat = 15;
    };

    trackpad.Clicking = true;

    CustomUserPreferences = {
      ".GlobalPreferences" = {
        "com.apple.trackpad.scaling" = 2;
      };
    };
  };

  system.stateVersion = 5;
}
