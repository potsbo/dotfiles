# lazygit の設定。テーマ色を palette.nix から引くために nix 側で生成する。
# lazygit は aqua で入れるので programs.lazygit (package も入れる) は使わず、
# ~/.config/lazygit/config.yml を直接置く。
{ pkgs, palette, ... }:

{
  xdg.configFile."lazygit/config.yml" = {
    # lazygit は config.yml が無いと起動時に空ファイルを作る。この設定を当てる前に
    # 一度でも lazygit を起動するとその空ファイルが残り、activation が "Existing file
    # would be clobbered" で止まる (2026-09-06 phoenix)。中身は常に nix 側が正なので上書きする。
    force = true;
    source = (pkgs.formats.yaml { }).generate "lazygit-config.yml" {
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
  };
}
