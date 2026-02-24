{ ... }:

# ============================================================================
# xremap 設計方針: macOS キーバインド再現
# ============================================================================
#
# 目標: macOS の物理キー配列・修飾キーの役割分担をできる限り再現する
#
# --- macOS における Cmd と Ctrl の役割 ---
#
#   Cmd (⌘):  アプリケーションレベルのショートカット
#     - Cmd-C/V/X: コピー/ペースト/カット
#     - Cmd-W: ウィンドウ・タブを閉じる
#     - Cmd-Q: アプリ終了
#     - Cmd-T: 新規タブ
#     - Cmd-S: 保存
#     - Cmd-Z: Undo
#     - Cmd-A: 全選択
#     - Cmd-F: 検索
#
#   Ctrl:  テキスト編集・ターミナル操作 (Emacs 系)
#     - Ctrl-A/E: 行頭/行末
#     - Ctrl-K: 行末まで削除
#     - Ctrl-D: 前方1文字削除
#     - Ctrl-H: 後方1文字削除 (Backspace)
#     - Ctrl-F/B: 前方/後方1文字移動
#     - Ctrl-N/P: 次行/前行
#     - Ctrl-C: SIGINT (ターミナル)
#     - Ctrl-W: 単語削除 (readline)
#
# --- Linux (GNOME) での実現方法 ---
#
#   Linux では Ctrl がアプリショートカットとテキスト編集の両方を担っているため、
#   xremap で Super (物理 Cmd キー) → Ctrl への変換を行い、macOS の Cmd 相当にする。
#   物理 Ctrl キーはそのまま Ctrl として通し、Emacs 系操作に使う。
#   GTK_KEY_THEME = "Emacs" (configuration.nix) と併用して Ctrl の Emacs バインドを有効化。
#
#   現在の方針:
#     Super-{key} → Ctrl-{key}  (アプリショートカット用、グローバル)
#     Super-W     → Alt-F4      (ウィンドウクローズ。Ctrl-W は一部アプリでしか効かないため Alt-F4 を使う)
#     Ctrl-{key}  → そのまま    (テキスト編集・ターミナル用)
#
# --- 既知の制約・TODO ---
#
#   [ ] ターミナルアプリ (Ghostty 等) では Ctrl-C = SIGINT なので、
#       Super-C → Ctrl-C だとコピーではなくシグナルになる。
#       macOS と同じにするにはターミナル専用ルールが必要:
#         Super-C → Ctrl-Shift-C (ターミナルのコピー)
#         Super-V → Ctrl-Shift-V (ターミナルのペースト)
#   [ ] Super-Q (Cmd-Q = アプリ終了) は GNOME のデフォルトと競合する可能性あり
#   [ ] GNOME 固有のショートカット (Super 単押し = Activities) との干渉に注意
#
# ============================================================================
{
  # xremap を HHKB 抜き差し・起動順序に関係なく自動復旧させる
  systemd.services.xremap = {
    serviceConfig = {
      Restart = "always";
      RestartSec = 3;
      # キーボード未接続時に exit 1 で終了するが、これを失敗扱いしない
      # switch 時の "the following units failed" 警告を防ぐ
      SuccessExitStatus = "1";
    };
  };

  services.xremap = {
    enable = true;
    withGnome = false;
    userName = "potsbo";

    config = {
      modmap = [
        {
          name = "Key remaps";
          remap = {
            Ctrl_L = {
              held = "Ctrl_L";
              alone = "Esc";
              alone_timeout_millis = 150;
            };
            # HHKB Studio のファームウェア設定でスペース横のキーが Alt を送信するため、
            # Alt ↔ Super を入れ替えて macOS の物理配列を再現する
            # スペース横 (物理Cmd位置, HHKBはAlt送信) → Super (Cmd相当)
            # その外側 (物理Option位置, HHKBはSuper送信) → Alt (Option相当)
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
            Super_L = "Alt_L";
            Super_R = "Alt_R";
            Shift_R = {
              held = "Shift_R";
              alone = "Super_L";
              alone_timeout_millis = 500;
            };
          };
        }
      ];

      keymap = [
        # === Super shortcuts for all apps (Cmd-like) ===
        {
          name = "Super shortcuts";
          remap = {
            Super-c = "C-c";
            Super-v = "C-v";
            Super-x = "C-x";
            Super-a = "C-a";
            Super-z = "C-z";
            Super-Shift-z = "C-Shift-z";
            Super-s = "C-s";
            # Alt-F4 は GNOME の標準ウィンドウクローズ。Ctrl-W はブラウザ等の一部アプリでしか効かない。
            Super-w = "Alt-F4";
            Super-t = "C-t";
            Super-f = "C-f";
            Super-r = "C-r";
            Super-l = "C-l";
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
