-- Starship 併用時にシェルから届く情報を、実際の Lua モジュールへ渡して確かめる。
-- WezTerm 内蔵の Lua で実行する。端末の OSC 解釈・GUI の描画自体は検証しない。
-- 実行: wezterm --config-file tests/starship/lua-behavior.lua ls-fonts --text a
-- 終了コードだけでは設定エラーを判定できないため、lua-results.json も確認する。
local real_wezterm = require("wezterm")
package.path = real_wezterm.config_dir .. "/../../lua/?.lua;" .. package.path

local records = {}
local events = {}
local stub = {
	nerdfonts = setmetatable({}, { __index = function(_, key) return "<" .. key .. ">" end }),
	hostname = function() return "LOCAL.TEST" end,
	truncate_right = function(text, width) return text:sub(1, width) end,
	font_with_fallback = function(fonts) return fonts end,
	format = function(elements)
		local text = {}
		for _, element in ipairs(elements) do
			if element.Text then table.insert(text, element.Text) end
		end
		return table.concat(text)
	end,
	on = function(name, callback) events[name] = callback end,
	action_callback = function(callback) return callback end,
	strftime = function(format)
		return ({ ["%w"] = "2", ["%m/%d"] = "10/06", ["%H:%M"] = "12:34" })[format]
	end,
	battery_info = function() return {} end,
	open_with = function() end,
	mux = { get_workspace_names = function() return { "default", "test" } end },
}
setmetatable(stub, { __index = real_wezterm })
stub.action = setmetatable({}, { __index = function(_, name)
	return function(value) return { name = name, value = value } end
end })
package.loaded.wezterm = stub
package.loaded.shells = { list = function() return { { label = "Test Bash", args = { "bash" } } } end }

local function equal(actual, expected)
	assert(actual == expected, "期待値=" .. tostring(expected) .. " 実際=" .. tostring(actual))
end
local function includes(actual, expected)
	assert(actual:find(expected, 1, true), "見つからない文字列=" .. expected .. " 実際=" .. actual)
end
local function excludes(actual, expected)
	assert(not actual:find(expected, 1, true), "予期しない文字列=" .. expected .. " 実際=" .. actual)
end
local function test(name, callback)
	local ok, err = pcall(callback)
	table.insert(records, { name = name, passed = ok, error = ok and nil or tostring(err) })
end

local procs = require("procs")
for _, item in ipairs({
	{ "Windows のパス", "C:\\Program Files\\PowerShell\\7\\pwsh.exe", nil, "pwsh" },
	{ "待機中の Git Bash", "C:/Git/bin/bash.exe", "", "bash" },
	{ "Git Bash の vim", "C:/Git/bin/bash.exe", "vim example.txt", "vim" },
	{ "Git Bash の ssh", "C:/Git/bin/bash.exe", "ssh host", "ssh" },
	{ "環境変数と sudo", "bash.exe", "TERM=xterm-256color sudo -E ssh -p 22 host", "ssh" },
	{ "cd の後に ssh", "bash.exe", "cd repo && ssh host", "ssh" },
	{ "clear の後に ssh", "bash.exe", "clear; ssh host", "ssh" },
	{ "mosh", "bash.exe", "mosh host", "mosh" },
	{ "不明な前景を補完", nil, "python script.py", "python" },
	{ "WSL 入口を補完", "wsl.exe", "nvim file", "nvim" },
	{ "実プロセスを優先", "C:/bin/ssh.exe", "vim file", "ssh" },
	{ "実プロセス node を優先", "/usr/bin/node", "ssh host", "node" },
}) do
	test("procs: " .. item[1], function() equal(procs.running(item[2], item[3]), item[4]) end)
end

local statusbar = require("statusbar")
local actions = require("actions")
local function window(overrides)
	local w = {
		window_id = function() return 987654 end,
		active_key_table = function() return nil end,
		active_workspace = function() return "default" end,
		set_right_status = function(self, text) self.status = text end,
		copy_to_clipboard = function(self, text, destination) self.copied, self.destination = text, destination end,
	}
	for name, value in pairs(overrides or {}) do w[name] = value end
	return w
end
local function zone(kind, text, y)
	return { semantic_type = kind, text = text, start_y = y, end_y = y }
end
local function pane(zones, y, prog, fg)
	return {
		get_semantic_zones = function() return zones end,
		get_text_from_semantic_zone = function(_, z) return z.text end,
		get_cursor_position = function() return { y = y } end,
		get_user_vars = function() return { WEZTERM_PROG = prog } end,
		get_foreground_process_name = function() return fg or "bash.exe" end,
	}
end
local function copy_case(name, zones, y, expected, reason, prog, fg)
	test("copy: " .. name, function()
		local w = window()
		actions.copy_last_output(w, pane(zones, y, prog, fg))
		equal(w.copied, expected)
		if expected then
			equal(w.destination, "Clipboard")
			includes(w.status, "出力")
			includes(w.status, "行をコピー")
		else
			includes(w.status, reason)
		end
	end)
