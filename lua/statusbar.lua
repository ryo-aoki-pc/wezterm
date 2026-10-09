local wezterm = require("wezterm")
local palette = require("colors").palette
local M = {}

local nf = wezterm.nerdfonts

-- 日本語曜日（strftime の %a は英語表記のため手動でマッピング）
local WDAYS = { "日", "月", "火", "水", "木", "金", "土" }

-- 各セグメントのアイコン
local ICON_WORKSPACE = nf.cod_window or ""
local ICON_DATE = nf.md_calendar or ""
local ICON_TIME = nf.md_clock_outline or ""

-- モード（キーテーブル）→ バッジ。キーは window:active_key_table() が返す名前。
-- copy_mode / search_mode は WezTerm 組み込みのコピーモード・検索のオーバーレイが使う名前
-- ※ タブ名は cwd 表示を優先する（tabs.lua）ため、標準の「Copy mode: …」というタブ
--   タイトルは出ない。モードに入ったことはここで示す
local MODE_BADGES = {
	resize_pane = { icon = nf.md_arrow_expand_all or nf.cod_move or "", text = "リサイズ", color = palette.warn },
	copy_mode = { icon = nf.md_content_copy or "", text = "コピー", color = palette.accent },
	search_mode = { icon = nf.md_magnify or "", text = "検索", color = palette.accent2 },
}

-- 一時メッセージ（actions.lua の「直前の出力をコピー」などの結果）の見た目
local FLASH_STYLES = {
	ok = { icon = nf.md_check or "", color = palette.ok },
	warn = { icon = nf.md_alert_circle_outline or "", color = palette.warn },
}
local FLASH_SECONDS = 3

-- ウィンドウ ID → { text, style, expires }。期限切れは次の描画で消す
local flashes = {}

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

local function render(window)
	local p = palette
	local segs = {}

	-- 「アイコン + テキスト」のセグメントを追加（text_color を省くと fg）
	local function push(icon, icon_color, text, text_color)
		table.insert(segs, { Background = { Color = p.tab_bar_bg } })
		table.insert(segs, { Foreground = { Color = icon_color } })
		table.insert(segs, { Text = icon .. " " })
		table.insert(segs, { Foreground = { Color = text_color or p.fg } })
		table.insert(segs, { Text = text .. "  " })
	end

	-- 知らせのバッジ（一時メッセージ・モード）。アイコンも文字もその色にする。
	-- ※ 面で塗ったピルにはしない。ステータスは WezTerm が 1.75 行の高さで描くので、
	--   面が帯の上下いっぱいに広がり、端の半円も縦長になってタブのピルと形が揃わない。
	--   タブバーは 1 つのフォントで描かれるので、太字にもできない
	local function badge(icon, text, color)
		push(icon, color, text, color)
	end

	-- バッジを出したか（出している間は下の日付・時刻を省く）
	local badged = false

	-- 1) 一時メッセージ（M.flash。数秒で消える）
	local id = window:window_id()
	local f = flashes[id]
	if f then
		if os.time() < f.expires then
			badge(f.style.icon, f.text, f.style.color)
			badged = true
		else
			flashes[id] = nil
		end
	end

	-- 2) モード中はバッジで知らせる
	--    リサイズ (Ctrl+Shift+S) / コピーモード (Ctrl+Shift+X) / 検索 (Ctrl+Shift+F)
	local mode = MODE_BADGES[window:active_key_table() or ""]
	if mode then
		badge(mode.icon, mode.text, mode.color)
		badged = true
	end

	-- 3) ワークスペース名（default 以外のときだけ表示）
	local workspace = window:active_workspace()
	if workspace and workspace ~= "default" then
		push(ICON_WORKSPACE, p.accent2, workspace)
	end

	-- 4) 日付（日本語曜日）+ 5) 時刻。バッジを出している間は省く
	--    （ステータスはタブの右に置かれ、狭いウィンドウでは収まらない分がタブの下に隠れる。
	--    操作の結果・今のモードを時計より優先する）
	--    日付・時刻・電池の残量は控えめな灰色にし、色は知らせ（一時メッセージ・モード・
	--    ワークスペース・電池の状態）にだけ使う
	if not badged then
		local wday = WDAYS[tonumber(wezterm.strftime("%w")) + 1]
		push(ICON_DATE, p.dim, wezterm.strftime("%m/%d") .. " (" .. wday .. ")", p.muted)
		push(ICON_TIME, p.dim, wezterm.strftime("%H:%M"), p.muted)
	end

	-- 6) バッテリー（ノートPCのみ。デスクトップでは battery_info が空）
	for _, b in ipairs(wezterm.battery_info()) do
		local charging = b.state == "Charging"
		local color = p.ok
		if not charging and b.state_of_charge <= 0.15 then
			color = p.warn -- 残量わずかは警告色
		end
		push(
			battery_icon(b.state_of_charge, charging),
			color,
			string.format("%.0f%%", b.state_of_charge * 100),
			p.muted
		)
		break -- 複数バッテリー搭載機でも先頭のみ表示
	end

	window:set_right_status(wezterm.format(segs))
end

-- ステータスバー（タブバーの右端）に一時メッセージを数秒出す。level は "ok"（緑）/ "warn"（黄）。
-- トースト通知は Windows の通知センターに溜まるため、操作結果の軽い知らせはこちらを使う
function M.flash(window, text, level)
	flashes[window:window_id()] = {
		text = text,
		style = FLASH_STYLES[level] or FLASH_STYLES.ok,
		expires = os.time() + FLASH_SECONDS,
	}
	render(window) -- 次の定期更新（最大 1 秒後）を待たずに出す
end

function M.apply(config)
	-- 時計を毎秒更新（モードバッジと一時メッセージの出し入れもこの間隔）
	config.status_update_interval = 1000

	wezterm.on("update-status", function(window, _pane)
		render(window)
	end)
end

return M
