local wezterm = require("wezterm")
local palette = require("colors").palette
local M = {}

local nf = wezterm.nerdfonts

-- 丸型のパワーライン区切り（ピル状タブ）
-- U+E0B6 = 左半円, U+E0B4 = 右半円（Nerd Font / Powerline Extra）
-- もしタブ端が □（豆腐）で表示される場合はハード区切りに変更:
--   local LEFT_CAP  = wezterm.nerdfonts.pl_left_hard_divider
--   local RIGHT_CAP = wezterm.nerdfonts.pl_right_hard_divider
local LEFT_CAP = utf8.char(0xe0b6)
local RIGHT_CAP = utf8.char(0xe0b4)
local ZOOM_ICON = nf.md_magnify or ""

-- 汎用端末アイコン（未知のプロセス・プロセス名が取れない場合のフォールバック）
local GENERIC_ICON = nf.cod_terminal or nf.md_console or utf8.char(0xe795)

-- 実行中プロセス名 → Nerd Font アイコン
-- ※ キーが存在しない wezterm バージョンでも nil エラーにならないよう or でガード
local PROCESS_ICONS = {
	-- シェル
	["pwsh"] = nf.md_powershell or GENERIC_ICON,
	["powershell"] = nf.md_powershell or GENERIC_ICON,
	["cmd"] = nf.cod_terminal_cmd or GENERIC_ICON,
	["bash"] = nf.cod_terminal_bash or GENERIC_ICON,
	["sh"] = nf.cod_terminal_bash or GENERIC_ICON,
	["zsh"] = nf.dev_terminal or GENERIC_ICON,
	["fish"] = nf.md_fish or GENERIC_ICON,
	["nu"] = nf.md_console or GENERIC_ICON,
	-- WSL / Linux
	["wsl"] = nf.linux_tux or GENERIC_ICON,
	["wslhost"] = nf.linux_tux or GENERIC_ICON,
	-- エディタ
	["nvim"] = nf.custom_neovim or nf.custom_vim or GENERIC_ICON,
	["vim"] = nf.custom_vim or GENERIC_ICON,
	-- 開発ツール
	["node"] = nf.md_nodejs or GENERIC_ICON,
	["python"] = nf.md_language_python or GENERIC_ICON,
	["python3"] = nf.md_language_python or GENERIC_ICON,
	["git"] = nf.dev_git or GENERIC_ICON,
	["lazygit"] = nf.dev_git or GENERIC_ICON,
	["gh"] = nf.oct_mark_github or GENERIC_ICON,
	["cargo"] = nf.dev_rust or GENERIC_ICON,
	["rustc"] = nf.dev_rust or GENERIC_ICON,
	["go"] = nf.md_language_go or GENERIC_ICON,
	["docker"] = nf.md_docker or GENERIC_ICON,
	["kubectl"] = nf.md_docker or GENERIC_ICON,
	["ssh"] = nf.cod_remote or GENERIC_ICON,
	-- モニタリング
	["top"] = nf.md_chart_line or GENERIC_ICON,
	["htop"] = nf.md_chart_line or GENERIC_ICON,
	["btop"] = nf.md_chart_line or GENERIC_ICON,
}

-- ConEmu 方式 (OSC 9;4) の進捗表示用グリフ（12.5% 刻みの円スライス）
local PROGRESS_SLICES = {
	nf.md_circle_slice_1,
	nf.md_circle_slice_2,
	nf.md_circle_slice_3,
	nf.md_circle_slice_4,
	nf.md_circle_slice_5,
	nf.md_circle_slice_6,
	nf.md_circle_slice_7,
	nf.md_circle_slice_8,
}
local ICON_PROGRESS_ERROR = nf.md_close_circle or ""
local ICON_PROGRESS_BUSY = nf.md_dots_circle or ""

-- ペインが報告した進捗（winget / pacman / yazi 等が OSC 9;4 で送る）から
-- 「表示テキスト + 色」を返す ※pane.progress は nightly 限定フィールド。
-- フィールドが無いバージョンや未報告 ("None") のときは nil を返して何も描かない
local function progress_cell(pane)
	local pr = pane and pane.progress
	if not pr or pr == "None" then
		return nil
	end
	if pr == "Indeterminate" then
		return ICON_PROGRESS_BUSY, palette.accent2
	end
	if type(pr) == "table" then
		if pr.Percentage then
			local pct = math.min(100, math.max(0, pr.Percentage))
			local slice = PROGRESS_SLICES[math.min(8, math.max(1, math.ceil(pct / 12.5)))] or ""
			return string.format("%s %d%%", slice, pct), palette.ok
		end
		if pr.Error then
			return string.format("%s %d%%", ICON_PROGRESS_ERROR, pr.Error), palette.ansi[2]
		end
	end
	return nil
