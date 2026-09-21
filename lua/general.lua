local wezterm = require("wezterm")
local ui = require("ui")
local M = {}

function M.apply(config)
	config.font = wezterm.font_with_fallback(ui.font_family)
	config.font_size = 12
	config.audible_bell = "Disabled"
	config.scrollback_lines = 100000
	config.harfbuzz_features = { "calt=1", "clig=1", "liga=1" }
	config.inactive_pane_hsb = { saturation = 0.85, brightness = 0.75 }

	-- スクロールバー（つまみの色は colors.lua の scrollbar_thumb）。
	-- window.lua の右パディング(16px)の中に描画されるので内容は狭くならない
	config.enable_scroll_bar = true

	-- Ctrl + +/- のフォント拡縮でウィンドウサイズを追従させない。
	-- 自由リサイズ中にウィンドウが跳ねるのを防ぐ
	config.adjust_window_size_when_changing_font_size = false

	-- コマンドパレット(Ctrl+Shift+P)と文字選択(Ctrl+Shift+U)のフォント。
	-- tabs.lua の window_frame と同じ理由: 既定の Roboto は Nerd Font / 日本語
	-- グリフを持たないため、指定しないとアイコンや日本語が豆腐になる
	config.command_palette_font = wezterm.font_with_fallback(ui.font_family)
	config.command_palette_font_size = 12
	config.char_select_font_size = 12

	-- QuickSelect (Ctrl+Shift+Space): 既定パターン（URL 等）に追加される。
	-- ラベルは bindings.lua の PaneSelect と同じホームポジションに揃える
	config.quick_select_alphabet = "asdfghjkl"
	-- ※ 正規表現はバックスラッシュを含むため長括弧文字列 [[ ]] で書く
	--   （Lua 5.4 は "\s" のような未知のエスケープを構文エラーにする）
	config.quick_select_patterns = {
		[[[0-9a-f]{7,40}]],                                  -- git のコミットハッシュ
		[[[A-Za-z]:[\\/](?:[^\s:*?"<>|]+[\\/])*[^\s:*?"<>|]*]], -- Windows の絶対パス
		[[[^\s]+:\d+(?::\d+)?]],                            -- file:line / file:line:col
	}

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
