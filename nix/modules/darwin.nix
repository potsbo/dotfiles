{ pkgs, ... }:

{
  nix.enable = false;
  system.primaryUser = "potsbo";

  environment.etc."sudoers.d/potsbo".text = ''
    potsbo ALL=(ALL) NOPASSWD: ALL
  '';

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

  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "uninstall";
      autoUpdate = true;
      upgrade = true;
    };
    taps = [
      "superbrothers/opener"
    ];
    brews = [
      "opener"
    ];
    casks = [
      "akiflow"
      "karabiner-elements"
      "visual-studio-code"
      "google-japanese-ime"
      "raycast"
      "keyboard-cleaner"
      "zoom"
      "dash"
      "docker-desktop"
      "1password"
      "notion"
      "notion-calendar"
      "font-monaspice-nerd-font"
      "tailscale-app"
      "ghostty"
      "cursor"
      "zotero"
    ];
  };

  system.stateVersion = 5;
}