end

-- ペインのフォアグラウンドプロセスからアイコンを決定する。
-- 例: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" → "pwsh" → PowerShell アイコン
local function process_icon(pane)
	local name = (pane and pane.foreground_process_name) or ""
	-- パス末尾のみ取り出し（Windows の \ と Unix の / 両対応）→ .exe 除去 → 小文字化
	name = name:match("([^/\\]+)$") or ""
	name = name:gsub("%.exe$", ""):lower()
	if name == "" then
		-- WSL ペイン等ではプロセス名が取れないことが多い
		return GENERIC_ICON
	end
	return PROCESS_ICONS[name] or GENERIC_ICON
end

function M.apply(config)
	-- ファンシータブバー: タイトルフォント行高の約1.75倍の高さになり、
	-- タブの上下に余白が生まれる（レトロタブバーは1セル固定で調整不可）
	config.use_fancy_tab_bar = true
	config.tab_bar_at_bottom = false
	config.hide_tab_bar_if_only_one_tab = false
	config.tab_max_width = 40
	config.show_new_tab_button_in_tab_bar = true
	-- タブ内の×ボタンを消してピルの見た目を保つ（閉じるのは Ctrl+Shift+W）※nightly 限定
	config.show_close_tab_button_in_tabs = false

	-- タブバー（タイトルバー）のフォントと背景
	-- ※ フォント指定は必須: デフォルトの Roboto は Nerd Font / Powerline / 日本語
	--   グリフを持たないため、ピルの丸キャップやアイコンが豆腐になる
	-- ※ 背景は不透明のまま（window.lua の #5348 幽霊ボタン対策を維持）
	config.window_frame = {
		font = wezterm.font("HackGen Console NF"),
		font_size = 11.0, -- 本文(12)より少し小さめ。タブバーの高さもこれで決まる
		active_titlebar_bg = palette.tab_bar_bg,
		inactive_titlebar_bg = palette.tab_bar_bg,
	}

	wezterm.on("format-tab-title", function(tab, tabs, panes, conf, hover, max_width)
		local bg, fg
		if tab.is_active then
			bg, fg = palette.accent, palette.bg
		elseif hover then
			bg, fg = palette.accent2, palette.bg
		else
			bg, fg = palette.tab_bg, palette.dim
		end

		local icon = process_icon(tab.active_pane)
		-- 明示的に付けたタブ名 (Ctrl+Shift+Alt+T) があれば優先、無ければペインのタイトル
		local title = tab.tab_title
		if not title or #title == 0 then
			title = tab.active_pane.title or ""
		end
		-- ズーム中のペインは虫眼鏡を表示
		local zoom = tab.active_pane.is_zoomed and (" " .. ZOOM_ICON) or ""
		-- ファンシータブバーでは max_width が実質無制限のため、固定幅で切り詰める
		title = wezterm.truncate_right(title, 24)
		local label = string.format(" %d %s  %s%s ", tab.tab_index + 1, icon, title, zoom)

		local elements = {
			-- 左の丸キャップ
			{ Background = { Color = palette.tab_bar_bg } },
			{ Foreground = { Color = bg } },
			{ Text = LEFT_CAP },
			-- 本体（番号 + プロセスアイコン + タイトル）
			{ Background = { Color = bg } },
			{ Foreground = { Color = fg } },
			{ Attribute = { Intensity = tab.is_active and "Bold" or "Normal" } },
			{ Text = label },
		}

		-- 実行中コマンドの進捗（報告があるときだけピル本体の右側に差し込む）
		local ptext, pcolor = progress_cell(tab.active_pane)
		if ptext then
			-- アクティブタブはピル背景が明るいため、文字色は他と同じ暗色に倒して馴染ませる
			table.insert(elements, { Foreground = { Color = tab.is_active and palette.bg or pcolor } })
			table.insert(elements, { Text = ptext .. " " })
		end

		-- 右の丸キャップ
		table.insert(elements, { Background = { Color = palette.tab_bar_bg } })
		table.insert(elements, { Foreground = { Color = bg } })
		table.insert(elements, { Text = RIGHT_CAP })

		return elements
	end)
end

return M
