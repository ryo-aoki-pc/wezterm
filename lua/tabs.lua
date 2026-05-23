local wezterm = require("wezterm")
local palette = require("colors").palette
local M = {}

local SOLID_RIGHT_ARROW = wezterm.nerdfonts.pl_right_hard_divider

function M.apply(config)
	config.use_fancy_tab_bar = false
	config.tab_bar_at_bottom = false
	config.hide_tab_bar_if_only_one_tab = false
	config.tab_max_width = 48
	config.show_new_tab_button_in_tab_bar = true

	wezterm.on("format-tab-title", function(tab, tabs, panes, conf, hover, max_width)
		local bg, fg
		if tab.is_active then
			bg, fg = palette.accent, palette.bg
		elseif hover then
			bg, fg = palette.accent2, palette.bg
		else
			bg, fg = palette.tab_bg, palette.fg
		end

		local pane_title = tab.active_pane.title or ""
		local title = string.format("   %d  %s   ", tab.tab_index + 1, pane_title)
		title = wezterm.truncate_right(title, max_width - 2)

		return {
			{ Background = { Color = bg } },
			{ Foreground = { Color = fg } },
			{ Attribute = { Intensity = tab.is_active and "Bold" or "Normal" } },
			{ Text = title },
			{ Background = { Color = palette.tab_bar_bg } },
			{ Foreground = { Color = bg } },
			{ Text = SOLID_RIGHT_ARROW },
		}
	end)
end

return M
