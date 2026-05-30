-- ============================================================
--  キーバインド一覧
-- ============================================================
--  ▼ カスタム（この設定で定義）
--    Ctrl+Shift+D        ペインを左右分割
--    Ctrl+Shift+E        ペインを上下分割
--    Ctrl+Shift+Alt+D    シェルを選んで左右分割（一覧から選択）
--    Ctrl+Shift+Alt+E    シェルを選んで上下分割（一覧から選択）
--    Ctrl+Shift+H/J/K/L  ペイン移動（左/下/上/右, vim風）
--    Ctrl+Shift+Q        ペインを閉じる（確認あり）
--    Ctrl+Shift+M        起動メニュー（Git Bash/PowerShell/MSYS2/WSL）
--    Ctrl+Shift+S        リサイズモード開始 → h/j/k/l または矢印で調整
--                        （Esc または Enter で終了 / 2秒で自動終了）
--    左クリック          選択をコピー（リンク上ならURLを開く）
--    右クリック          クリップボードから貼り付け
--
--  ▼ 主要デフォルト（WezTerm 標準。この設定でも有効）
--    Ctrl+Shift+C / V         コピー / 貼り付け
--    Ctrl+Shift+F             検索
--    Ctrl+Shift+X             コピーモード（vim風カーソル選択）
--    Ctrl+Shift+Space         QuickSelect（URL等を素早く選択）
--    Ctrl+Shift+P             コマンドパレット
--    Ctrl+Shift+U             文字（絵文字）選択
--    Ctrl+Shift+R             設定リロード
--    Ctrl+Shift+N             新しいウィンドウ
--    Ctrl+Shift+T             新しいタブ
--    Ctrl+Shift+W             タブを閉じる（確認あり）
--    Ctrl+Shift+1〜9          指定番号のタブへ切替
--    Ctrl+Tab / Ctrl+Shift+Tab        次 / 前のタブ
--    Ctrl+PageUp / PageDown           前 / 次のタブ
--    Ctrl+Shift+PageUp / PageDown     タブを左 / 右へ移動
--    Shift+PageUp / PageDown          1ページ スクロール
--    Ctrl + +/-/0             フォント拡大 / 縮小 / リセット
--    Alt+Enter                フルスクリーン切替
--  ※ 標準の Ctrl+Shift+K(ClearScrollback) / Ctrl+Shift+L(ShowDebugOverlay)
--    は上のペイン移動に再割当のため無効。
-- ============================================================

local wezterm = require("wezterm")
local shells = require("shells")
local M = {}

function M.apply(config)
	local act = wezterm.action

	-- シェルを選んで分割する。shells.list() の定義（args/domain/env）を
	-- そのまま SplitPane の command に渡して再利用する。
	local shell_list = shells.list()
	local shell_choices = {}
	for i, s in ipairs(shell_list) do
		shell_choices[i] = { id = tostring(i), label = s.label }
	end

	local function split_with_shell(direction)
		return act.InputSelector({
			title = "分割するシェルを選択",
			fuzzy = true,
			choices = shell_choices,
			action = wezterm.action_callback(function(window, pane, id)
				if not id then
					return -- Esc でキャンセル
				end
				window:perform_action(
					act.SplitPane({ direction = direction, command = shell_list[tonumber(id)] }),
					pane
				)
			end),
		})
	end

	config.mouse_bindings = {
		{
			-- 選択したテキストをコピー（リンク上ならURLを開く）
			event = { Up = { streak = 1, button = "Left" } },
			mods = "NONE",
			action = act.CompleteSelectionOrOpenLinkAtMouseCursor("ClipboardAndPrimarySelection"),
		},
		{
			-- 右クリックでペースト
			event = { Down = { streak = 1, button = "Right" } },
			mods = "NONE",
			action = act.PasteFrom("Clipboard"),
		},
	}

	config.keys = {
		-- ペイン分割（現在と同じシェル）
		{ key = "d", mods = "CTRL|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
		{ key = "e", mods = "CTRL|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },

		-- ペイン分割（シェルを一覧から選んで起動）
		{ key = "d", mods = "CTRL|SHIFT|ALT", action = split_with_shell("Right") },
		{ key = "e", mods = "CTRL|SHIFT|ALT", action = split_with_shell("Down") },

		-- ペイン移動 (vim-like)
		{ key = "h", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Left") },
		{ key = "j", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Down") },
		{ key = "k", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Up") },
		{ key = "l", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Right") },

		-- ペインを閉じる (Q = Quit)
		{ key = "q", mods = "CTRL|SHIFT", action = act.CloseCurrentPane({ confirm = true }) },

		-- 起動メニュー (M = Menu): Git Bash / PowerShell / MSYS2 / WSL …
		{ key = "m", mods = "CTRL|SHIFT", action = act.ShowLauncherArgs({ flags = "FUZZY|TABS|LAUNCH_MENU_ITEMS" }) },

		-- リサイズモード突入 (S = Size)
		{
			key = "s",
			mods = "CTRL|SHIFT",
			action = act.ActivateKeyTable({
				name = "resize_pane",
				one_shot = false,
				timeout_milliseconds = 2000,
				until_unknown = true,
			}),
		},
	}

	config.key_tables = {
		resize_pane = {
			{ key = "h",          action = act.AdjustPaneSize({ "Left", 2 }) },
			{ key = "j",          action = act.AdjustPaneSize({ "Down", 2 }) },
			{ key = "k",          action = act.AdjustPaneSize({ "Up", 2 }) },
			{ key = "l",          action = act.AdjustPaneSize({ "Right", 2 }) },
			{ key = "LeftArrow",  action = act.AdjustPaneSize({ "Left", 2 }) },
			{ key = "DownArrow",  action = act.AdjustPaneSize({ "Down", 2 }) },
			{ key = "UpArrow",    action = act.AdjustPaneSize({ "Up", 2 }) },
			{ key = "RightArrow", action = act.AdjustPaneSize({ "Right", 2 }) },
			{ key = "Escape",     action = "PopKeyTable" },
			{ key = "Enter",      action = "PopKeyTable" },
		},
	}
end

return M
