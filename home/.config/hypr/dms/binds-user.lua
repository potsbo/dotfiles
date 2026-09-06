-- DMS 既定バインド (dms/binds.lua) への上書き。DMS の設定画面 (Keyboard Shortcuts) もここに書く。
--
-- 前提: xremap (modules/nixos/xremap.nix) が macOS の Cmd 再現のために Super+C/V/X/A/Z/
-- S/W/T/F/R/L/K/N/Q/Return を Ctrl+同キーに変えてから compositor に渡す。これらの Super
-- コンボは Hyprland には届かないので、重なる既定を外し、要るものだけ Super+Alt (物理
-- Cmd+Option) に付け替える。xremap は Super+Alt+<同キー> を素通しする。

-- Cmd+T/V/N/X/Q/F/W/R はアプリ側 (新規タブ、貼り付け、新規ウィンドウ、切り取り、終了、検索、
-- タブを閉じる、再読込) に渡す
hl.unbind("SUPER + T")
hl.bind("SUPER + ALT + T", hl.dsp.exec_cmd("ghostty"), { description = "Terminal" })
hl.unbind("SUPER + V")
hl.bind("SUPER + ALT + V", hl.dsp.exec_cmd("dms ipc call clipboard toggle"), { description = "Clipboard history" })
hl.unbind("SUPER + N")
hl.bind("SUPER + ALT + N", hl.dsp.exec_cmd("dms ipc call notifications toggle"), { description = "Notifications" })
hl.unbind("SUPER + X")
hl.bind("SUPER + ALT + X", hl.dsp.exec_cmd("dms ipc call powermenu toggle"), { description = "Power menu" })
hl.unbind("SUPER + Q")
hl.bind("SUPER + ALT + Q", hl.dsp.window.close(), { description = "Close window" })
hl.unbind("SUPER + F")
hl.bind("SUPER + ALT + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), { description = "Maximize" })
hl.unbind("SUPER + W") -- group toggle。使わない
hl.unbind("SUPER + R") -- togglesplit。浮動既定 (windowrules.lua) では使わない
hl.unbind("SUPER + L") -- focus right。下の Super+Alt+矢印で代替 (Super+Alt+L は DMS のロック)
hl.unbind("SUPER + K")

-- 全ウィンドウ浮動の本体 (float) は DMS が dms/windowrules.lua で持つ (初回起動で取り込まれた)。
-- DMS の形式には無い center と persistent_size (同じ class+title は前回の大きさで開く) を
-- ここで足す。
hl.window_rule({ match = { class = ".*" }, center = true, persistent_size = true })

-- === Magnet 風の配置 (macOS の Ctrl+Option+矢印 / U/I/J/K) ===
-- xremap が Ctrl+Alt+矢印 → Super+矢印、Ctrl+Alt+U/I/J/K → Super+U/I/J/K に変える
-- (GNOME では tiling-assistant 拡張がこれを受けていた)。DMS 既定の Super+矢印 (フォーカス
-- 移動) と Super+U/I (ワークスペース) 、Super+J/K は外し、フォーカス移動は Super+Alt+矢印へ。
--
-- 座標は論理ピクセル。monitor.width/height は物理ピクセルなので scale で割る。
-- reserved は bar などが占める領域。
--
-- ウィンドウの size と position に枠線 (border) は含まれない。作業領域いっぱいに置くと
-- 右と下の枠線が画面外にはみ出すので、枠線の分だけ内側に寄せる。あわせて、タイル配置の
-- gaps_out / gaps_in と同じ余白を外周とウィンドウ間に置き、見た目をタイルに揃える。
-- 値は DMS が書く dms/layout.lua (border_size = 2, gaps = 4) に合わせている。
local border = 0 -- 下の hl.config で枠線を消している
local gap = 4

local function place(fx, fy, fw, fh)
  return function()
    local w = hl.get_active_window()
    local m = hl.get_active_monitor()
    if not w or not m then
      return
    end
    local r = m.reserved
    -- 作業領域から外周の余白を引いたもの
    local ax = m.x + r.left + gap
    local ay = m.y + r.top + gap
    local aw = m.width / m.scale - r.left - r.right - 2 * gap
    local ah = m.height / m.scale - r.top - r.bottom - 2 * gap
    -- 割り当てるセル。隣にセルがある辺は余白を半分ずつ分け合う
    local x = ax + aw * fx
    local y = ay + ah * fy
    local cw = aw * fw
    local ch = ah * fh
    if fx > 0 then x = x + gap / 2; cw = cw - gap / 2 end
    if fx + fw < 1 then cw = cw - gap / 2 end
    if fy > 0 then y = y + gap / 2; ch = ch - gap / 2 end
    if fy + fh < 1 then ch = ch - gap / 2 end
    -- float({ action = "set" }) は Hyprland 0.56 では toggle として動く (実機で確認: 2 回送ると
    -- タイルに戻る)。浮動でないときだけ切り替える。
    if not w.floating then
      hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    end
    hl.dispatch(hl.dsp.window.resize({ x = math.floor(cw - 2 * border), y = math.floor(ch - 2 * border) }))
    hl.dispatch(hl.dsp.window.move({ x = math.floor(x + border), y = math.floor(y + border) }))
    -- 配置したウィンドウが他の浮動ウィンドウの下に残ることがある (フォーカスと重なり順は
    -- 別)。Magnet は操作したウィンドウが必ず前に出るので、明示的に最前面へ
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
  end
end

for _, key in ipairs({ "left", "right", "up", "down", "U", "I", "J", "H" }) do
  hl.unbind("SUPER + " .. key)
end

hl.bind("SUPER + left", place(0, 0, 0.5, 1), { description = "Left half" })
hl.bind("SUPER + right", place(0.5, 0, 0.5, 1), { description = "Right half" })
hl.bind("SUPER + up", place(0, 0, 1, 1), { description = "Maximize" })
hl.bind("SUPER + down", hl.dsp.window.center(), { description = "Center" })
hl.bind("SUPER + U", place(0, 0, 0.5, 0.5), { description = "Top-left quarter" })
hl.bind("SUPER + I", place(0.5, 0, 0.5, 0.5), { description = "Top-right quarter" })
hl.bind("SUPER + J", place(0, 0.5, 0.5, 0.5), { description = "Bottom-left quarter" })
hl.bind("SUPER + K", place(0.5, 0.5, 0.5, 0.5), { description = "Bottom-right quarter" })

hl.bind("SUPER + ALT + left", hl.dsp.focus({ direction = "l" }), { description = "Focus left" })
hl.bind("SUPER + ALT + right", hl.dsp.focus({ direction = "r" }), { description = "Focus right" })
hl.bind("SUPER + ALT + up", hl.dsp.focus({ direction = "u" }), { description = "Focus up" })
hl.bind("SUPER + ALT + down", hl.dsp.focus({ direction = "d" }), { description = "Focus down" })

-- === DMS のランチャー等での Emacs Ctrl バインド ===
-- spotlight やクリップボード履歴は layer-shell に描かれ、Hyprland の IPC は「最後に
-- フォーカスしていたウィンドウ」を返し続ける。xremap (xremap.nix) はそれを見てアプリ判定
-- するので、ターミナルから開くと Emacs バインドが外れたまま Ctrl+M などが素通りする。
-- 該当の layer が開いている間だけ compositor 側で補う。通常ウィンドウから開いたときは
-- xremap が先に Enter に変えていて、ここに Ctrl+M は届かないので二重にならない。
-- bar (dms:bar) は常に開いているので、名前を列挙して限定する。
local emacs_layers = {
  ["dms:spotlight"] = true,
  ["dms:clipboard"] = true,
  ["dms:powermenu"] = true,
  ["dms:workspace-overview"] = true,
  ["dms:notepad"] = true,
  ["dms:processlist"] = true,
  ["dms:settings"] = true,
  ["dms:control-center"] = true,
}
local emacs_keys = {
  { "CTRL + M", "Return" },
  { "CTRL + N", "Down" },
  { "CTRL + P", "Up" },
  { "CTRL + H", "BackSpace" },
  { "CTRL + D", "Delete" },
  { "CTRL + A", "Home" },
  { "CTRL + E", "End" },
  { "CTRL + F", "Right" },
  { "CTRL + B", "Left" },
}

-- send_key_state で修飾キー無しを明示するのは、物理的に押されている Ctrl が混ざるのを避けるため
local function send_plain_key(key)
  return function()
    hl.dispatch(hl.dsp.send_key_state({ mods = "", key = key, state = "down" }))
    hl.timer(function()
      hl.dispatch(hl.dsp.send_key_state({ mods = "", key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
  end
end

local emacs_layer_count = 0
local emacs_binds = {}

hl.on("layer.opened", function(layer)
  if not emacs_layers[layer.namespace] then
    return
  end
  emacs_layer_count = emacs_layer_count + 1
  if emacs_layer_count == 1 then
    for _, pair in ipairs(emacs_keys) do
      table.insert(emacs_binds, hl.bind(pair[1], send_plain_key(pair[2]), { description = "Emacs: " .. pair[2] .. " (DMS layer)" }))
    end
  end
end)

hl.on("layer.closed", function(layer)
  if not emacs_layers[layer.namespace] or emacs_layer_count == 0 then
    return
  end
  emacs_layer_count = emacs_layer_count - 1
  if emacs_layer_count == 0 then
    for _, keybind in ipairs(emacs_binds) do
      keybind:unbind()
    end
    emacs_binds = {}
  end
end)

-- === 見た目 ===
-- 枠線を消す。macOS にウィンドウの枠線は無く、フォーカスは影と bar の表示で分かる。
-- DMS の dms/layout.lua (border_size = 2) と dms/colors.lua (テーマの primary 色) の後に
-- 読まれるので、こちらが勝つ。配置 (place) の border も 0 に合わせる。
hl.config({
  general = {
    border_size = 0,
  },
  -- 枠線が無い分、影を濃く大きくして前後関係が分かるようにする (雛形は range 30、
  -- render_power 4、rgba(00000070))。
  decoration = {
    shadow = {
      enabled = true,
      range = 60,
      render_power = 3,
      offset = "0 12",
      color = "rgba(000000b0)",
    },
  },
})

-- macOS と同じく、フォーカスしていないウィンドウでもポインタの下ならスクロールが効くようにする。
-- DMS の雛形は 0 (ポインタでフォーカスは動かない = スクロールもフォーカス中のウィンドウへ)。
-- 2 はポインタのフォーカスとキーボードのフォーカスを分け、キーボード側はクリックで移る。
hl.config({
  input = {
    follow_mouse = 2,
  },
})

-- === 入力: macOS の既定 + modules/darwin/default.nix の上書きに合わせる ===
-- macOS 側で変えているのは、タップでクリック (trackpad.Clicking = true)、キーリピートを
-- 最速 (KeyRepeat = 1 → 15ms、InitialKeyRepeat = 15 → 225ms)、トラックパッドの速さ
-- (scaling = 2) の 3 つ。それ以外は macOS の既定: ナチュラルスクロールはトラックパッドも
-- マウスも on、二本指クリックで右クリック、入力中はトラックパッドを無視、文字を打ち始めたら
-- ポインタを隠す、中クリック貼り付けは無い、ウィンドウの縁でサイズ変更できる。
-- GNOME 側 (gnome.nix) は tap-to-click を切っていたが、macOS 側の上書きに揃える。
hl.config({
  input = {
    repeat_rate = 66,
    repeat_delay = 225,
    natural_scroll = true,
    touchpad = {
      natural_scroll = true,
      tap_to_click = true,
      clickfinger_behavior = true,
      disable_while_typing = true,
      -- スクロール量 (1.0 が既定)。トラックパッドは速く感じるので下げる。マウスは
      -- input.scroll_factor で、HHKB は下の hl.device で別に持つ
      scroll_factor = 0.3,
    },
    scroll_factor = 0.6,
    -- libinput の加速 (-1 〜 1)。GNOME では speed 0.5 にしていた
    sensitivity = 0.5,
  },
  cursor = {
    hide_on_key_press = true,
  },
  misc = {
    middle_click_paste = false,
  },
  general = {
    resize_on_border = true,
    -- 枠線を 0 にしているので、掴める幅は縁の外側に足す
    extend_border_grab_area = 12,
  },
})

-- 透過ウィンドウ (Ghostty の background-opacity) の背後のぼかし。Hyprland の既定は
-- size 8 / passes 1 で薄い。macOS の半透明ウィンドウ (ターミナルや通知センター) に近い
-- 強さにする。size は 1 pass あたりの半径、passes は重ねる回数で、掛け算で効く。
hl.config({
  decoration = {
    blur = {
      enabled = true,
      size = 10,
      passes = 3,
      noise = 0.02,
    },
  },
})

-- HHKB Studio のポインティングスティック / ジェスチャーパッドはマウス扱いだが、
-- ナチュラルスクロールだと向きが逆に感じる。HHKB だけ通常向きにする。
-- xremap-1 は xremap の仮想デバイスで、HHKB のポインタ操作がそちらを経由して届く場合の保険。
-- 名前は `hyprctl devices` で確認。
-- スクロール量も HHKB は遅く感じるので、マウス共通の 0.6 より上げる
for _, name in ipairs({ "pfu-limited-hhkb-studio-1", "xremap-1" }) do
  hl.device({ name = name, natural_scroll = false, scroll_factor = 1.0 })
end
