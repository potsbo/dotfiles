local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- Theme
config.color_scheme = "Monokai Remastered"

-- Font
config.font_size = 13.0
config.font = wezterm.font_with_fallback({
  { family = "JetBrains Mono", weight = "Medium", harfbuzz_features = { "calt=0", "liga=0", "dlig=0" } },
  "Symbols Nerd Font Mono",
  "BIZ UDGothic",
})

-- macOS: left Option as Alt, right Option as compose (default macOS behavior)
config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = true

-- IME (Linux only; macOS handles IME natively)
if wezterm.target_triple:find("linux") then
  config.use_ime = true
  config.xim_im_name = "fcitx"
end

-- Hide title bar
-- macOS: "RESIZE" hides title bar but keeps resize ability
-- Linux: "NONE" removes WM title bar to avoid bottom row clipping
config.window_decorations = wezterm.target_triple:find("linux") and "NONE" or "RESIZE"

-- Snap window size to cell boundaries so the bottom row isn't clipped
config.use_resize_increments = true

-- Hide tab bar
config.enable_tab_bar = false

-- Remove window padding
config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}

-- Skip close confirmation when tmux is the foreground process
config.skip_close_confirmation_for_processes_named = {
  "bash", "sh", "zsh", "fish", "tmux", "tuicast", "tsuimux",
}

-- Keybindings (neovim integration)
config.keys = {
  { key = "p", mods = "SUPER", action = wezterm.action.SendString("\x1b:CommandP\r") },
  { key = "s", mods = "SUPER", action = wezterm.action.SendString("\x1b:w\r") },
  { key = "\\", mods = "SUPER", action = wezterm.action.SendString("\x1b:vsplit\r") },
  { key = "r", mods = "SUPER", action = wezterm.action.SendString("\x1b:e!\r") },
  { key = " ", mods = "SUPER|SHIFT", action = wezterm.action.QuickSelect },
  -- Linux: xremap terminal rule が Super+key → Ctrl+Shift+key に変換して送ってくる
  { key = "v", mods = "CTRL|SHIFT", action = wezterm.action.PasteFrom("Clipboard") },
  { key = "c", mods = "CTRL|SHIFT", action = wezterm.action.CopyTo("Clipboard") },
  { key = "w", mods = "CTRL|SHIFT", action = wezterm.action.CloseCurrentTab({ confirm = false }) },
  { key = "n", mods = "CTRL|SHIFT", action = wezterm.action.SpawnWindow },
  { key = "q", mods = "CTRL|SHIFT", action = wezterm.action.QuitApplication },
}

return config