end
copy_case("通常の完了コマンド", {
	zone("Prompt", "$ ", 0), zone("Input", "printf hello", 0), zone("Output", "hello\n", 1),
	zone("Prompt", "$ ", 2), zone("Input", "", 2),
}, 2, "hello")
copy_case("複数の出力範囲を連結", {
	zone("Input", "printf test", 0), zone("Output", "line1", 1), zone("Output", "line2\n\n", 2),
	zone("Prompt", "$ ", 3),
}, 3, "line1\nline2")
copy_case("入力途中の次コマンドを無視", {
	zone("Input", "echo old", 0), zone("Output", "old\n", 1), zone("Prompt", "$ ", 2),
	zone("Input", "echo not-yet", 2),
}, 2, "old")
copy_case("起動直後", { zone("Prompt", "$ ", 0), zone("Input", "", 0) }, 0,
	nil, "コピーできる出力がありません")
copy_case("clear 後の空白だけの出力", {
	zone("Output", "\n\n ", 0), zone("Prompt", "$ ", 2), zone("Input", "", 2),
}, 2, nil, "コピーできる出力がありません")
copy_case("出力なしコマンド", { zone("Input", "cd repo", 0), zone("Prompt", "$ ", 1) }, 1,
	nil, "直前の出力は空です")
copy_case("実行中で出力なし", { zone("Input", "sleep 20", 0) }, 1,
	nil, "直前の出力は空です")
copy_case("実行中の通常コマンド", { zone("Input", "long-command", 0), zone("Output", "progress\n", 1) },
	2, "progress")
copy_case("Starship が A/B を消して Output だけ", { zone("Output", "prompt command output prompt", 0) },
	3, nil, "コピーできません（要シェル統合）")
copy_case("区切りが一切ない", {}, 0, nil, "コピーできません（要シェル統合）")
copy_case("最初だけ古い Input が残り新しい A/B がない", {
	zone("Input", "old-command", 0), zone("Output", "old-result\nnew-prompt new-command\nnew-result", 1),
}, 3, "old-result\nnew-prompt new-command\nnew-result")
copy_case("ssh 先統合なし: 入力コマンドで判定", {
	zone("Input", "cd repo && ssh host", 0), zone("Output", "remote entire session", 1),
}, 2, nil, "ssh 先の出力は区切れません")
copy_case("ssh 先統合なし: ユーザー変数で判定", {
	zone("Input", "s", 0), zone("Output", "remote entire session", 1),
}, 2, nil, "ssh 先の出力は区切れません", "ssh host")
copy_case("直接 ssh 起動で Input がない", { zone("Output", "remote", 0) },
	1, nil, "ssh 先の出力は区切れません", nil, "ssh.exe")
copy_case("ssh 終了後はローカルの出力コピー", {
	zone("Input", "ssh host", 0), zone("Output", "closed session", 1), zone("Prompt", "$ ", 2),
}, 2, "closed session")
copy_case("ssh 先の統合あり", {
	zone("Input", "ssh host", 0), zone("Output", "welcome", 1), zone("Prompt", "remote $ ", 2),
	zone("Input", "echo remote", 2), zone("Output", "remote result", 3), zone("Prompt", "remote $ ", 4),
}, 4, "remote result", nil, "ssh host")

require("tabs").apply({})
local function tab_text(pane_info, title, active)
	return stub.format(events["format-tab-title"]({
		active_pane = pane_info, tab_index = 0, tab_title = title, is_active = active ~= false,
	}))
end
local function tab_pane(overrides)
	local p = {
		foreground_process_name = "bash.exe", user_vars = { WEZTERM_PROG = "" }, title = "fallback",
		current_working_dir = { file_path = "C:/dev/example", host = "local.test" },
	}
	for name, value in pairs(overrides or {}) do p[name] = value end
	return p
