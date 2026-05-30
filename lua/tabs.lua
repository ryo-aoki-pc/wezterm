local wezterm = require("wezterm")
local palette = require("colors").palette
local M = {}

-- 丸型のパワーライン区切り（ピル状タブ）
-- U+E0B6 = 左半円, U+E0B4 = 右半円（Nerd Font / Powerline Extra）
-- もしタブ端が □（豆腐）で表示される場合はハード区切りに変更:
--   local LEFT_CAP  = wezterm.nerdfonts.pl_left_hard_divider
--   local RIGHT_CAP = wezterm.nerdfonts.pl_right_hard_divider
local LEFT_CAP = utf8.char(0xe0b6)
local RIGHT_CAP = utf8.char(0xe0b4)
local ZOOM_ICON = wezterm.nerdfonts.md_magnify or ""

function M.apply(config)
	config.use_fancy_tab_bar = false
	config.tab_bar_at_bottom = false
	config.hide_tab_bar_if_only_one_tab = false
	config.tab_max_width = 40
	config.show_new_tab_button_in_tab_bar = true

	wezterm.on("format-tab-title", function(tab, tabs, panes, conf, hover, max_width)
		local bg, fg
		if tab.is_active then
			bg, fg = palette.accent, palette.bg
		elseif hover then
			bg, fg = palette.accent2, palette.bg
		else
			bg, fg = palette.tab_bg, palette.dim
		end

		local title = tab.active_pane.title or ""
		-- ズーム中のペインは虫眼鏡を表示
		local zoom = tab.active_pane.is_zoomed and (" " .. ZOOM_ICON) or ""
		local label = string.format(" %d%s  %s ", tab.tab_index + 1, zoom, title)
		-- 両端の丸キャップ分を差し引いて切り詰め
		label = wezterm.truncate_right(label, max_width - 4)

		return {
			-- 左の丸キャップ
			{ Background = { Color = palette.tab_bar_bg } },
			{ Foreground = { Color = bg } },
			{ Text = LEFT_CAP },
			-- 本体
			{ Background = { Color = bg } },
			{ Foreground = { Color = fg } },
			{ Attribute = { Intensity = tab.is_active and "Bold" or "Normal" } },
			{ Text = label },
			-- 右の丸キャップ
			{ Background = { Color = palette.tab_bar_bg } },
			{ Foreground = { Color = bg } },
			{ Text = RIGHT_CAP },
		}
	end)
end

return M
