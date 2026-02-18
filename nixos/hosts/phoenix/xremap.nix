{ ... }:

{
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
            Super-w = "C-w";
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