end
test("tabs: OSC 7 のローカル cwd", function()
	local text = tab_text(tab_pane())
	includes(text, "example")
	includes(text, "<cod_terminal_bash>")
end)
test("tabs: Starship の A/B 消失と無関係に vim のアイコン", function()
	local text = tab_text(tab_pane({ user_vars = { WEZTERM_PROG = "vim file" } }))
	includes(text, "example")
	includes(text, "<custom_vim>")
end)
test("tabs: プログラム終了後のクリアで bash のアイコン", function()
	includes(tab_text(tab_pane({ user_vars = { WEZTERM_PROG = "" } })), "<cod_terminal_bash>")
end)
test("tabs: ssh 実行中はローカル cwd を使わずリモートタイトル", function()
	local text = tab_text(tab_pane({ user_vars = { WEZTERM_PROG = "cd repo && ssh host" }, title = "user@host:repo" }))
	includes(text, "host:repo")
	excludes(text, "user@")
	excludes(text, "example")
	includes(text, "<cod_remote>")
end)
test("tabs: ssh 先 OSC 7 はホスト名つき cwd", function()
	local text = tab_text(tab_pane({ current_working_dir = { file_path = "/srv/remote", host = "OTHER.EXAMPLE" } }))
	includes(text, "other:remote")
end)
test("tabs: 明示的なタブ名が優先", function()
	includes(tab_text(tab_pane(), "手動名"), "手動名")
	excludes(tab_text(tab_pane(), "手動名"), "example")
end)
test("tabs: cwd がない場合はタイトル", function()
	local p = tab_pane()
	p.current_working_dir = nil
	includes(tab_text(p), "fallback")
end)
test("tabs: OSC 9;4 の進捗表示", function()
	includes(tab_text(tab_pane({ progress = { Percentage = 50 } })), "50%")
end)
test("tabs: 非アクティブの未読出力表示", function()
	includes(tab_text(tab_pane({ has_unseen_output = true }), nil, false), "<md_circle_medium>")
end)
test("tabs: ズーム表示", function()
	includes(tab_text(tab_pane({ is_zoomed = true })), "<md_magnify>")
end)

require("notify").apply({})
local function notify_case(name, focused, active_id, source_id, value, expected_title, expected_body, varname)
	test("notify: " .. name, function()
		local w = window({
			is_focused = function() return focused end,
			active_pane = function() return active_id and { pane_id = function() return active_id end } end,
			toast_notification = function(self, title, body) self.toast_title, self.toast_body = title, body end,
		})
		events["user-var-changed"](w, { pane_id = function() return source_id end }, varname or "wezterm_cmd_done", value)
		equal(w.toast_title, expected_title)
		equal(w.toast_body, expected_body)
	end)
end
notify_case("前面のアクティブペインは抑制", true, 1, 1, "0\t12\tsleep 12")
notify_case("前面の非アクティブペイン", true, 1, 2, "0\t12\tsleep 12", "✔ 完了", "sleep 12 (12秒)")
notify_case("別アプリを見ているとき", false, 1, 1, "0\t12\tsleep 12", "✔ 完了", "sleep 12 (12秒)")
notify_case("失敗の終了コード", false, 1, 1, "3\t72\t  long\n command  ", "✘ 失敗 (終了コード 3)", "long command (1分12秒)")
notify_case("コマンド名なし", false, 1, 1, "0\t3661\t", "✔ 完了", "1時間1分")
notify_case("不正値は無視", false, 1, 1, "not-a-notification")
notify_case("WEZTERM_PROG は通知を出さない", false, 1, 1, "ssh host", nil, nil, "WEZTERM_PROG")

test("statusbar: 一時メッセージ", function()
	local w = window()
	statusbar.flash(w, "テスト表示", "warn")
	includes(w.status, "テスト表示")
	excludes(w.status, "12:34")
end)
test("statusbar: モード表示と workspace", function()
	statusbar.apply({})
	local w = window({
		window_id = function() return 987655 end,
		active_key_table = function() return "copy_mode" end,
		active_workspace = function() return "work" end,
	})
	events["update-status"](w)
	includes(w.status, "コピー")
	includes(w.status, "work")
	excludes(w.status, "12:34")
end)
test("statusbar: 時計・日付", function()
	local w = window({ window_id = function() return 987656 end })
	events["update-status"](w)
	includes(w.status, "10/06 (火)")
	includes(w.status, "12:34")
end)
test("bindings: プロンプトジャンプと出力コピー", function()
	local config = {}
	require("bindings").apply(config)
	local keys = {}
	for _, binding in ipairs(config.keys) do keys[binding.key .. ":" .. binding.mods] = binding.action end
	equal(keys["UpArrow:CTRL|SHIFT|ALT"].name, "ScrollToPrompt")
	equal(keys["UpArrow:CTRL|SHIFT|ALT"].value, -1)
	equal(keys["DownArrow:CTRL|SHIFT|ALT"].name, "ScrollToPrompt")
	equal(keys["DownArrow:CTRL|SHIFT|ALT"].value, 1)
	equal(keys["c:CTRL|SHIFT|ALT"], actions.copy_last_output)
end)

local passed = 0
for _, record in ipairs(records) do if record.passed then passed = passed + 1 end end
local report = {
	mode = "実モジュール + WezTerm API stub (GUI/OSC 解釈は含まない)",
	total = #records, passed = passed, failed = #records - passed, tests = records,
}
local output = assert(io.open(real_wezterm.config_dir .. "/lua-results.json", "w"))
output:write(real_wezterm.json_encode(report), "\n")
output:close()
package.loaded.wezterm = real_wezterm
real_wezterm.log_info(string.format("STARSHIP_LUA_TESTS %d/%d passed", passed, #records))
assert(passed == #records, "失敗したテストは tests/starship/lua-results.json を参照")
return real_wezterm.config_builder()
