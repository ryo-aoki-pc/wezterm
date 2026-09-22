local wezterm = require("wezterm")
local M = {}

function M.apply(config)
	-- ネイティブのタイトルバー + リサイズ枠（Windows / macOS / Linux X11）
	config.window_decorations = "TITLE|RESIZE"

	-- Linux の Wayland セッション（GNOME/mutter 等 xdg-decoration 非対応コンポジタ）では
	-- サーバー側装飾が出ず、既定の "TITLE|RESIZE" だと WezTerm がフレームを一切描かない。
	-- タブバーのドラッグ移動も Wayland では未実装のため、ウィンドウ操作の取っかかりが無くなる
	-- （wezterm #7155）。
	-- ただし "TITLE"（= WezTerm 自前の CSD フレーム: ヘッダ + 4px の縁 + 3 ボタン）にすると、
	-- 最大化・タイル時に本文をモニタ全面と同じ大きさにしたうえでフレームを外側に足すため、
	-- ウィンドウが画面より一回り大きくなり下端と右端が見切れる
	-- （mutter も "Client provided invalid window geometry" を警告する）。
	-- INTEGRATED_BUTTONS ならフレームを持たず、タブバーの右端に 最小化/最大化/閉じる が載るので、
	-- 最大化サイズが正しいままマウスでのウィンドウ操作も残る。
	-- 移動・リサイズは GNOME 標準の Super+ドラッグ / Super+中ドラッグでも行える
	local is_linux = wezterm.target_triple:find("linux") ~= nil
	if is_linux and os.getenv("WAYLAND_DISPLAY") then
		config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
	end
	config.window_padding = { left = 16, right = 16, top = 12, bottom = 10 }

	config.default_cursor_style = "BlinkingUnderline"
	config.cursor_blink_rate = 500
	config.cursor_blink_ease_in = "Constant"
	config.cursor_blink_ease_out = "Constant"

	-- 半透明 + ブラー（すりガラス風）
	-- ※ 文字セル(text_background_opacity)とタブバー背景は不透明のままにして可読性を確保。
	--    （タイトルバー無し "RESIZE" + Acrylic + 半透明タブバーで幽霊ウィンドウボタンが
	--    出る wezterm #5348 の回避策でもあったが、今はネイティブタイトルバーなので主目的は可読性）
	-- ※ ファンシータブバー(tabs.lua)の window_frame 背景も同様に不透明を維持すること
	config.window_background_opacity = 0.9 -- 小さくすると Acrylic のブラーがより強く透ける
	config.text_background_opacity = 1.0 -- 文字セルは不透明にして可読性を確保
	config.win32_system_backdrop = "Acrylic" -- Windows 11: アクリル（すりガラス）
	config.macos_window_background_blur = 24 -- macOS でも近い見た目に（Windows では無害）

	-- ウィンドウサイズがセルの整数倍でないときの端数余白を上下左右に均等配分する ※nightly 限定
	-- 自由リサイズ時に内容が左上に張り付かず、padding が対称に見える
	config.window_content_alignment = { horizontal = "Center", vertical = "Center" }
end

return M
