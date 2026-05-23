local wezterm = require("wezterm")
local M = {}

function M.apply(config)
	config.font = wezterm.font("HackGen Console NF")
	config.font_size = 12
	config.audible_bell = "Disabled"
	config.scrollback_lines = 100000
	config.harfbuzz_features = { "calt=1", "clig=1", "liga=1" }
	config.inactive_pane_hsb = { saturation = 0.85, brightness = 0.75 }
end

return M
