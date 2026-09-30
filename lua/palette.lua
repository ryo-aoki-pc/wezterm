local wezterm = require("wezterm")
local actions = require("actions")
local M = {}

-- コマンドパレット (Ctrl+Shift+P) に独自の操作を足す。
-- キーを割り当てた操作も並べ、キーを覚えていなくても名前で探せるようにする。
--   brief: 「日本語 (English)」。IME をオフのまま英語でも絞り込める
--   doc  : 割り当てたキー（キーの無い操作は省略）
--   icon : Nerd Font のグリフ名（wezterm.nerdfonts のキー名）
local ENTRIES = {
	{
		brief = "直前のコマンドの出力をコピー (Copy last output)",
		doc = "Ctrl+Shift+Alt+C",
		icon = "md_content_copy",
		action = actions.copy_last_output,
	},
	{
		brief = "スクロールバックをエディタで開く (Open scrollback in editor)",
		doc = "Ctrl+Shift+Alt+O",
		icon = "md_file_document_edit_outline",
		action = actions.open_scrollback,
	},
	{
		brief = "URL を選んで開く (Open URL)",
		doc = "Ctrl+Shift+O",
		icon = "md_open_in_new",
		action = actions.open_url,
	},
	{
		brief = "タブ名を変更 (Rename tab)",
		doc = "Ctrl+Shift+Alt+T",
		icon = "md_rename_box",
		action = actions.rename_tab,
	},
	{
		brief = "ペインを新しいタブへ移動 (Move pane to new tab)",
		icon = "md_tab_plus",
		action = actions.move_pane_to_new_tab,
	},
	{
		brief = "ペインを新しいウィンドウへ移動 (Move pane to new window)",
		icon = "md_open_in_app",
		action = actions.move_pane_to_new_window,
	},
	{
		brief = "ワークスペースを作成 / 移動 (New workspace)",
		doc = "Ctrl+Shift+Alt+N",
		icon = "cod_window",
		action = actions.new_workspace,
	},
	{
		brief = "ワークスペース名を変更 (Rename workspace)",
		icon = "md_rename_box",
		action = actions.rename_workspace,
	},
	{
		brief = "設定フォルダを開く (Open config folder)",
		icon = "md_folder_cog_outline",
		action = actions.open_config_dir,
	},
}

function M.apply(_config)
	wezterm.on("augment-command-palette", function(_window, _pane)
		return ENTRIES
	end)
end

return M
