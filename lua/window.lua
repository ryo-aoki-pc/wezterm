local wezterm = require("wezterm")
local M = {}

function M.apply(config)
	-- タイトルバー無し + リサイズ枠 + タブバー右端の 最小化/最大化/閉じる。
	-- 端末の表示領域が広がり、タブバーがタイトルバーを兼ねる。
	--   移動   : タブバーの空き（タブや ＋ の無い帯）を左ドラッグ / Win+左ドラッグ
	--   リサイズ: ウィンドウの縁をドラッグ
	-- INTEGRATED_BUTTONS はファンシータブバー前提なので、tabs.lua の
	-- use_fancy_tab_bar = true / hide_tab_bar_if_only_one_tab = false を変えないこと
	-- （タブバーが消えるとボタンとドラッグ帯ごと消える）。
	-- ボタンの見た目は integrated_title_button_style の既定（macOS 以外は "Windows"）に任せる。
	local target = wezterm.target_triple
	local is_windows = target:find("windows") ~= nil
	local is_linux = target:find("linux") ~= nil
	-- Wayland（GNOME/mutter 等 xdg-decoration 非対応コンポジタ）でも同じ装飾を使う。
	-- サーバー側装飾が出ず、既定の "TITLE|RESIZE" では WezTerm がフレームを一切描かない。
	-- タブバーのドラッグ移動も Wayland では未実装のため、ウィンドウ操作の取っかかりが
	-- 無くなる（wezterm #7155）。かといって "TITLE"（= WezTerm 自前の CSD フレーム）は
	-- 最大化・タイル時に本文をモニタ全面と同じ大きさにしたうえでフレームを外側に足すため、
	-- ウィンドウが画面より一回り大きくなり下端と右端が見切れる。
	-- INTEGRATED_BUTTONS はフレームを持たないので最大化サイズが正しいまま、
	-- ボタンだけは残る。移動・リサイズは GNOME 標準の Win+ドラッグ / Win+中ドラッグで行う
	local is_wayland = is_linux and os.getenv("WAYLAND_DISPLAY") ~= nil

	if is_windows or is_wayland then
		config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
	else
		-- macOS / Linux X11 はネイティブのタイトルバーが問題なく出るのでそのまま使う
		config.window_decorations = "TITLE|RESIZE"
	end
	config.window_padding = { left = 16, right = 16, top = 12, bottom = 10 }

	config.default_cursor_style = "BlinkingUnderline"
	config.cursor_blink_rate = 500
	config.cursor_blink_ease_in = "Constant"
	config.cursor_blink_ease_out = "Constant"

	-- 半透明 + ブラー（すりガラス風）
	-- ※ 文字セル(text_background_opacity)とタブバー背景は不透明のままにして可読性を確保
	--    （タイトルバー無し + Acrylic + 半透明タブバーで幽霊ウィンドウボタンが出た
	--    wezterm #5348 は修正済みだが、半透明のタブバーは文字とボタンが沈んで読みにくい）
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
