{ ... }:

{
  services.xremap = {
    enable = true;
    withGnome = true;
    userName = "potsbo";

    config = {
      modmap = [
        {
          name = "Key remaps";
          remap = {
            CapsLock = {
              held = "Ctrl_L";
              alone = "Esc";
              alone_timeout_millis = 150;
            };
            Ctrl_L = "CapsLock";
            Alt_L = {
              held = "Alt_L";
              alone = "Muhenkan";
              alone_timeout_millis = 500;
            };
            Alt_R = {
              held = "Alt_R";
              alone = "Henkan";
              alone_timeout_millis = 500;
            };
          };
        }
      ];

      keymap = [
        # === Emacs keybindings (excluding terminals/editors) ===
        {
          name = "Emacs keybindings";
          application = {
            not = [
              "org.gnome.Terminal"
              "kitty"
              "Alacritty"
              "com.mitchellh.ghostty"
              "Emacs"
              "code"
              "Cursor"
            ];
          };
          remap = {
            C-b = "left";
            C-f = "right";
            C-n = "down";
            C-p = "up";
            C-d = "delete";
            C-h = "backspace";
            C-i = "tab";
            C-m = "enter";
          };
        }

        # === Anpan layout (bare keys + Shift only) ===
        {
          name = "Anpan letter remaps";
          remap = {
            # Left hand - top row
            q = "apostrophe";
            Shift-q = "Shift-apostrophe";  # "
            w = "comma";
            Shift-w = "Shift-comma";  # <
            e = "dot";
            Shift-e = "Shift-dot";  # >
            r = "p";
            Shift-r = "P";
            t = "y";
            Shift-t = "Y";

            # Right hand - top row
            y = "f";
            Shift-y = "F";
            u = "g";
            Shift-u = "G";
            i = "c";
            Shift-i = "C";
            o = "r";
            Shift-o = "R";
            p = "l";
            Shift-p = "L";

            # Left hand - home row
            # a stays as a
            s = "o";
            Shift-s = "O";
            d = "e";
            Shift-d = "E";
            f = "u";
            Shift-f = "U";
            g = "i";
            Shift-g = "I";

            # Right hand - home row
            h = "d";
            Shift-h = "D";
            j = "h";
            Shift-j = "H";
            k = "t";
            Shift-k = "T";
            l = "n";
            Shift-l = "N";
            semicolon = "s";
            Shift-semicolon = "S";
            apostrophe = "minus";
            Shift-apostrophe = "Shift-minus";  # _

            # Left hand - bottom row
            z = "semicolon";
            Shift-z = "Shift-semicolon";  # :
            x = "q";
            Shift-x = "Q";
            c = "j";
            Shift-c = "J";
            v = "k";
            Shift-v = "K";
            b = "x";
            Shift-b = "X";

            # Right hand - bottom row
            n = "b";
            Shift-n = "B";
            comma = "w";
            Shift-comma = "W";
            dot = "v";
            Shift-dot = "V";
            slash = "z";
            Shift-slash = "Z";

            # Brackets
            leftbrace = "slash";
            Shift-leftbrace = "Shift-slash";  # ?
            rightbrace = "Shift-2";  # @
            Shift-rightbrace = "Shift-6";  # ^
          };
        }
        {
          name = "Anpan number/symbol row";
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
