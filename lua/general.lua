local wezterm = require("wezterm")
local M = {}

function M.apply(config)
	config.font = wezterm.font("HackGen Console NF")
	config.font_size = 12
	config.audible_bell = "Disabled"
	config.scrollback_lines = 100000
	config.harfbuzz_features = { "calt=1", "clig=1", "liga=1" }
	config.inactive_pane_hsb = { saturation = 0.85, brightness = 0.75 }

	-- 滑らかな描画・アニメーション
	config.max_fps = 120
	config.animation_fps = 60

	-- コントラスト比が低すぎる文字色を自動補正（WCAG AA 相当の 4.5:1 を確保）※nightly 限定
	-- 例: `ls` の濃紺ディレクトリ名 × 黒背景など。ペイン内のセルのみが対象で、
	-- タブバーやステータスバーのピル配色には影響しない
	config.text_min_contrast_ratio = 4.5

	-- QuickSelect (Ctrl+Shift+Space) 中は画面の色装飾を外してラベルを見やすくする ※nightly 限定
	config.quick_select_remove_styling = true

	-- 視覚ベル（音は鳴らさず、ベル時にカーソル色が一瞬フェードする上品な演出）
	config.visual_bell = {
		fade_in_duration_ms = 75,
		fade_in_function = "EaseIn",
		fade_out_duration_ms = 150,
		fade_out_function = "EaseOut",
		target = "CursorColor",
	}
end

return M
