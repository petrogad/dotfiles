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

-- Cmd-click opens a hyperlink even while the app has the mouse — tmux runs with
-- `mouse on`, so a plain click goes to tmux and never reaches WezTerm's link
-- handling. `mouse_reporting = true` makes these bindings apply in that state.
-- The Down is swallowed so tmux doesn't also see a click and move the cursor.
-- Links inside tmux also need the client to have the `hyperlinks` terminal
-- feature, which tmux-agent-mgr's conf enables (it applies on attach).
config.mouse_bindings = {
  {
    event = { Down = { streak = 1, button = "Left" } },
    mods = "CMD",
    mouse_reporting = true,
    action = wezterm.action.Nop,
  },
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "CMD",
    mouse_reporting = true,
    action = wezterm.action.OpenLinkAtMouseCursor,
  },
}

-- Bare URLs in plain text (not OSC 8 links) are found by hyperlink_rules. The
-- default bare-URL rule may end on ")", so "(https://…/pull/6)." opened
-- ".../6)". Replace it with Gruber's pattern: a ")" belongs to the URL only when
-- the URL opened one itself (Wikipedia's Foo_(bar)), and trailing sentence
-- punctuation is never part of it. The other defaults (mailto, bracketed) stay.
local hyperlink_rules = {}
for _, rule in ipairs(wezterm.default_hyperlink_rules()) do
  if not rule.regex:find("\\S+[)/a-zA-Z0-9-]+", 1, true) then
    table.insert(hyperlink_rules, rule)
  end
end
table.insert(hyperlink_rules, {
  regex = [[\b\w+://(?:[^\s()<>]|\([^\s()<>]*\))+(?:\([^\s()<>]*\)|[^\s`!()\[\]{};:'".,<>?«»“”‘’])]],
  format = "$0",
})
config.hyperlink_rules = hyperlink_rules

return config
