local M = {}

M.palette = {
	bg = "#1a1b26",
	fg = "#c0caf5",
	accent = "#7aa2f7",
	accent2 = "#bb9af7",
	tab_bg = "#24283b",
	tab_bar_bg = "#15161e",
	selection_bg = "#283457",
	dim = "#565f89",
	warn = "#e0af68", -- リサイズモード表示などの強調色（黄）
	ok = "#9ece6a", -- バッテリー良好などの正常色（緑）
	ansi = {
		"#15161e",
		"#f7768e",
		"#9ece6a",
		"#e0af68",
		"#7aa2f7",
		"#bb9af7",
		"#7dcfff",
		"#a9b1d6",
	},
	brights = {
		"#414868",
		"#ff7a93",
		"#b9f27c",
		"#ff9e64",
		"#7da6ff",
		"#bb9af7",
		"#0db9d7",
		"#c0caf5",
	},
}

function M.apply(config)
	local p = M.palette
	config.colors = {
		foreground = p.fg,
		background = p.bg,
		cursor_bg = p.accent,
		cursor_fg = p.bg,
		cursor_border = p.accent,
		selection_bg = p.selection_bg,
		selection_fg = p.fg,
		split = p.accent,
		scrollbar_thumb = p.tab_bg,
		ansi = p.ansi,
		brights = p.brights,
		tab_bar = {
			background = p.tab_bar_bg,
			-- ファンシータブバーではタブの見た目は format-tab-title のピルが描画するため、
			-- ここはピルの最初のセルに背景色が無い場合のフォールバックとして機能する
			active_tab = { bg_color = p.accent, fg_color = p.bg, intensity = "Bold" },
			inactive_tab = { bg_color = p.tab_bg, fg_color = p.dim },
			inactive_tab_hover = { bg_color = p.accent2, fg_color = p.bg, italic = true },
			-- タブ間の縦線（境界）を背景に同化させて消す
			inactive_tab_edge = p.tab_bar_bg,
			-- 新規タブ(+)ボタンは控えめに、ホバーでアクセント色
			new_tab = { bg_color = p.tab_bar_bg, fg_color = p.dim },
			new_tab_hover = { bg_color = p.tab_bar_bg, fg_color = p.accent },
		},
	}
end

return M
