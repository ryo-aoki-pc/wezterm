-- SSH 越しの Starship シェルから届く OSC / ユーザー変数を扱う Lua の回帰確認。
-- 実際の SSH 通信・端末の OSC 解釈・描画は別の実ペイン検証で確かめる。
-- 実行: wezterm --config-file tests/starship/ssh-lua-behavior.lua ls-fonts --text a
local real_wezterm = require("wezterm")
package.path = real_wezterm.config_dir .. "/../../lua/?.lua;" .. package.path

local records, events = {}, {}
local stub = {
	nerdfonts = setmetatable({}, { __index = function(_, key) return "<" .. key .. ">" end }),
	hostname = function() return "LOCAL.TEST" end,
	truncate_right = function(text, width) return text:sub(1, width) end,
	font_with_fallback = function(fonts) return fonts end,
	format = function(elements)
		local parts = {}
		for _, element in ipairs(elements) do
			if element.Text then table.insert(parts, element.Text) end
		end
		return table.concat(parts)
	end,
	on = function(name, callback) events[name] = callback end,
	action_callback = function(callback) return callback end,
	strftime = function() return "" end,
	battery_info = function() return {} end,
	open_with = function() end,
	mux = { get_workspace_names = function() return { "default" } end },
}
setmetatable(stub, { __index = real_wezterm })
stub.action = setmetatable({}, { __index = function(_, name)
	return function(value) return { name = name, value = value } end
end })
package.loaded.wezterm = stub
package.loaded.shells = { list = function() return {} end }

local function equal(actual, expected)
	assert(actual == expected, "期待値=" .. tostring(expected) .. " 実際=" .. tostring(actual))
end
local function includes(actual, expected)
	assert(actual:find(expected, 1, true), "見つからない=" .. expected .. " 実際=" .. actual)
end
local function excludes(actual, unexpected)
	assert(not actual:find(unexpected, 1, true), "予期しない=" .. unexpected .. " 実際=" .. actual)
end
local function test(name, callback, category)
	local ok, err = pcall(callback)
	table.insert(records, { name = name, passed = ok, category = category or "required", error = ok and nil or tostring(err) })
end

local procs = require("procs")
for _, item in ipairs({
	{ "Git Bash の通常 ssh", "C:/Git/bin/bash.exe", "ssh test-host", "ssh" },
	{ "Git Bash で連結後に ssh", "C:/Git/bin/bash.exe", "cd /tmp && ssh test-host", "ssh" },
	{ "Git Bash で Windows OpenSSH の絶対パス", "bash.exe", "C:/Windows/System32/OpenSSH/ssh.exe test-host", "ssh" },
	{ "起動メニューの直接 ssh", "C:/Windows/System32/OpenSSH/ssh.exe", nil, "ssh" },
	{ "直接 ssh は遠隔 WEZTERM_PROG より優先", "ssh.exe", "printf remote", "ssh" },
	{ "Git Bash で ssh 値を保持", "bash.exe", "ssh test-host", "ssh" },
	{ "ローカルへ戻り ssh 値を消去", "bash.exe", "", "bash" },
	{ "遠隔公式統合が値を消した待機中", "bash.exe", "", "bash" },
	{ "遠隔公式統合が値を上書きしたコマンド中", "bash.exe", "vim remote-file", "vim" },
	{ "WSL の入口から ssh", "wsl.exe", "ssh test-host", "ssh" },
}) do
	test("procs: " .. item[1], function() equal(procs.running(item[2], item[3]), item[4]) end)
end
test("procs: Git Bash の ssh エイリアスは展開できない", function()
	equal(procs.running("bash.exe", "s"), "s")
end, "known_limit")

local actions = require("actions")
local function zone(kind, text, y)
	return { semantic_type = kind, text = text, start_y = y, end_y = y }
end
local function copy_case(name, zones, y, prog, fg, expected, reason, category)
	test("copy: " .. name, function()
		local window = {
			window_id = function() return 777123 end,
			active_key_table = function() return nil end,
			active_workspace = function() return "default" end,
			set_right_status = function(self, text) self.status = text end,
			copy_to_clipboard = function(self, text, destination) self.copied, self.destination = text, destination end,
		}
		local pane = {
			get_semantic_zones = function() return zones end,
			get_text_from_semantic_zone = function(_, z) return z.text end,
			get_cursor_position = function() return { y = y } end,
			get_user_vars = function() return { WEZTERM_PROG = prog } end,
			get_foreground_process_name = function() return fg or "bash.exe" end,
		}
		actions.copy_last_output(window, pane)
		equal(window.copied, expected)
		if expected then
			equal(window.destination, "Clipboard")
			includes(window.status, "行をコピー")
		else
			includes(window.status, reason)
		end
	end, category)
