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
--    Ctrl+Shift+O        ペイン選択（各ペインのラベルを打ってジャンプ）
--    Ctrl+Shift+Alt+O    ペイン選択（選んだペインと現在のペインの位置を入替）
--    Ctrl+Shift+Alt+W    ワークスペース切替（一覧から選択 / 新規作成）
--    Ctrl+Shift+Alt+B    背景の半透明 ⇔ 不透明を切替（読みにくいとき用）
--    Ctrl+Shift+Alt+←/→  タブを左 / 右へ移動
--    Alt+1〜9 / Alt+0    タブ番号で切替（Alt+0 は最後のタブ）
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
--  ※ 標準の Ctrl+Shift+Alt+←/→(AdjustPaneSize) は上のタブ移動に再割当のため無効
--    （ペインのリサイズは Ctrl+Shift+S のリサイズモードで代替）。
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

	-- ワークスペース切替 (W = Workspace): 既存一覧から選択、または新規作成。
	-- 新規作成エントリの番兵 ID は、実在のワークスペース名と衝突しないよう制御文字入りにする
	local NEW_WORKSPACE_ID = "\x00new"
	local switch_workspace = wezterm.action_callback(function(window, pane)
		local current = window:active_workspace()
		local choices = {}
		for _, name in ipairs(wezterm.mux.get_workspace_names()) do
			table.insert(choices, {
				id = name,
				label = (name == current) and (name .. "（現在）") or name,
			})
		end
		table.insert(choices, {
			id = NEW_WORKSPACE_ID,
			label = (wezterm.nerdfonts.md_plus or "+") .. " 新しいワークスペースを作成",
		})
		window:perform_action(
			act.InputSelector({
				title = "ワークスペースを切替",
				fuzzy = true,
				choices = choices,
				action = wezterm.action_callback(function(win, p, id)
					if not id then
						return -- Esc でキャンセル
					end
					if id == NEW_WORKSPACE_ID then
						win:perform_action(
							act.PromptInputLine({
								description = "新しいワークスペース名を入力",
								prompt = (wezterm.nerdfonts.md_pencil or ">") .. " ", -- ※nightly 限定
								action = wezterm.action_callback(function(w2, p2, line)
									-- Esc でキャンセルすると line は nil
									if line and #line > 0 then
										w2:perform_action(act.SwitchToWorkspace({ name = line }), p2)
									end
								end),
							}),
							p
						)
					else
						win:perform_action(act.SwitchToWorkspace({ name = id }), p)
					end
				end),
			}),
			pane
		)
	end)

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

		-- ペイン選択 (O = Overview): 各ペインにラベルを重ね、打ったペインへジャンプ。
		-- Alt 付きは選んだペインと現在のペインの位置を入れ替える
		{ key = "o", mods = "CTRL|SHIFT", action = act.PaneSelect({ alphabet = "asdfghjkl" }) },
		{ key = "o", mods = "CTRL|SHIFT|ALT", action = act.PaneSelect({ mode = "SwapWithActive" }) },

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

		-- タブを左右へ移動（標準の Ctrl+Shift+PageUp/Down と同じ動作を矢印でも）
		-- ※ 標準の Ctrl+Shift+Alt+矢印 (AdjustPaneSize) を上書きする。
		--    ペインのリサイズは Ctrl+Shift+S のリサイズモードで代替
		{ key = "LeftArrow", mods = "CTRL|SHIFT|ALT", action = act.MoveTabRelative(-1) },
		{ key = "RightArrow", mods = "CTRL|SHIFT|ALT", action = act.MoveTabRelative(1) },

		-- ワークスペース切替 (W = Workspace): 上のヘルパーで一覧選択 / 新規作成
		{ key = "w", mods = "CTRL|SHIFT|ALT", action = switch_workspace },

		-- 背景透過トグル (B = Background): 半透明で読みにくいときに一時的に不透明へ。
		-- override を消せば window.lua の基準値 (0.9) に戻るため、ここに 0.9 は書かない
		{
			key = "b",
			mods = "CTRL|SHIFT|ALT",
			action = wezterm.action_callback(function(window, _)
				local overrides = window:get_config_overrides() or {}
				if overrides.window_background_opacity == nil then
					overrides.window_background_opacity = 1.0 -- 不透明にして可読性を優先
				else
					overrides.window_background_opacity = nil -- 半透明 + Acrylic に戻す
				end
				window:set_config_overrides(overrides)
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
	}

	-- タブ番号で直接切替（Alt+1〜9。Alt+0 は最後のタブ）
	-- ※ Git Bash (readline) の Alt+数字 (digit-argument) はこの割当てで無効になる
	for i = 1, 9 do
		table.insert(config.keys, { key = tostring(i), mods = "ALT", action = act.ActivateTab(i - 1) })
	end
	table.insert(config.keys, { key = "0", mods = "ALT", action = act.ActivateTab(-1) })

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
