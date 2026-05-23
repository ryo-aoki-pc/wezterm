local wezterm = require("wezterm")
local M = {}

function M.apply(config)
	local act = wezterm.action

	config.mouse_bindings = {
		{
			-- 選択したテキストをコピー
			event = { Up = { streak = 1, button = "Left" } },
			mods = "NONE",
			action = act.CopyTo("ClipboardAndPrimarySelection"),
		},
		{
			-- 右クリックでペースト
			event = { Down = { streak = 1, button = "Right" } },
			mods = "NONE",
			action = act.PasteFrom("Clipboard"),
		},
	}

	config.keys = {
		-- ペイン分割
		{ key = "d", mods = "CTRL|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
		{ key = "e", mods = "CTRL|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },

		-- ペイン移動 (vim-like)
		{ key = "h", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Left") },
		{ key = "j", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Down") },
		{ key = "k", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Up") },
		{ key = "l", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Right") },

		-- ズーム ON/OFF
		{ key = "z", mods = "CTRL|SHIFT", action = act.TogglePaneZoomState },

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
