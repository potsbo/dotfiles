-- Window rules. DMS の設定画面 (Window Rules) からも書き換わる。

-- タイルが肌に合わないので、新規ウィンドウは全部浮動にする (macOS と同じ扱い)。
-- 配置は xremap 経由の Super+矢印 / U/I/J/K (binds-user.lua) で Magnet 風に寄せる。
-- persistent_size は同じ class+title のウィンドウが前回の大きさで開くための設定。
hl.window_rule({ match = { class = ".*" }, float = true, center = true, persistent_size = true })
