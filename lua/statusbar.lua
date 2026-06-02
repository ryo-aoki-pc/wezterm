local wezterm = require("wezterm")
local palette = require("colors").palette
local M = {}

local nf = wezterm.nerdfonts

-- ピル型バッジ用の丸キャップ（tabs.lua と同じ U+E0B6 / U+E0B4）
local LEFT_CAP = utf8.char(0xe0b6)
local RIGHT_CAP = utf8.char(0xe0b4)

-- 日本語曜日（strftime の %a は英語表記のため手動でマッピング）
local WDAYS = { "日", "月", "火", "水", "木", "金", "土" }

-- 各セグメントのアイコン
local ICON_RESIZE = nf.md_arrow_expand_all or nf.cod_move or ""
local ICON_WORKSPACE = nf.cod_window or ""
local ICON_DATE = nf.md_calendar or ""
local ICON_TIME = nf.md_clock_outline or ""

-- バッテリー残量アイコン（10%刻み。インデックス = 残量を10%単位に四捨五入した値）
local BATTERY_ICONS = {
	nf.md_battery_10,
	nf.md_battery_20,
	nf.md_battery_30,
	nf.md_battery_40,
	nf.md_battery_50,
	nf.md_battery_60,
	nf.md_battery_70,
	nf.md_battery_80,
	nf.md_battery_90,
	nf.md_battery,
}

-- バッテリー残量(0.0〜1.0)と充電状態からアイコンを返す
local function battery_icon(charge, charging)
	if charging then
		return nf.md_battery_charging or ""
	end
	local idx = math.min(10, math.max(1, math.floor(charge * 10 + 0.5)))
	return BATTERY_ICONS[idx] or ""
end

function M.apply(config)
	-- 時計を毎秒更新
	config.status_update_interval = 1000

	wezterm.on("update-status", function(window, pane)
		local p = palette
		local segs = {}

		-- 「アイコン + テキスト」のセグメントを追加（アイコンだけ色を付ける）
		local function push(icon, icon_color, text)
			table.insert(segs, { Background = { Color = p.tab_bar_bg } })
			table.insert(segs, { Foreground = { Color = icon_color } })
			table.insert(segs, { Text = icon .. " " })
			table.insert(segs, { Foreground = { Color = p.fg } })
			table.insert(segs, { Text = text .. "  " })
		end

		-- 1) リサイズモード中はピル型バッジで強調（Ctrl+Shift+S → h/j/k/l）
		if window:active_key_table() == "resize_pane" then
			table.insert(segs, { Background = { Color = p.tab_bar_bg } })
			table.insert(segs, { Foreground = { Color = p.warn } })
			table.insert(segs, { Text = LEFT_CAP })
			table.insert(segs, { Background = { Color = p.warn } })
			table.insert(segs, { Foreground = { Color = p.bg } })
			table.insert(segs, { Attribute = { Intensity = "Bold" } })
			table.insert(segs, { Text = ICON_RESIZE .. " リサイズ" })
			table.insert(segs, { Background = { Color = p.tab_bar_bg } })
			table.insert(segs, { Foreground = { Color = p.warn } })
			table.insert(segs, { Text = RIGHT_CAP .. "  " })
		end

		-- 2) ワークスペース名（default 以外のときだけ表示）
		local workspace = window:active_workspace()
		if workspace and workspace ~= "default" then
			push(ICON_WORKSPACE, p.accent2, workspace)
		end

		-- 3) 日付（日本語曜日）+ 4) 時刻
		local wday = WDAYS[tonumber(wezterm.strftime("%w")) + 1]
		push(ICON_DATE, p.accent, wezterm.strftime("%m/%d") .. " (" .. wday .. ")")
		push(ICON_TIME, p.accent, wezterm.strftime("%H:%M"))

		-- 5) バッテリー（ノートPCのみ。デスクトップでは battery_info が空）
		for _, b in ipairs(wezterm.battery_info()) do
			local charging = b.state == "Charging"
			local color = p.ok
			if not charging and b.state_of_charge <= 0.15 then
				color = p.warn -- 残量わずかは警告色
			end
			push(
				battery_icon(b.state_of_charge, charging),
				color,
				string.format("%.0f%%", b.state_of_charge * 100)
			)
			break -- 複数バッテリー搭載機でも先頭のみ表示
		end

		window:set_right_status(wezterm.format(segs))
	end)
end

return M
