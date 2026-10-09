local M = {}

-- 色は Tokyo Night（night）から選んでいる。役割は README の「配色」の表と同じ
M.palette = {
	bg = "#1a1b26",
	fg = "#c0caf5",
	accent = "#7aa2f7",
	accent2 = "#bb9af7",
	surface = "#292e42", -- 浮かせる面（アクティブなタブ・コマンドパレット・選択 UI のラベル）
	tab_bar_bg = "#15161e",
	selection_bg = "#283457",
	match_bg = "#3d59a1", -- QuickSelect の一致の面
	hint = "#ff9e64", -- 打つラベルの橙（QuickSelect・ペインの選択）
	muted = "#737aa2", -- 控えめな文字（非アクティブなタブ・日付と時刻）。タブバーの背景に対して 4.3:1
	dim = "#565f89", -- 飾りのアイコン（日付・時刻）
	line = "#3b4261", -- 分割線・スクロールバーのつまみ
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
	-- tokyonight.nvim が配っている WezTerm 用の配色（extras/wezterm/tokyonight_night.toml）と同じ。
	-- どれも通常の色より一段明るい
	brights = {
		"#414868",
		"#ff899d",
		"#9fe044",
		"#faba4a",
		"#8db0ff",
		"#c7a9ff",
		"#a4daff",
		"#c0caf5",
	},
}

function M.apply(config)
	local p = M.palette

	-- コマンドパレット (Ctrl+Shift+P) と文字選択 (Ctrl+Shift+U) の配色。
	-- 既定の背景 #333333（灰色）はこの配色から浮くので、アクティブなタブと同じ面の色に揃える
	-- （フォントは general.lua で指定済み）
	config.command_palette_bg_color = p.surface
	config.command_palette_fg_color = p.fg
	config.char_select_bg_color = p.surface
	config.char_select_fg_color = p.fg

	-- ペインのラベル選択 (Ctrl+Shift+Alt+P / S) の文字。既定の灰色を QuickSelect のラベルと同じ橙に
	config.pane_select_fg_color = p.hint

	-- タブバー右端の 最小化 / 最大化 / 閉じる の線（既定の "Auto" は暗い背景だと純白）。
	-- 閉じるボタンに乗せたときの赤は WezTerm の固定で、変えられない
	config.integrated_title_button_color = p.fg

	config.colors = {
		foreground = p.fg,
		background = p.bg,
		cursor_bg = p.accent,
		cursor_fg = p.bg,
		cursor_border = p.accent,
		selection_bg = p.selection_bg,
		selection_fg = p.fg,
		-- IME 変換中（未確定）のカーソル色。確定すると cursor_bg の青に戻るため、
		-- 日本語入力で「今は未確定」が一目で分かる
		compose_cursor = p.warn,
		-- 分割線とスクロールバーは控えめな線にする。どのペインにいるかは、
		-- 非アクティブなペインを暗くして示す（general.lua の inactive_pane_hsb）
		split = p.line,
		scrollbar_thumb = p.line,
		-- 検索 (Ctrl+Shift+F) の一致の色（copy_mode_*_highlight_*）は既定（ANSI の明るい紫の面）のまま。
		-- 今の一致は WezTerm が選択範囲にするので、選択範囲の色（selection_bg の紺）で描かれ、
		-- copy_mode_active_highlight の色は隠れる。ほかの一致を控えめな色にすると、
		-- 今の一致の方が目立たなくなる
		-- QuickSelect (Ctrl+Shift+Space) と URL を開く (Ctrl+Shift+O)。一致は青い面、
		-- 打つラベルは橙（既定は黒地に緑 / 黄の文字）
		quick_select_match_bg = { Color = p.match_bg },
		quick_select_match_fg = { Color = p.fg },
		quick_select_label_bg = { Color = p.hint },
		quick_select_label_fg = { Color = p.bg },
		-- シェルピッカー(InputSelector)と起動メニュー(Launcher)の項目ラベル配色 ※nightly 限定
		-- 値は { Color = "#…" } のオブジェクト形式（文字列だけでは受け付けない）
		input_selector_label_bg = { Color = p.surface },
		input_selector_label_fg = { Color = p.fg },
		launcher_label_bg = { Color = p.surface },
		launcher_label_fg = { Color = p.fg },
		ansi = p.ansi,
		brights = p.brights,
		tab_bar = {
			-- タブバーの帯は tabs.lua の window_frame が塗る。これはステータスで背景を指定していないセルの色
			background = p.tab_bar_bg,
			-- ファンシータブバーは、format-tab-title の最初のセルの背景をタブの箱（余白と角）の色にし、
			-- 最初のセルに色が無いときだけ下の色を使う。アクティブなタブは tabs.lua が色を付けて
			-- ピルを描くので active_tab は予備。非アクティブなタブは色を付けないので、
			-- inactive_tab / inactive_tab_hover がそのまま効く（マウスを乗せると文字が明るくなる。
			-- 乗っているかは WezTerm がピクセル単位で判定する）。
			-- ※ タブバーは 1 つのフォントで描かれるので、intensity（太字）・italic は効かない
			active_tab = { bg_color = p.surface, fg_color = p.fg },
			inactive_tab = { bg_color = p.tab_bar_bg, fg_color = p.muted },
			inactive_tab_hover = { bg_color = p.tab_bar_bg, fg_color = p.fg },
			-- タブ間の縦線（境界）を背景に同化させて消す
			inactive_tab_edge = p.tab_bar_bg,
			-- 新規タブ(+)ボタンも、タブと同じく乗せると明るくなる
			new_tab = { bg_color = p.tab_bar_bg, fg_color = p.muted },
			new_tab_hover = { bg_color = p.tab_bar_bg, fg_color = p.fg },
		},
	}
end

return M
