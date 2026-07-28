local wezterm = require("wezterm")
local M = {}

function M.apply(config)
	config.font = wezterm.font("HackGen Console NF")
	config.font_size = 12
	-- フォントサイズ変更 (Ctrl + +/-) 時にウィンドウサイズを維持し、行数・桁数の方を変える
	config.adjust_window_size_when_changing_font_size = false
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

	-- QuickSelect の追加パターン（組み込みデフォルトに URL / Unix パス / git SHA /
	-- IPv4 / UUID / #16進色 / 数値は含まれるため、足りないものだけを足す）
	-- ※ 全パターンは 1 つの正規表現に結合されるため、グループは非捕捉 (?:) のみ使うこと
	config.quick_select_patterns = {
		-- Windows のドライブパス（例: C:\Users\ryo\file.txt。空白入りパスは対象外）
		[[\b[A-Za-z]:[\\/](?:[\w.-]+[\\/])*[\w.-]+]],
		-- UNC パス（例: \\server\share\dir）
		[[\\\\[\w.-]+(?:\\[\w.$-]+)+]],
		-- semver（例: v1.2.3-beta.1+build.5）
		[[\bv?\d+\.\d+\.\d+(?:-[\w.]+)?(?:\+[\w.]+)?\b]],
	}

	-- ハイパーリンク規則: デフォルト（http(s)://… や mailto 等）に追記する。
	-- 20230408 以降は fancy-regex になり、先読み・後読み (lookaround) が使える
	config.hyperlink_rules = wezterm.default_hyperlink_rules()
	-- スキーム無しの localhost:ポート（例: localhost:3000 / 127.0.0.1:8080/path）
	-- ※ http://localhost:… の形はデフォルト規則で既にリンクになるため、
	--    後読みで URL の途中（/ や英数字の直後）から始まるものを除外している
	table.insert(config.hyperlink_rules, {
		regex = [[(?<![\w/.-])(?:localhost|127\.0\.0\.1):\d{2,5}(?:/\S*)?]],
		format = "http://$0",
	})
	-- 開発サーバがよく表示する 0.0.0.0:ポートはブラウザで開けないため localhost に読み替える
	table.insert(config.hyperlink_rules, {
		regex = [[(?<![\w/.-])0\.0\.0\.0:(\d{2,5}(?:/\S*)?)]],
		format = "http://localhost:$1",
	})
	-- GitHub の owner/repo 短縮形（例: wezterm/wezterm）→ https://github.com/owner/repo
	-- 誤検出対策: 前後に / . ~ 等が続くもの（lua/general.lua、src/main.rs、~/dir/x、
	-- 2026/07/28 のようなパスや日付）は lookaround で除外し、repo 側は英字必須・ドット不可。
	-- 代償として vercel/next.js のようなドット入りリポジトリ名は対象外。and/or のような
	-- 語は残るが、リンクはホバー時のみ下線表示なので実害は小さい
	table.insert(config.hyperlink_rules, {
		regex = [[(?<![\w.~/@-])[A-Za-z0-9][A-Za-z0-9-]*/[\w-]*[A-Za-z][\w-]*(?![\w./-])]],
		format = "https://github.com/$0",
	})

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
