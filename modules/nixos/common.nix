# 全 NixOS ホスト共通の土台。関心ごとの設定は同階層のモジュールに分けてあり、
# ここからまとめて import する。常時稼働かラップトップかは flake.nix の hosts で決まる。
{ config, pkgs, lib, ... }:

{
  imports = [
    ./ssh.nix
    ./network.nix
    ./oom-resilience.nix
    ./docker.nix
    ./desktop.nix
    ./server.nix
    ./laptop.nix
  ];

  # flake.nix の hosts から渡る性質。server.nix / laptop.nix がこれを見て有効になる。
  options.host = {
    alwaysOn = lib.mkEnableOption "常時稼働 (サスペンドしない)";
    laptop = lib.mkEnableOption "ラップトップ (蓋を閉じたらサスペンド)";
    desktop = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "GUI 一式 (desktop.nix, xremap) を入れる。false は headless。";
    };
  };

  config = {
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
    nixpkgs.config.allowUnfree = true;
  
    # Bootloader.
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
  
    # Set your time zone.
    time.timeZone = "Asia/Tokyo";
  
    # Select internationalisation properties.
    i18n.defaultLocale = "en_US.UTF-8";
    i18n.supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "en_CA.UTF-8/UTF-8"
      "ja_JP.UTF-8/UTF-8"
      "C.UTF-8/UTF-8"
    ];
  
    security.sudo = {
      enable = true;
      wheelNeedsPassword = false;
    };
  
    # パスワードは宣言していない (initialPassword も hashedPassword も置かない)。
    # ハッシュを平文でリポジトリに置きたくないのが理由で、mutableUsers のまま
    # 実機で passwd する運用にしている。
    # 代償として、新規インストール直後はパスワードが存在せず GNOME にログインできない。
    # SSH は AuthorizedKeysCommand が GitHub から鍵を引くので入れるので、
    # 入れ直した直後は ssh してから `sudo passwd potsbo` すること。
    users.users.potsbo = {
      uid = 1000;
      isNormalUser = true;
      description = "Shimpei Otsubo";
      extraGroups = [ "networkmanager" "wheel" "docker" "onepassword-cli" ];
      shell = pkgs.zsh;
      packages = with pkgs; [];
    };
  
    programs.zsh.enable = true;
    # system の /etc/zshrc が実行する compinit を無効化する。既定では -d なしで
    # ~/.zcompdump を毎ログイン生成してしまうため。補完初期化は user の .zshrc が
    # `compinit -d $XDG_CACHE_HOME/zsh/...` で XDG 配下に行う。
    programs.zsh.enableGlobalCompInit = false;
    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [
      readline
      krb5.lib
    ];
    programs.mosh.enable = true;
    programs._1password.enable = true;
  
    environment.systemPackages = with pkgs; [
      git
    ];
  
    # rclone mount (FUSE) support
    # 26.11 で programs.fuse が opt-in 化した。今は GNOME 由来の gvfs / xdg-portal が
    # 暗黙に有効化しているだけなので、GNOME を外すと setuid fusermount3 ごと消えて
    # rclone mount が黙って失敗する。依存を明示しておく。
    programs.fuse.enable = true;
    programs.fuse.userAllowOther = true;
  
    # Keep user services running after logout (for rclone mount)
    users.users.potsbo.linger = true;
  
    system.stateVersion = "25.11";
  };
}
