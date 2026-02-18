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
