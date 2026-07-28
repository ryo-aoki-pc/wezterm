local wezterm = require("wezterm")
local config = wezterm.config_builder()

package.path = wezterm.config_dir .. "/lua/?.lua;" .. package.path

require("general").apply(config)
require("colors").apply(config)
require("window").apply(config)
require("tabs").apply(config)
require("statusbar").apply(config)
require("shells").apply(config)
require("links").apply(config)
require("bindings").apply(config)

return config
