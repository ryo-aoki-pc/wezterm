local M = {}

function M.apply(config)
	config.window_decorations = "RESIZE"
	config.window_padding = { left = 14, right = 14, top = 10, bottom = 8 }

	config.default_cursor_style = "BlinkingBar"
	config.cursor_blink_rate = 500
	config.cursor_blink_ease_in = "Constant"
	config.cursor_blink_ease_out = "Constant"
end

return M
