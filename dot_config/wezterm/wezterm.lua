-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- Create the configuration
local config = wezterm.config_builder()

-----------------------------------------------------------
-- Font & UI
-----------------------------------------------------------
config.font = wezterm.font("IosevkaTermSlab NFM")
config.font_size = 20.0
config.line_height = 1.05
config.enable_tab_bar = false
config.use_fancy_tab_bar = false
config.enable_scroll_bar = false
config.window_background_opacity = 0.90
-- config.kde_window_background_blur = true
config.window_close_confirmation = "NeverPrompt"
config.enable_wayland = true

-----------------------------------------------------------
-- Colors
-----------------------------------------------------------
config.colors = {
  ansi = {
    "#050c08", -- black
    "#69537c", -- red
    "#32d8bc", -- green
    "#8d6565", -- yellow
    "#08af8b", -- blue
    "#58709b", -- magenta
    "#A0BDB8", -- cyan
    "#6fa868", -- white
  },
  brights = {
    "#4d5f55",
    "#69537c",
    "#32d8bc",
    "#8d6565",
    "#08af8b",
    "#58709b",
    "#A0BDB8",
    "#6fa868",
  },
  foreground = "#A0BDB8",
  background = "#050c08",
  cursor_bg = "#32d8bc",
  cursor_fg = "#02000C",
  cursor_border = "#32d8bc",
  selection_fg = "#02000C",
  selection_bg = "#32d8bc",
  scrollbar_thumb = "#118080",
  split = "#32d8bc",
}
config.bold_brightens_ansi_colors = true

-----------------------------------------------------------
-- Clipboard & Mouse
-----------------------------------------------------------
-- Copy selection on mouse release
config.mouse_bindings = {
  {
    event={Up={streak=1, button="Left"}},
    mods=nil,
    action=wezterm.action.CompleteSelection "Clipboard"
  },
}

config.selection_word_boundary = " \t\n"

-- Explicit keybindings for clipboard
config.keys = {
  {key="C", mods="CTRL|SHIFT", action=wezterm.action.CopyTo "Clipboard"},
  {key="V", mods="CTRL|SHIFT", action=wezterm.action.PasteFrom "Clipboard"},
  {key="Insert", mods="SHIFT", action=wezterm.action.CopyTo "Clipboard"},
  {key="Insert", mods="CTRL", action=wezterm.action.PasteFrom "Clipboard"},
}

-----------------------------------------------------------
-- Return the configuration to WezTerm
-----------------------------------------------------------
return config
