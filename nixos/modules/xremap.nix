{ pkgs, config, ... }:

let
  # HHKB Studio USB vendor/product ID (PFU vendor 0x04FE, product 0x0016)
  # Confirm with: cat /sys/class/input/event*/device/id/{vendor,product}
  hhkbDevice = "ids:0x04FE:0x0016";

  # RDP クライアントではリモート側にキーをそのまま渡すため、xremap を無効化する
  rdpApps = [ "xfreerdp" "FreeRDP" ];
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
# --- 解決: アプリ種別ごとに変換先を分ける (withGnome = true 必須) ---
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
  systemd.user.services.xremap.serviceConfig = {
    Restart = "always";
    RestartSec = 3;
  };

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
    enable = true;
    withGnome = true;
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
            # 単押しで GNOME Activities が起動してしまう
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
        # === Vicinae ランチャー (右Shift 単押し → F20 経由) ===
        {
          name = "Vicinae toggle";
          application = { not = rdpApps; };
          remap = {
            F20 = { launch = ["${pkgs.vicinae}/bin/vicinae" "toggle"]; };
          };
        }

        # === ターミナル用 Cmd ショートカット ===
        # Wayland では Super+key が compositor に消費されアプリに届かないため、
        # ターミナルでは Ctrl+Shift+key に変換して Ghostty keybind で処理する。
        # グローバルの "Super shortcuts" より前に配置して先にマッチさせる。
        {
          name = "Terminal Cmd shortcuts";
          application = {
            only = [ "com.mitchellh.ghostty" "Ghostty" "ghostty" "com.github.wez.wezterm" "org.wezfurlong.wezterm" "wezterm" ];
          };
          remap = {
            Super-n = "C-Shift-n";   # Ghostty: new_window
            Super-q = "C-Shift-q";   # Ghostty: quit
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
            C-m = "C-m";
          };
        }

        # === Chrome 用 Cmd-Q (Ctrl+Shift+W で全タブ・全ウィンドウを閉じる) ===
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
            Super-q = "C-q";
            Super-Enter = "C-Enter";
            # macOS 風 Tab 切り替え
            # Cmd+Tab → GNOME が <Super>Tab を switch-applications として処理するため変換不要
            # Option+Tab → 同一アプリのウィンドウ切り替え (GNOME の Alt+`)
            Alt-Tab = "Alt-grave";
            Alt-Shift-Tab = "Alt-Shift-grave";
          };
        }

        # === Magnet 風ウィンドウ操作 (Ctrl+Option → Ctrl+Alt) ===
        # macOS の Magnet ショートカットを GNOME タイリングにマッピング
        {
          name = "Magnet window management";
          application = { not = rdpApps; };
          remap = {
            C-Alt-Left = "Super-Left";    # 左半分
            C-Alt-Right = "Super-Right";   # 右半分
            C-Alt-Up = "Super-Up";         # 最大化
            C-Alt-Down = "Super-Down";     # 元に戻す
            C-Alt-Enter = "Super-Up";      # 最大化 (Magnet の Ctrl+Option+Enter)
            # 四分割 (tiling-assistant 拡張が Super+U/I/J/K を処理)
            C-Alt-u = "Super-u";           # 左上
            C-Alt-i = "Super-i";           # 右上
            C-Alt-j = "Super-j";           # 左下
            C-Alt-k = "Super-k";           # 右下
          };
        }

        # === Emacs Ctrl バインド (ターミナル以外) ===
        # macOS の Cocoa テキストシステムと同じ挙動を再現。
        # serviceMode = "user" により GNOME D-Bus のアプリ検出が機能するため、
        # ターミナル (Ghostty) を除外して適用する。
        {
          name = "Emacs Ctrl bindings (non-terminal)";
          application = {
            not = [ "com.mitchellh.ghostty" "Ghostty" "ghostty" "com.github.wez.wezterm" "org.wezfurlong.wezterm" "wezterm" ] ++ rdpApps;
          };
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
}
