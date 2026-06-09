local M = {}

-- 半透明 + Acrylic は描画負荷が高く、Windows 11 で不安定化/クラッシュの一因に
-- なり得る (wezterm #6111 / #5348)。general.lua の front_end=OpenGL 化だけで
-- クラッシュが止まらない場合は、まずここを false にして半透明/Acrylic を切り分ける。
local enable_acrylic = true

function M.apply(config)
	config.window_decorations = "RESIZE"
	config.window_padding = { left = 16, right = 16, top = 12, bottom = 10 }

	config.default_cursor_style = "BlinkingUnderline"
	config.cursor_blink_rate = 500
	config.cursor_blink_ease_in = "Constant"
	config.cursor_blink_ease_out = "Constant"

	-- 半透明 + ブラー（すりガラス風）
	-- ※ 文字セル(text_background_opacity)とタブバー背景は不透明のままにして、
	--    RESIZE 装飾 + Acrylic 併用時の幽霊ウィンドウボタン (wezterm #5348) を避ける
	-- ※ ファンシータブバー(tabs.lua)の window_frame 背景も同様に不透明を維持すること
	if enable_acrylic then
		config.window_background_opacity = 0.9 -- 小さくすると Acrylic のブラーがより強く透ける
		config.text_background_opacity = 1.0 -- 文字セルは不透明にして可読性を確保
		config.win32_system_backdrop = "Acrylic" -- Windows 11: アクリル（すりガラス）
		config.macos_window_background_blur = 24 -- macOS でも近い見た目に（Windows では無害）
	else
		-- 切り分け用: 完全不透明 + Acrylic 無効
		config.window_background_opacity = 1.0
		config.win32_system_backdrop = "Disable"
	end
end

return M
