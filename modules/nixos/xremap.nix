{ config, lib, ... }:

let
  # HHKB Studio USB vendor/product ID (PFU vendor 0x04FE, product 0x0016)
  # Confirm with: cat /sys/class/input/event*/device/id/{vendor,product}
  hhkbDevice = "ids:0x04FE:0x0016";

  # RDP クライアントではリモート側にキーをそのまま渡すため、xremap を無効化する
  rdpApps = [ "xfreerdp" "FreeRDP" ];

  # ターミナルとして扱うアプリ
  terminalApps = [ "com.mitchellh.ghostty" "Ghostty" "ghostty" ];
in

# ============================================================================
# xremap 設計方針: macOS キーバインド再現
# ============================================================================
#
# 目標: macOS の Cmd / Ctrl の役割分担を Linux で再現する
#
# --- macOS のキー役割 ---
#
#   Cmd (⌘):  アプリショートカット (Cmd-C/V/S/Z/W/T/F/R/L/A/X)
#   Ctrl:     ターミナル・Emacs 操作 (Ctrl-C=SIGINT, Ctrl-A/E/K/D/H/F/B/N/P)
#
# --- Linux での問題 ---
#
#   Linux の Ctrl が両方の役割を担っているため、Super → Ctrl のグローバル変換では
#   ターミナルで衝突する (例: Cmd+C → Ctrl+C = SIGINT、コピーにならない)
#
# --- 解決: アプリ種別ごとに変換先を分ける (withHypr / withNiri でフォーカス中のアプリを判定) ---
#
#   ┌─────────────────┬──────────────────────────────┬──────────────────────────────┐
#   │ 物理キー         │ GUI アプリ (Chrome 等)         │ ターミナル (Ghostty)          │
#   ├─────────────────┼──────────────────────────────┼──────────────────────────────┤
#   │ Cmd + C/V       │ Ctrl+C/V (コピー/ペースト)      │ Ctrl+Shift+C/V (コピー/ペースト) │
#   │ Cmd + その他     │ Ctrl+{key} (アプリ操作)        │ 変換しない → Ghostty keybind  │
#   │ Ctrl + A/E/...  │ Home/End/... (Emacs 風)       │ そのまま通す (SIGINT 等)       │
#   └─────────────────┴──────────────────────────────┴──────────────────────────────┘
#
# ============================================================================
{
  # headless ホスト (role = server) ではキーボードの再配置も要らない。
  # enable だけは mkIf の外で常に明示する。上流 module は enable が未設定で
  # default に落ちたときだけ evaluation warning を出す (default に lib.warn を
  # 仕込んでいる) ので、false でも書いておく必要がある。
  config = lib.mkMerge [
    { services.xremap.enable = config.host.desktop; }
    (lib.mkIf config.host.desktop {
    systemd.user.services.xremap.serviceConfig = {
      Restart = "always";
      RestartSec = 3;
    };
    # GDM の greeter でも graphical-session.target 経由で起動し、uinput を作れずに
    # 3 秒おきに落ち続ける。greeter の判定は desktop/dms.nix の DMS と同じ。
    systemd.user.services.xremap.unitConfig.ConditionEnvironment = "!XDG_SESSION_CLASS=greeter";
  
    # nixos-rebuild switch 時に xremap の設定変更を検知して自動再起動する
    # NixOS はユーザーサービスの自動再起動をしないため、userActivationScripts で対応
    # (system.activationScripts は switch-to-configuration より前に走るため、
    #  古い unit で restart してしまう。userActivationScripts は daemon-reload 後に実行される)
    system.userActivationScripts.restartXremap = let
      unitFile = "/etc/systemd/user/xremap.service";
      stateFile = "\${XDG_RUNTIME_DIR}/xremap-unit-hash";
    in {
      text = ''
        if [ -f ${unitFile} ]; then
          NEW_HASH=$(sha256sum ${unitFile} | cut -d' ' -f1)
          OLD_HASH=""
          if [ -f ${stateFile} ]; then
            OLD_HASH=$(cat ${stateFile})
          fi
          echo "$NEW_HASH" > ${stateFile}
          if [ -z "$OLD_HASH" ] || [ "$NEW_HASH" != "$OLD_HASH" ]; then
            systemctl --user restart xremap.service 2>/dev/null || true
          fi
        fi
      '';
    };
  
    services.xremap = {
      # Hyprland / niri では IPC でフォーカス中のウィンドウ class を取る
      withHypr = config.desktop.environment == "hyprland";
      withNiri = config.desktop.environment == "niri";
      userName = "potsbo";
      serviceMode = "user";
      watch = true;
  
      config = {
        modmap = [
          # === 共通: すべてのキーボードで Ctrl_L を dual-purpose にする ===
          {
            name = "Common remaps";
            application = { not = rdpApps; };
            remap = {
              Ctrl_L = {
                held = "Ctrl_L";
                alone = "Esc";
                alone_timeout_millis = 150;
              };
            };
          }
  
          # === HHKB 専用: Alt ↔ Super 入れ替え ===
          # HHKB Studio のファームウェア設定でスペース横のキーが Alt を送信するため、
          # Alt ↔ Super を入れ替えて macOS の物理配列を再現する
          {
            name = "HHKB remaps";
            device = { only = [ hhkbDevice ]; };
            application = { not = rdpApps; };
            remap = {
              # スペース横 (物理Cmd位置, HHKBはAlt送信) → Super (Cmd相当)
              Alt_L = {
                held = "Super_L";
                alone = "Muhenkan";
                alone_timeout_millis = 500;
              };
              Alt_R = {
                held = "Super_R";
                alone = "Henkan";
                alone_timeout_millis = 500;
              };
              # その外側 (物理Option位置, HHKBはSuper送信) → Alt (Option相当)
              Super_L = "Alt_L";
              Super_R = "Alt_R";
              Shift_R = {
                held = "Shift_R";
                alone = "F20";
                alone_timeout_millis = 500;
              };
            };
          }
  
          # === 非HHKB: CapsLock → Ctrl, かなキー修正 ===
          {
            name = "Non-HHKB remaps";
            device = { not = [ hhkbDevice ]; };
            application = { not = rdpApps; };
            remap = {
              CapsLock = {
                held = "Ctrl_L";
                alone = "Esc";
                alone_timeout_millis = 150;
              };
              # MacBook の ⌘/かなキーは Super を送信するため、
              # 単押しが compositor に食われないよう
              # → 単押しは IME 切り替え、押しながらはショートカット用 Super として使う
              Super_L = {
                held = "Super_L";
                alone = "Muhenkan";
                alone_timeout_millis = 500;
              };
              Super_R = {
                held = "Super_R";
                alone = "Henkan";
                alone_timeout_millis = 500;
              };
              Shift_R = {
                held = "Shift_R";
                alone = "F20";
                alone_timeout_millis = 500;
              };
            };
          }
        ];
  
        keymap = [
          # === ランチャー (右Shift 単押し → F20 経由) === DMS の spotlight
          {
            name = "Launcher toggle";
            application = { not = rdpApps; };
            remap = {
              F20 = { launch = [ (lib.getExe config.programs.dank-material-shell.package) "ipc" "call" "spotlight" "toggle" ]; };
            };
          }
  
          # === Super+Alt は変換せず compositor に渡す ===
          # 下の "Super shortcuts" は修飾キーが上位集合でも当たる (xremap の既定) ので、
          # Super+Alt+Q は Ctrl+Alt+Q になってしまう。compositor 側で Super+Alt に寄せた WM 操作
          # (hypr/dms/binds-user.lua、niri/binds-user.kdl) を届けるため、完全一致の同一写像で先に受ける。
          {
            name = "Super+Alt passthrough";
            exact_match = true;
            remap = lib.genAttrs
              (map (k: "Super-Alt-${k}") [ "c" "v" "x" "a" "z" "s" "w" "t" "f" "r" "l" "k" "n" "q" "Enter" ])
              (k: k);
          }

          # === Magnet 風の格子配置 (Ctrl+Option) をそのまま compositor へ ===
          # docs/keymap.md §2 で Ctrl+Option を格子配置の面と決めたので、変換せずに
          # compositor (niri の user.kdl) が Ctrl+Alt+... を直接受ける。
          # ただ下の "Terminal Cmd shortcuts" と "Emacs Ctrl bindings" は修飾キーが上位集合でも
          # 当たる (xremap の既定) ので、素通しにしないと Ctrl+Alt+K が Ctrl+K (行末まで削除) に
          # 化ける。完全一致の同一写像で、どちらより前に置いて先に受ける。
          # Hyprland 側 (binds-user.lua) は Super+矢印 / Super+U/I/J/K で受けていたので、
          # あちらに戻すときはこの節を元の変換に戻す。
          {
            name = "Ctrl+Alt passthrough (Magnet)";
            exact_match = true;
            remap = lib.genAttrs
              (map (k: "C-Alt-${k}") [ "Left" "Right" "Up" "Down" "u" "i" "j" "k" "Enter" ])
              (k: k);
          }

          # === ターミナル用 Cmd ショートカット ===
          # Wayland では Super+key が compositor に消費されアプリに届かないため、
          # ターミナルでは Ctrl+Shift+key に変換して Ghostty keybind で処理する。
          # グローバルの "Super shortcuts" より前に配置して先にマッチさせる。
          {
            name = "Terminal Cmd shortcuts";
            application = { only = terminalApps; };
            remap = {
              Super-n = "C-Shift-n";   # new_window
              Super-q = "C-Shift-q";   # quit
              Super-w = "C-Shift-w";   # close tab/window
              Super-v = "C-Shift-v";   # paste
              Super-c = "C-Shift-c";   # copy
              # Emacs Ctrl bindings の `not` フィルタが空文字 WMClass のため機能しないので、
              # `only` フィルタで先にマッチさせて Ctrl キーをそのまま通す (identity mapping)
              C-a = "C-a";
              C-b = "Left";   # 非ターミナルの Emacs bindings と統一
              C-f = "Right";
              C-n = "Down";
              C-p = "Up";
              C-d = "C-d";
              C-e = "C-e";
              C-h = "C-h";
              C-k = "C-k";
              # Enter に変換する。Ghostty は Ctrl+M を Enter (CR) と区別して送るので、zsh の
              # 行確定にならない。herdr など kitty keyboard protocol を使う TUI は Ctrl+M を
              # Enter 扱いするので、Enter を送っても振る舞いは変わらない
              C-m = "Enter";
            };
          }
  
          # === Chrome 用 Cmd-Q (Ctrl+Shift+W で全タブ・全ウィンドウを閉じる) ===
          # Cmd+Enter は下の "Super shortcuts" の Ctrl+Enter のままにする。macOS の
          # omnibox と同じ「新しいタブで開く」(Linux Chrome では Alt+Enter) に変えると、
          # xremap は omnibox に focus があるかを判別できない (見えるのは class だけ) ため
          # ページ側の Ctrl+Enter (BigQuery のクエリ実行、Gmail 送信など) が全滅する。
          # omnibox で新しいタブに開きたいときは Option+Enter か Cmd+Option+Enter を使う。
          # Chrome の omnibox は修飾キーだけで disposition を決めていて OS 分岐がない
          # (searchbox::ComputeOpenDispositionFromModifiersAndLogToUma) ので、
          # どちらも macOS と Linux で同じ挙動になる。
          {
            name = "Chrome Cmd-Q quit";
            application = {
              only = [ "google-chrome" "Google-chrome" "chromium-browser" "Chromium-browser" ];
            };
            remap = {
              Super-q = "C-Shift-w";
            };
          }
  
          # === Super → Ctrl (Cmd ショートカット再現、グローバル) ===
          # ターミナルでの Ctrl+C/V 衝突は Ghostty 側の keybind で解決する
          {
            name = "Super shortcuts";
            application = { not = rdpApps; };
            remap = {
              Super-c = "C-c";
              Super-v = "C-v";
              Super-x = "C-x";
              Super-a = "C-a";
              Super-z = "C-z";
              Super-Shift-z = "C-Shift-z";
              Super-Shift-m = "C-Shift-m";
              Super-s = "C-s";
              Super-w = "C-w";
              Super-t = "C-t";
              Super-f = "C-f";
              Super-r = "C-r";
              Super-l = "C-l";
              Super-k = "C-k";
              Super-n = "C-n";
              # DMS 既定の Hyprland バインド (dms/binds.lua) が Super+P を出力プロファイル
              # 切替に使っているので、ここで先に Ctrl+P に変えないとアプリ (Obsidian の
              # コマンドパレット等) に届かない
              Super-p = "C-p";
              Super-o = "C-o";
              Super-q = "C-q";
              Super-Enter = "C-Enter";
              # 表示の拡大縮小。アプリに届けるだけでは何も起きない (A6) ので、アプリが
              # 拡大縮小として解釈する Ctrl 系に変換する (A7)。Chrome は Ctrl+- と
              # Ctrl+= / Ctrl+Plus のどちらも見る。
              Super-minus = "C-minus";
              Super-equal = "C-equal";
              Super-Shift-equal = "C-Shift-equal";
              # Cmd+Tab と Cmd+` は変換せず Hyprland 側 (hyprshell) に渡す
            };
          }
    
          # === Emacs Ctrl バインド (ターミナル以外) ===
          # macOS の Cocoa テキストシステムと同じ挙動を再現。
          # ターミナル (Ghostty) を除外して適用する。
          {
            name = "Emacs Ctrl bindings (non-terminal)";
            application = { not = terminalApps ++ rdpApps; };
            remap = {
              C-a = "Home";
              C-e = "End";
              C-f = "Right";
              C-b = "Left";
              C-d = "Delete";
              C-h = "BackSpace";
              C-k = ["Shift-End" "Delete"];
              C-m = "Enter";
              C-n = "Down";
              C-p = "Up";
            };
          }
  
          # === Anpan layout (bare keys + Shift only) ===
          {
            name = "Anpan letter remaps";
            exact_match = true;
            application = { not = rdpApps; };
            remap = {
              # Left hand - top row
              q = "apostrophe";
              Shift-q = "Shift-apostrophe";  # "
              w = "comma";
              Shift-w = "Shift-comma";  # <
              e = "dot";
              Shift-e = "Shift-dot";  # >
              r = "p";
              Shift-r = "Shift-p";
              t = "y";
              Shift-t = "Shift-y";
  
              # Right hand - top row
              y = "f";
              Shift-y = "Shift-f";
              u = "g";
              Shift-u = "Shift-g";
              i = "c";
              Shift-i = "Shift-c";
              o = "r";
              Shift-o = "Shift-r";
              p = "l";
              Shift-p = "Shift-l";
  
              # Left hand - home row
              # a stays as a
              s = "o";
              Shift-s = "Shift-o";
              d = "e";
              Shift-d = "Shift-e";
              f = "u";
              Shift-f = "Shift-u";
              g = "i";
              Shift-g = "Shift-i";
  
              # Right hand - home row
              h = "d";
              Shift-h = "Shift-d";
              j = "h";
              Shift-j = "Shift-h";
              k = "t";
              Shift-k = "Shift-t";
              l = "n";
              Shift-l = "Shift-n";
              semicolon = "s";
              Shift-semicolon = "Shift-s";
              apostrophe = "minus";
              Shift-apostrophe = "Shift-minus";  # _
  
              # Left hand - bottom row
              z = "semicolon";
              Shift-z = "Shift-semicolon";  # :
              x = "q";
              Shift-x = "Shift-q";
              c = "j";
              Shift-c = "Shift-j";
              v = "k";
              Shift-v = "Shift-k";
              b = "x";
              Shift-b = "Shift-x";
  
              # Right hand - bottom row
              n = "b";
              Shift-n = "Shift-b";
              comma = "w";
              Shift-comma = "Shift-w";
              dot = "v";
              Shift-dot = "Shift-v";
              slash = "z";
              Shift-slash = "Shift-z";
  
              # Brackets
              leftbrace = "slash";
              Shift-leftbrace = "Shift-slash";  # ?
              rightbrace = "Shift-2";  # @
              Shift-rightbrace = "Shift-6";  # ^
            };
          }
          {
            name = "Anpan number/symbol row";
            exact_match = true;
            application = { not = rdpApps; };
            remap = {
              # Number row remaps
              grave = "Shift-4";  # $
              Shift-grave = "Shift-grave";  # ~
              "1" = "Shift-1";  # !
              "Shift-1" = "1";
              "2" = "leftbrace";  # [
              "Shift-2" = "2";
              "3" = "Shift-leftbrace";  # {
              "Shift-3" = "3";
              "4" = "Shift-9";  # (
              "Shift-4" = "4";
              "5" = "equal";  # =
              "Shift-5" = "5";
              "6" = "Shift-equal";  # +
              "Shift-6" = "6";
              "7" = "Shift-0";  # )
              "Shift-7" = "7";
              "8" = "Shift-rightbrace";  # }
              "Shift-8" = "8";
              "9" = "rightbrace";  # ]
              "Shift-9" = "9";
              "0" = "Shift-8";  # *
              "Shift-0" = "0";
              minus = "Shift-7";  # &
              Shift-minus = "Shift-5";  # %
              equal = "grave";  # `
              Shift-equal = "Shift-3";  # #
            };
          }
        ];
      };
    };
    })
  ];
}
