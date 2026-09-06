# lazygit の設定。テーマ色を palette.nix から引くために nix 側で生成する。
# lazygit は aqua で入れるので programs.lazygit (package も入れる) は使わず、
# ~/.config/lazygit/config.yml を直接置く。
{ pkgs, palette, ... }:

{
  xdg.configFile."lazygit/config.yml".source = (pkgs.formats.yaml { }).generate "lazygit-config.yml" {
    gui.theme = {
      activeBorderColor = [ palette.purple "bold" ];
      inactiveBorderColor = [ palette.gray ];
      optionsTextColor = [ palette.purple ];
      selectedLineBgColor = [ palette.surface ];
      cherryPickedCommitBgColor = [ palette.surface ];
      cherryPickedCommitFgColor = [ palette.green ];
      unstagedChangesColor = [ palette.red ];
      defaultFgColor = [ palette.white ];
      searchingActiveBorderColor = [ palette.yellow ];
    };
    git = {
      branchPrefix = "potsbo/";
      diffRenderers = [{ colorArg = "always"; command = "hunk pager"; }];
    };
    # SSH セッションでは wl-copy 等が使えないので OSC52 でターミナル経由コピー
    os.copyToClipboardCmd = ''printf "\033]52;c;$(printf {{text}} | base64 -w0)\a" > /dev/tty'';
    keybinding.universal = {
      prevItem-alt = "t";
      nextItem-alt = "h";
      prevBlock-alt = "d";
      nextBlock-alt = "n";
      remove = "j";
      new = "l";
    };
  };
}