end
local function remote_zones()
	return {
		zone("Input", "ssh test-host", 0), zone("Output", "login banner", 1),
		zone("Prompt", "remote STAR> ", 2), zone("Input", "printf remote", 2),
		zone("Output", "REMOTE_RESULT\n", 3), zone("Prompt", "remote STAR> ", 4),
		zone("Input", "", 4),
	}
end
copy_case("遠隔 Starship の区切り + ローカル ssh 値保持", remote_zones(), 4, "ssh test-host", "bash.exe", "REMOTE_RESULT")
copy_case("遠隔 Starship の区切り + 起動メニューから直接 ssh", remote_zones(), 4, nil, "ssh.exe", "REMOTE_RESULT")
copy_case("遠隔公式統合が WEZTERM_PROG を消しても区切りを使用", remote_zones(), 4, "", "bash.exe", "REMOTE_RESULT")
copy_case("遠隔入力中の文字は前の結果に混ぜない", {
	zone("Input", "printf first", 0), zone("Output", "FIRST\n", 1),
	zone("Prompt", "STAR> ", 2), zone("Input", "printf not-run", 2),
}, 2, "ssh test-host", "bash.exe", "FIRST")
copy_case("遠隔複数コマンドでは最後の出力のみ", {
	zone("Input", "echo previous", 0), zone("Output", "OLD\n", 1), zone("Prompt", "STAR> ", 2),
	zone("Input", "echo next", 2), zone("Output", "NEXT\n", 3), zone("Prompt", "STAR> ", 4),
}, 4, "ssh test-host", "bash.exe", "NEXT")
copy_case("遠隔の空出力コマンド", {
	zone("Input", "cd /tmp", 0), zone("Prompt", "STAR> ", 1), zone("Input", "", 1),
}, 1, "ssh test-host", "bash.exe", nil, "直前の出力は空です")
copy_case("TERM_PROGRAM が届かず遠隔統合なし", {
	zone("Input", "ssh test-host", 0), zone("Output", "session content", 1),
}, 3, "ssh test-host", "bash.exe", nil, "ssh 先の出力は区切れません")
copy_case("直接起動の ssh に遠隔統合なし", { zone("Output", "session content", 0) },
	1, nil, "ssh.exe", nil, "ssh 先の出力は区切れません")
copy_case("遠隔統合なしでも実プロセス ssh で判定", {
	zone("Input", "s", 0), zone("Output", "session content", 1),
}, 3, nil, "ssh.exe", nil, "ssh 先の出力は区切れません")
copy_case("ssh 終了後はローカル入力以降の出力を使用", {
	zone("Input", "exit", 0), zone("Output", "connection closed", 1), zone("Prompt", "LOCAL> ", 2),
	zone("Input", "echo local", 2), zone("Output", "LOCAL_RESULT\n", 3), zone("Prompt", "LOCAL> ", 4),
}, 4, "", "bash.exe", "LOCAL_RESULT")
copy_case("統合あり遠隔コマンド実行中は完了まで拒否", {
	zone("Input", "sleep 20; echo done", 0), zone("Output", "partial output", 1),
}, 2, "ssh test-host", "bash.exe", nil, "ssh 先の出力は区切れません")
copy_case("Git Bash のエイリアス ssh と遠隔統合なしは判別不能", {
	zone("Input", "s", 0), zone("Output", "whole remote session", 1),
}, 2, "s", "bash.exe", "whole remote session", nil, "known_limit")

require("tabs").apply({})
local function tab_text(overrides, title)
	local pane = {
		foreground_process_name = "bash.exe", user_vars = { WEZTERM_PROG = "ssh test-host" },
		title = "user@remote:wrong", current_working_dir = { file_path = "/srv/project", host = "REMOTE.EXAMPLE" },
	}
	for k, v in pairs(overrides or {}) do pane[k] = v end
	return stub.format(events["format-tab-title"]({
		active_pane = pane, tab_index = 0, is_active = true, tab_title = title,
	}))
