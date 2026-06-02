local M = {}

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
	config.window_background_opacity = 0.9 -- 小さくすると Acrylic のブラーがより強く透ける
	config.text_background_opacity = 1.0 -- 文字セルは不透明にして可読性を確保
	config.win32_system_backdrop = "Acrylic" -- Windows 11: アクリル（すりガラス）
	config.macos_window_background_blur = 24 -- macOS でも近い見た目に（Windows では無害）
end

return M
