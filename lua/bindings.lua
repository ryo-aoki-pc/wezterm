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
--    Ctrl+Shift+Alt+T    タブ名を変更（現在の名前を編集。空欄でデフォルトに戻す）
--    Ctrl+Shift+S        リサイズモード開始 → h/j/k/l または矢印で調整
--                        （Esc または Enter で終了 / 2秒で自動終了）
--    Ctrl+Shift+F        検索（大文字小文字を区別しない。標準は区別あり）
--    Ctrl+Shift+A        ペイン選択（ラベルを打って移動）
--    Ctrl+Shift+Alt+A    ペイン選択（選んだペインと現在ペインを入替え）
--    Ctrl+Shift+B        直前にアクティブだったタブへ戻る（タブバーの ↩ 印）
--    Ctrl+Shift+Alt+B    背景透過のトグル（0.9 ⇔ 1.0 一時切替）
--    Ctrl+Shift+Alt+W    ワークスペース一覧（fuzzy 選択で切替）
--    Ctrl+Shift+Alt+N    新しいワークスペースを作成して切替
--    Ctrl+Shift+Alt+R    ワークスペース名を変更（現在の名前を編集）
--    Ctrl+Shift+Alt+K    スクロールバック消去（標準 Ctrl+Shift+K の移設先）
--    Ctrl+Shift+Alt+L    デバッグオーバーレイ（標準 Ctrl+Shift+L の移設先）
--    左クリック          選択をコピー（リンク上ならURLを開く）
--    右クリック          クリップボードから貼り付け
--
--  ▼ 主要デフォルト（WezTerm 標準。この設定でも有効）
--    Ctrl+Shift+C / V         コピー / 貼り付け
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
--    はペイン移動に再割当。元の機能は Ctrl+Shift+Alt+K / L に移設済み。
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

		-- タブ名を変更 (T = Tab の Alt 付き変種): 現在の名前を初期値にして編集する。
		-- prompt / initial_value は nightly 限定のため、押した時点のタブ名を
		-- 初期値に入れられるようコールバック内でアクションを組み立てる
		{
			key = "t",
			mods = "CTRL|SHIFT|ALT",
			action = wezterm.action_callback(function(window, pane)
				window:perform_action(
					act.PromptInputLine({
						description = "タブ名を入力（空欄で確定するとデフォルト名に戻る）",
						prompt = (wezterm.nerdfonts.md_pencil or ">") .. " ",
						initial_value = window:active_tab():get_title(),
						action = wezterm.action_callback(function(win, _, line)
							-- Esc でキャンセルすると line は nil
							if line then
								win:active_tab():set_title(line)
							end
						end),
					}),
					pane
				)
			end),
		},

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

		-- 検索: 標準の「大文字小文字を区別」を「区別なし」に上書き
		-- （検索オーバーレイ内でのモード切替は引き続き可能）
		{ key = "f", mods = "CTRL|SHIFT", action = act.Search({ CaseInSensitiveString = "" }) },

		-- ペイン選択 (A = Activate): 各ペインにラベルが出て、打った文字のペインへ移動。
		-- Alt 付きは選んだペインと現在ペインの位置を入替える
		{ key = "a", mods = "CTRL|SHIFT", action = act.PaneSelect({ mode = "Activate" }) },
		{ key = "a", mods = "CTRL|SHIFT|ALT", action = act.PaneSelect({ mode = "SwapWithActive" }) },

		-- 直前にアクティブだったタブへ戻る (B = Back)。タブバーの ↩ 印が戻り先
		{ key = "b", mods = "CTRL|SHIFT", action = act.ActivateLastTab },

		-- 背景透過を一時トグル（1.0=不透明 ⇔ override 解除=window.lua の 0.9）
		-- 値を nil に戻すことで基準値を二重管理しない
		{
			key = "b",
			mods = "CTRL|SHIFT|ALT",
			action = wezterm.action_callback(function(window, _)
				local overrides = window:get_config_overrides() or {}
				if overrides.window_background_opacity == nil then
					overrides.window_background_opacity = 1.0
				else
					overrides.window_background_opacity = nil
				end
				window:set_config_overrides(overrides)
			end),
		},

		-- ワークスペース一覧から fuzzy 選択で切替 (W = Workspace)
		{ key = "w", mods = "CTRL|SHIFT|ALT", action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }) },

		-- 新しいワークスペースを名前を付けて作成・切替 (N = New)
		{
			key = "n",
			mods = "CTRL|SHIFT|ALT",
			action = act.PromptInputLine({
				description = "新しいワークスペース名を入力",
				prompt = (wezterm.nerdfonts.cod_window or ">") .. " ",
				action = wezterm.action_callback(function(win, pane, line)
					-- Esc でキャンセルすると line は nil。空欄も何もしない
					if line and #line > 0 then
						win:perform_action(act.SwitchToWorkspace({ name = line }), pane)
					end
				end),
			}),
		},

		-- ワークスペース名を変更 (R = Rename): 現在の名前を初期値にして編集。
		-- initial_value は nightly 限定のため、押した時点の名前を取り込めるよう
		-- コールバック内でアクションを組み立てる（タブ名変更と同じパターン）
		{
			key = "r",
			mods = "CTRL|SHIFT|ALT",
			action = wezterm.action_callback(function(window, pane)
				local current = window:active_workspace()
				window:perform_action(
					act.PromptInputLine({
						description = "ワークスペース名を入力",
						prompt = (wezterm.nerdfonts.md_pencil or ">") .. " ",
						initial_value = current,
						action = wezterm.action_callback(function(_, _, line)
							if line and #line > 0 and line ~= current then
								wezterm.mux.rename_workspace(current, line)
							end
						end),
					}),
					pane
				)
			end),
		},

		-- ペイン移動 (Ctrl+Shift+K/L) に潰された標準機能の移設先
		{ key = "k", mods = "CTRL|SHIFT|ALT", action = act.ClearScrollback("ScrollbackOnly") },
		{ key = "l", mods = "CTRL|SHIFT|ALT", action = act.ShowDebugOverlay },
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
