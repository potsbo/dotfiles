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

-- Hide title bar (macos-titlebar-style = hidden)
config.window_decorations = "RESIZE"

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
  -- Linux: xremap が Super-n/q → Ctrl+Shift+n/q に変換して送ってくる
  { key = "n", mods = "CTRL|SHIFT", action = wezterm.action.SpawnWindow },
  { key = "q", mods = "CTRL|SHIFT", action = wezterm.action.QuitApplication },
}

return config
