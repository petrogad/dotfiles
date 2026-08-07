local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.color_scheme = "Catppuccin Mocha"

config.font = wezterm.font("FiraCode Nerd Font")
config.font_size = 13

config.default_prog = { "/bin/zsh", "-l" }

-- config.use_fancy_tab_bar = false
-- config.hide_tab_bar_if_only_one_tab = true
config.enable_tab_bar = true

config.window_padding = {
  left = 10,
  right = 10,
  top = 10,
  bottom = 5,
}

config.window_decorations = "RESIZE"
config.native_macos_fullscreen_mode = false
config.window_close_confirmation = "NeverPrompt"
config.adjust_window_size_when_changing_font_size = false

config.scrollback_lines = 10000

config.enable_kitty_keyboard = true

config.keys = {
  {
    key = "d",
    mods = "CMD",
    action = wezterm.action.SplitPane({ direction = "Right" }),
  },
  {
    key = "d",
    mods = "CMD|SHIFT",
    action = wezterm.action.SplitPane({ direction = "Down" }),
  },
  -- New tab already ssh'd into helios. Uses system ssh (not an ssh_domain) so
  -- ~/.ssh/config applies: cloudflared ProxyCommand + ControlMaster reuse.
  {
    key = "h",
    mods = "CMD|SHIFT",
    action = wezterm.action.SpawnCommandInNewTab({ args = { "ssh", "helios" } }),
  },
}

return config
