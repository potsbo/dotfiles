_:

# macOS の GUI アプリ (Homebrew cask / Mac App Store) の宣言。
# brew / mas の確認は遅く、`rebuild` で毎回挟まると鬱陶しいので
# 本体の default.nix から切り離し、`apps` コマンド (home/.local/bin/apps) が
# 使う `<host>-apps` 構成でだけ読み込む。
{
  homebrew = {
    enable = true;
    onActivation = {
      # zap: 宣言から外したアプリを削除する際に設定ファイルも一緒に削除
      # uninstall: アプリのみ削除、設定は残る
      cleanup = "zap";
      # false: `brew update` は手動で実行し、意図したタイミングでのみバージョンを上げる
      autoUpdate = false;
      # false: `apps` は足した / 消したアプリの反映だけにする。true だと
      # `brew bundle` が Mac App Store のアプリ (Word など) まで毎回上げにいき、
      # 遅いうえに更新のタイミングを選べない。`brew bundle` の upgrade 抑止は
      # `--no-upgrade` 一つで cask と mas を分けられないので、cask も含めて
      # 止めている (Chrome / VS Code / Slack などは自前で更新する)。
      # 上げたいときは `brew upgrade` / `mas upgrade` を手で打つ。
      upgrade = false;
    };
    brews = [
      "libomp" # LightGBM 等の機械学習ライブラリのビルドに必要
    ];
    masApps = {
      "Amphetamine" = 937984704;
      "Magnet" = 441258766;
      "Microsoft Excel" = 462058435;
      "Microsoft PowerPoint" = 462062816;
      "Microsoft Word" = 462054704;
      "Slack" = 803453959;
      "Todoist" = 585829637;
      "Windows App" = 1295203466;
    };
    casks = [
      "karabiner-elements"
      "visual-studio-code"
      "google-chrome"
      "google-japanese-ime"
      "raycast"
      "keyboard-cleaner"
      "zoom"
      "dash"
      "docker-desktop"
      "1password"
      "notion"
      "notion-calendar"
      "obsidian"
      "font-monaspice-nerd-font"
      "ghostty"
      # ターミナルの日本語フォールバック (home/.config/ghostty/config)。
      # 未インストールだと一部の漢字が tofu (斜線付き□) になるため必須。
      "font-biz-udgothic"
      "tailscale-app"
      "chatgpt"
      "claude"
      "pgadmin4"
      "plaud"
      "cloudflare-warp"
      # niri (Linux 側の WM) と同じスクロール型タイリングを macOS でも使うための試用。
      # niri 自体は Wayland コンポジタなので移植版は存在せず、体験を再実装したものから
      # 選ぶことになる。候補は PaperWM.spoon (Hammerspoon 上、枯れている) / Paneru
      # (niri に一番近いが nixpkgs にも cask にも無く入手経路を自作する必要がある) /
      # これ。署名 + notarize 済みで cask から入る配布品質を取った。
      #
      # 設定は流用できない。niri の KDL を読めるものは無いので、移すのは
      # docs/keymap.md の仕様のほう。ただし niri 側で手のかかっている格子配置
      # (niri-place.sh) と画面をまたぐ移動は macOS では Magnet の担当なので、
      # 移植が要るのは列の操作だけ。
      #
      # cask が arm64 かつ macOS 26 以降を要求する。blizzard がこれを満たさない間は
      # あちらで `apps` が落ちるので、そのときはホスト別に分ける。
      "omniwm"
    ];
  };
}
