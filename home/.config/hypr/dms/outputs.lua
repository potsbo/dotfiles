-- モニタ。GNOME での運用 (home/.config/monitors.xml) に合わせる: 4K 2 枚を 1.25 倍、Dell が左、
-- LG が右。DMS 雛形の "auto" だと 4K は 2 倍に選ばれて GNOME と見え方が変わる。
-- DMS の設定画面 (Displays) で変えるとこのファイルが書き換わる。
hl.monitor({ output = "DP-1", mode = "preferred", position = "0x0", scale = 1.25 })
hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "3072x0", scale = 1.25 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1.25 })

-- GDK_SCALE は GTK が自分の UI を描く倍率で整数しか効かない。Xwayland アプリもこれで決まる。
hl.env("GDK_SCALE", "1")
