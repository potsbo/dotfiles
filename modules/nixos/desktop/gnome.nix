# GNOME デスクトップ。desktop.environment (modules/nixos/desktop.nix) が "gnome" の
# ときだけ有効になる。別の DE を試すときは specialisation で desktop.environment を
# 差し替え、こちらは自然に外れる。
{ config, pkgs, lib, ... }:

let
  # xremap がフォーカス中のアプリを検出するための GNOME Shell 拡張機能
  # アプリごとに Emacs Ctrl バインドの適用/除外を切り替えるために必要
  xremap-gnome-extension = pkgs.stdenvNoCC.mkDerivation {
    pname = "gnome-shell-extension-xremap";
    # metadata.json の shell-version に現在の GNOME Shell が無いと拡張は
    # "OUT OF DATE" で読み込まれず、xremap の application フィルタが全滅する
    # (`only` は何にも当たらず `not` は何でも通る → ターミナルで Super+V が
    # Ctrl+V になる)。GNOME を上げたら `gnome-extensions info xremap@k0kubun.com`
    # の State を確認し、必要ならここを上げる。
    version = "14";
    src = pkgs.fetchFromGitHub {
      owner = "xremap";
      repo = "xremap-gnome";
      rev = "de79b05989308d717429726dab503e116a141851";
      hash = "sha256-pTTUepxDcAi63k2FmbU7WRb9npkw5YF7UuVEqvZsm1w=";
    };
    installPhase = ''
      mkdir -p $out/share/gnome-shell/extensions/xremap@k0kubun.com
      cp extension.js metadata.json $out/share/gnome-shell/extensions/xremap@k0kubun.com/
    '';
  };
in
{
  config = lib.mkIf (config.desktop.environment == "gnome") {
    services.xserver.enable = true;
    services.displayManager.gdm.enable = true;
    services.desktopManager.gnome.enable = true;

    # GNOME Shell 拡張機能の有効化 & tiling-assistant 設定
    programs.dconf.profiles.user.databases = [{
      settings = {
        "org/gnome/shell" = {
          disable-user-extensions = false;
          enabled-extensions = [
            "xremap@k0kubun.com"
            "tiling-assistant@leleat-on-github"
            "appindicatorsupport@rgcjonas.gmail.com"
            "vicinae@dagimg-dot"
          ];
        };
        "org/gnome/shell/extensions/tiling-assistant" = {
          # スナップ時に反対側のウィンドウ候補を表示しない
          enable-tiling-popup = false;
          # Magnet 風四分割: Ctrl+Option+U/I/J/K → xremap が Super+U/I/J/K に変換
          tile-topleft-quarter = [ "<Super>u" ];
          tile-topright-quarter = [ "<Super>i" ];
          tile-bottomleft-quarter = [ "<Super>j" ];
          tile-bottomright-quarter = [ "<Super>k" ];
        };
        # xremap が Ctrl+Alt+Arrow を横取りするので、GNOME デフォルトのワークスペース
        # 切り替えショートカットを無効化 (Ctrl+Alt+Up/Down/Left/Right の衝突を防ぐ)
        "org/gnome/desktop/wm/keybindings" = let
          noBinding = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        in {
          switch-to-workspace-up = noBinding;
          switch-to-workspace-down = noBinding;
          switch-to-workspace-left = noBinding;
          switch-to-workspace-right = noBinding;
        };
        "org/gnome/desktop/peripherals/touchpad" = {
          speed = 0.5;
          tap-to-click = false;
        };
        "org/gnome/desktop/interface" = {
          font-name = "Noto Sans CJK JP 11";
          document-font-name = "Noto Sans CJK JP 12";
          monospace-font-name = "JetBrains Mono 11";
          font-antialiasing = "grayscale";
          font-hinting = "none";
          show-battery-percentage = true;
        };
        "org/gnome/desktop/wm/preferences" = {
          titlebar-font = "Noto Sans CJK JP Bold 11";
        };
      };
    }];

    environment.systemPackages = with pkgs; [
      xremap-gnome-extension
      gnomeExtensions.tiling-assistant
      gnomeExtensions.appindicator
      gnomeExtensions.vicinae
    ];
  };
}
