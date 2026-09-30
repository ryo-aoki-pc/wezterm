local wezterm = require("wezterm")
local M = {}

-- 長いコマンドの完了通知。
-- シェル統合 (shell/wezterm.sh / .ps1) が、一定時間（既定 10 秒、環境変数
-- WEZTERM_NOTIFY_AFTER で変更）以上かかったコマンドの終了時にユーザー変数を送る。
-- 値は WezTerm が base64 を復号済みの "終了コード<TAB>経過秒<TAB>コマンド"
local VAR = "wezterm_cmd_done"

-- 経過秒を「1分23秒」形式にする
local function duration(sec)
	if sec >= 3600 then
		return string.format("%d時間%d分", sec // 3600, sec % 3600 // 60)
	end
	if sec >= 60 then
		return string.format("%d分%d秒", sec // 60, sec % 60)
	end
	return string.format("%d秒", sec)
end

function M.apply(_config)
	wezterm.on("user-var-changed", function(window, pane, name, value)
		if name ~= VAR then
			return
		end

		-- 今まさに見ているペインなら通知しない（ウィンドウが前面 かつ そのペインがアクティブ）。
		-- ※ notification_handling = "SuppressFromFocusedPane" では代用できない。WezTerm は
		--   ウィンドウがフォーカスを失っても最後のペインを「フォーカス中」とみなし続けるため、
		--   ブラウザ等の別アプリを見ている間の通知まで消えてしまう
		local active = window:active_pane()
		if window:is_focused() and active and active:pane_id() == pane:pane_id() then
			return
		end

		local code, secs, cmd = value:match("^(%-?%d+)\t(%d+)\t(.*)$")
		if not code then
			return
		end
		local title = code == "0" and "✔ 完了" or ("✘ 失敗 (終了コード " .. code .. ")")
		cmd = (cmd:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " "))
		local body = string.format("%s (%s)", wezterm.truncate_right(cmd, 60), duration(tonumber(secs)))
		window:toast_notification(title, body)
	end)
end

return M
