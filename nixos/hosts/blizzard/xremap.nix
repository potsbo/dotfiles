{ pkgs, config, ... }:

let
  # HHKB Studio USB vendor/product ID (PFU vendor 0x2DC8, product 0x9021)
  hhkbDevice = "ids:0x2DC8:0x9021";
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
  # xremap を HHKB 抜き差し・起動順序に関係なく自動復旧させる
  systemd.services.xremap = {
    unitConfig = {
      # キーボード未接続時の無限再起動ループを防止
      # 30秒以内に3回失敗したら再起動を停止する
      # キーボード接続時は udev ルールが reset-failed → restart する
      StartLimitBurst = 3;
      StartLimitIntervalSec = 30;
    };
    # xremap はシステムサービス (root) で動くため、ユーザーセッションの
    # D-Bus ソケットパスを明示しないと GNOME Shell 拡張に接続できない
    environment.DBUS_SESSION_BUS_ADDRESS =
      let uid = toString config.users.users.${config.services.xremap.userName}.uid;
      in "unix:path=/run/user/${uid}/bus";
    serviceConfig = {
      Restart = "always";
      RestartSec = 3;
      # キーボード未接続時に exit 1 で終了するが、これを失敗扱いしない
      # switch 時の "the following units failed" 警告を防ぐ
      SuccessExitStatus = "1";
    };
  };

  # USB キーボード接続時に xremap を自動復旧させる udev ルール
  # StartLimitBurst で停止した状態からでも reset-failed → restart で復帰する
  # ID_BUS=="usb" で xremap 自身の仮想デバイス (uinput) を除外し、再起動ループを防ぐ
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="input", ENV{ID_INPUT_KEYBOARD}=="1", ENV{ID_BUS}=="usb", RUN+="${pkgs.systemd}/bin/systemctl reset-failed xremap.service", RUN+="${pkgs.systemd}/bin/systemctl restart xremap.service"
  '';

  services.xremap = {
    enable = true;
    withGnome = true;
    userName = "potsbo";

    config = {
      modmap = [
        # === 共通: すべてのキーボードで Ctrl_L を dual-purpose にする ===
        {
          name = "Common remaps";
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
              alone = "Super_L";
              alone_timeout_millis = 500;
            };
          };
        }

        # === 非HHKB: CapsLock → Ctrl, かなキー修正 ===
        {
          name = "Non-HHKB remaps";
          device = { not = [ hhkbDevice ]; };
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
            Super_R = "Henkan";
          };
        }
      ];

      keymap = [
        # === Super → Ctrl (Cmd ショートカット再現、グローバル) ===
        # ターミナルでの Ctrl+C/V 衝突は Ghostty 側の keybind で解決する
        {
          name = "Super shortcuts";
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
            # macOS 風 Tab 切り替え
            # Cmd+Tab → アプリ切り替え (GNOME の Alt+Tab)
            Super-Tab = "Alt-Tab";
            Super-Shift-Tab = "Alt-Shift-Tab";
            # Option+Tab → 同一アプリのウィンドウ切り替え (GNOME の Alt+`)
            Alt-Tab = "Alt-grave";
            Alt-Shift-Tab = "Alt-Shift-grave";
          };
        }

        # === Magnet 風ウィンドウ操作 (Ctrl+Option → Ctrl+Alt) ===
        # macOS の Magnet ショートカットを GNOME タイリングにマッピング
        {
          name = "Magnet window management";
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
        # macOS では Karabiner が frontmost_application_unless でターミナル等を除外して適用。
        # Linux でも xremap + GNOME 拡張で同様にアプリ検出して除外する。
        {
          name = "Emacs Ctrl bindings (non-terminal)";
          application = {
            not = [ "com.mitchellh.ghostty" "Ghostty" "ghostty" ];
          };
          remap = {
            C-a = "Home";
            C-e = "End";
            C-f = "Right";
            C-b = "Left";
            C-d = "Delete";
            C-h = "BackSpace";
            C-m = "Enter";
            C-n = "Down";
            C-p = "Up";
          };
        }

        # === Anpan layout (bare keys + Shift only) ===
        {
          name = "Anpan letter remaps";
          exact_match = true;
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
