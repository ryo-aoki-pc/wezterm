local wezterm = require("wezterm")
local M = {}

function M.apply(config)
	-- ============================================================
	--  QuickSelect (Ctrl+Shift+Space) の追加パターン
	--  ※ 組み込みデフォルト（URL / スラッシュ区切りパス / git SHA / UUID /
	--    #rrggbb / IPv4 単体 / 0x アドレス / 4桁以上の数値）への「追加」。
	--    重複するものは定義しない。構文は fancy-regex
	-- ============================================================
	config.quick_select_patterns = {
		-- Windows パス（C:\… / C:/…）。デフォルトの path パターンは
		-- スラッシュ区切り専用でドライブレターを拾えないため追加。
		-- 空白を含むパスは空白の手前までしか選択されない点に注意
		[[\b[A-Za-z]:[\\/][^\s:*?"'<>|]+]],
		-- IPv4:ポート（IP 単体はデフォルトが拾うため「:ポート必須」の形のみ）
		[[\b(?:\d{1,3}\.){3}\d{1,3}:\d{1,5}\b]],
		-- localhost:ポート（下のハイパーリンク規則と対）
		[[\blocalhost:\d{1,5}\b]],
		-- semver（v1.2.3 / 1.2.3-rc.1 等）※日付 2026.7.28 なども拾うが実害なし
		[[\bv?\d+\.\d+\.\d+(?:-[\w.]+)?(?:\+[\w.]+)?\b]],
	}

	-- ============================================================
	--  ハイパーリンク規則（左クリックで開く）
	--  ※ hyperlink_rules への代入はデフォルト規則の「置換」になるため、
	--    まず default_hyperlink_rules() を取得してから追加する。
	--    デフォルトは scheme 付き URL と mailto のみ
	-- ============================================================
	config.hyperlink_rules = wezterm.default_hyperlink_rules()

	-- scheme 無しの localhost:PORT / 127.0.0.1:PORT を http リンク化
	-- （ローカル開発サーバーの起動メッセージをそのままクリックできる）
	table.insert(config.hyperlink_rules, {
		regex = [[\b(?:localhost|127\.0\.0\.1):\d{1,5}\b]],
		format = "http://$0",
	})

	-- 引用符付き "owner/repo" を GitHub リンク化
	-- （引用符必須にして lua/tabs.lua のような裸のパスへの誤爆を回避。
	--   パスを引用した場合は誤リンクになり得るが、クリックしない限り実害なし）
	table.insert(config.hyperlink_rules, {
		regex = [["(\w[\w.-]*/[\w.-]+)"]],
		format = "https://github.com/$1",
		highlight = 1,
	})
end

return M
