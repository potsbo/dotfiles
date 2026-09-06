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

-- === Magnet 風の配置 (macOS の Ctrl+Option+矢印 / U/I/J/K) ===
-- xremap が Ctrl+Alt+矢印 → Super+矢印、Ctrl+Alt+U/I/J/K → Super+U/I/J/K に変える
-- (GNOME では tiling-assistant 拡張がこれを受けていた)。DMS 既定の Super+矢印 (フォーカス
-- 移動) と Super+U/I (ワークスペース) 、Super+J/K は外し、フォーカス移動は Super+Alt+矢印へ。
--
-- 座標は論理ピクセル。monitor.width/height は物理ピクセルなので scale で割る。
-- reserved は bar などが占める領域。
local function place(fx, fy, fw, fh)
  return function()
    local w = hl.get_active_window()
    local m = hl.get_active_monitor()
    if not w or not m then
      return
    end
    local r = m.reserved
    local lw = m.width / m.scale - r.left - r.right
    local lh = m.height / m.scale - r.top - r.bottom
    local x0 = m.x + r.left
    local y0 = m.y + r.top
    hl.dispatch(hl.dsp.window.float({ action = "set" }))
    hl.dispatch(hl.dsp.window.resize({ x = math.floor(lw * fw), y = math.floor(lh * fh) }))
    hl.dispatch(hl.dsp.window.move({ x = math.floor(x0 + lw * fx), y = math.floor(y0 + lh * fy) }))
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
