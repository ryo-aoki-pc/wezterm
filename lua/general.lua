local wezterm = require("wezterm")
local M = {}

function M.apply(config)
	config.font = wezterm.font("HackGen Console NF")
	config.font_size = 12
	config.audible_bell = "Disabled"
	config.scrollback_lines = 100000
	config.harfbuzz_features = { "calt=1", "clig=1", "liga=1" }
	config.inactive_pane_hsb = { saturation = 0.85, brightness = 0.75 }

	-- GPU バックエンド: Windows 11 では既定の WebGpu が、ペイン分割/リサイズ時の
	-- スワップチェーン再生成で無言クラッシュする報告が多い
	-- (wezterm #4279 / #3229 / #2881)。OpenGL に固定して回避する（体感性能差はわずか）。
	-- ※ WebGpu の性能を残したい場合は "WebGpu" に戻し、wezterm.gui.enumerate_gpus() で
	--   得たアダプタを config.webgpu_preferred_adapter に明示する（#3229 の回避策）。
	config.front_end = "OpenGL"

	-- IME は既定で無効（wezterm #7632 の IME 切替クラッシュ回避。Ctrl+Space 等で落ちる問題）。
	-- 一時的に日本語入力したいときは Ctrl+Shift+I で IME 有効の専用ウィンドウを開く（bindings.lua）。
	-- 恒久対策は 2026-06-08 以降の nightly へ更新すること。
	config.use_ime = false

	-- 滑らかな描画・アニメーション
	config.max_fps = 120
	config.animation_fps = 60

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
