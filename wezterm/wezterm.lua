-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices

-- For example, changing the color scheme:
-- config.color_scheme = 'AdventureTime'

config.enable_tab_bar = false
config.font = wezterm.font("IosevkaTermSlab NFM")
config.font_size = 11

config.window_close_confirmation = "NeverPrompt"
-- config.enable_scroll_bar = true
--{
--  "background": "#02000C",
--  "black": "#02000C",
--  "blue": "#2D4367",
--  "brightBlack": "#58615E",
--  "brightBlue": "#2252A4",
--  "brightCyan": "#32d8bc",
--  "brightGreen": "#00855E",
--  "brightPurple": "#8C42CD",
--  "brightRed": "#B2395F",
--  "brightWhite": "#D2E7E4",
--  "brightYellow": "#32d8bc",
--  "cursorColor": "#D2E7E4",
--  "cyan": "#118080",
--  "foreground": "#D2E7E4",
--  "green": "#0D4E3B",
--  "name": "TAWA",
--  "purple": "#643B96",
--  "red": "#632B3D",
--  "selectionBackground": "#92A8A5",
--  "white": "#A0BDB8",
--  "yellow": "#118080"
--}*/

config.window_background_opacity = 1.0 -- 0.8

config.colors = {
  ansi = {
"#050c08", --black
"#69537c", --red
"#32d8bc", --green
"#8d6565", --yellow
"#08af8b", --blue
"#58709b", --magenta
"#A0BDB8", --cyan
"#6fa868", --white
  },
  -- "#48514E",
  brights = {
"#0d1f15",
"#69537c",
"#32d8bc",
"#8d6565",
"#08af8b",
"#58709b",
"#A0BDB8",
"#6fa868",
  },
  
  foreground ="#A0BDB8",
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
-- and finally, return the configuration to wezterm
return config