end
test("tabs: 遠隔 OSC 7 のホストとディレクトリを優先", function()
	local text = tab_text()
	includes(text, "remote:project")
	includes(text, "<cod_remote>")
	excludes(text, "user@")
	excludes(text, "wrong")
end)
test("tabs: 遠隔 cwd が空白・日本語を含む", function()
	includes(tab_text({ current_working_dir = { file_path = "/srv/日本語 dir", host = "REMOTE.EXAMPLE" } }), "remote:日本語 dir")
end)
test("tabs: 遠隔ルートを表示", function()
	includes(tab_text({ current_working_dir = { file_path = "/", host = "REMOTE.EXAMPLE" } }), "remote:/")
end)
test("tabs: 遠隔ホームはローカルの ~ と同一視しない", function()
	includes(tab_text({ current_working_dir = { file_path = "/home/remote-user", host = "REMOTE.EXAMPLE" } }), "remote:remote-user")
end)
test("tabs: 遠隔公式統合が実行変数を消してもホスト表示を維持", function()
	local text = tab_text({ user_vars = { WEZTERM_PROG = "" } })
	includes(text, "remote:project")
	includes(text, "<cod_terminal_bash>")
end)
test("tabs: 遠隔公式統合が vim を送ったときのアイコン", function()
	local text = tab_text({ user_vars = { WEZTERM_PROG = "vim remote-file" } })
	includes(text, "remote:project")
	includes(text, "<custom_vim>")
end)
test("tabs: 直接起動 ssh は遠隔値を消しても ssh アイコン", function()
	includes(tab_text({ foreground_process_name = "ssh.exe", user_vars = { WEZTERM_PROG = "" } }), "<cod_remote>")
end)
test("tabs: 遠隔統合なしでは接続前 cwd よりタイトル優先", function()
	local text = tab_text({ current_working_dir = { file_path = "C:/local-project", host = "LOCAL.TEST" } })
	includes(text, "remote:wrong")
	excludes(text, "local-project")
	excludes(text, "user@")
end)
test("tabs: ssh 終了後にローカル cwd と bash を復帰", function()
	local text = tab_text({ user_vars = { WEZTERM_PROG = "" }, current_working_dir = { file_path = "C:/local-project", host = "LOCAL.TEST" } })
	includes(text, "local-project")
	includes(text, "<cod_terminal_bash>")
	excludes(text, "remote:")
end)
test("tabs: 手動タイトルは遠隔 cwd より優先", function()
	local text = tab_text({}, "SSHテスト")
	includes(text, "SSHテスト")
	excludes(text, "remote:project")
end)
test("tabs: 同じ短縮ホスト名はローカルとして扱う", function()
	local text = tab_text({ current_working_dir = { file_path = "/srv/project", host = "LOCAL.OTHER" } })
	includes(text, "remote:wrong")
	excludes(text, "local:project")
end, "known_limit")

require("notify").apply({})
local function notify_case(name, focused, active, source, value, title, body)
	test("notify: " .. name, function()
		local window = {
			is_focused = function() return focused end,
			active_pane = function() return { pane_id = function() return active end } end,
			toast_notification = function(self, t, b) self.title, self.body = t, b end,
		}
		events["user-var-changed"](window, { pane_id = function() return source end }, "wezterm_cmd_done", value)
		equal(window.title, title)
		equal(window.body, body)
	end)
end
notify_case("遠隔完了データを非アクティブペインで表示", true, 1, 2, "0\t12\tsleep 12", "✔ 完了", "sleep 12 (12秒)")
notify_case("遠隔失敗データを表示", false, 2, 2, "1\t12\tsleep 12; false", "✘ 失敗 (終了コード 1)", "sleep 12; false (12秒)")
notify_case("前面で見ている遠隔ペインは抑制", true, 2, 2, "0\t12\tsleep 12")
notify_case("別アプリを見ている遠隔ペインは通知", false, 2, 2, "0\t61\tsleep 61", "✔ 完了", "sleep 61 (1分1秒)")
notify_case("不正な遠隔データは無視", false, 2, 2, "broken")

local passed, required, limits = 0, 0, 0
for _, record in ipairs(records) do
	if record.passed then passed = passed + 1 end
	if record.category == "known_limit" then limits = limits + 1 else required = required + 1 end
end
local output = { total = #records, passed = passed, failed = #records - passed, required = required, known_limits = limits, tests = records }
local path = real_wezterm.config_dir .. "/ssh-results/lua-results.json"
local file = assert(io.open(path, "w"))
file:write(real_wezterm.json_encode(output), "\n")
file:close()
assert(passed == #records, "SSH Lua 回帰確認に失敗: " .. tostring(#records - passed))
return {}
