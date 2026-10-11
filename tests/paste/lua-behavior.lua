-- 本番の貼り付け操作を WezTerm 内蔵 Lua と API stub で検査する。
-- 実行: wezterm --config-file tests/paste/lua-behavior.lua ls-fonts --text a
-- 設定エラーでも終了コードは 0 になり得るため、results/lua.json を確認する。
local real_wezterm = require("wezterm")
package.path = real_wezterm.config_dir .. "/../../lua/?.lua;" .. package.path

local stub = {
	target_triple = "x86_64-pc-windows-msvc",
	action_callback = function(callback) return callback end,
}
local events, timers, process_calls = {}, {}, {}
local clock_now = 1000
local clipboard_success, clipboard_stdout, clipboard_exception, clipboard_hook = true, "", false, nil
stub.on = function(name, callback)
	if not events[name] then events[name] = {} end
	table.insert(events[name], callback)
end
stub.time = {
	call_after = function(seconds, callback) table.insert(timers, { seconds = seconds, callback = callback }) end,
	now = function() return { format = function(_, pattern) assert(pattern == "%s%.f"); return tostring(clock_now) end } end,
}
stub.run_child_process = function(argv)
	table.insert(process_calls, argv)
	if clipboard_hook then clipboard_hook() end
	if clipboard_exception then error("取得失敗") end
	return clipboard_success, clipboard_stdout, "ログに出さないエラー"
end
setmetatable(stub, { __index = real_wezterm })
stub.action = setmetatable({}, {
	__index = function(_, name)
		return function(value) return { name = name, value = value } end
	end,
})
package.loaded.wezterm = stub
package.loaded.shells = { list = function() return {} end }
local actions = require("actions")
require("paste").apply({})
local records = {}
local function equal(actual, expected)
	assert(actual == expected, "期待値=" .. tostring(expected) .. " 実際=" .. tostring(actual))
end
local function test(name, callback)
	local ok, err = pcall(callback)
	table.insert(records, { name = name, passed = ok, error = not ok and tostring(err) or nil })
end

test("実 WezTerm API で Unix 秒と小数を数値に変換できる", function()
	local value = real_wezterm.time.now():format("%s%.f")
	assert(value:match("^%d+%.%d+$"))
	assert(tonumber(value) > 0)
end)

local function paste_case(name, options, expected)
	test(name, function()
		stub.target_triple = options.os or "x86_64-pc-windows-msvc"
		local p = {
			pane_id = function() return -1 end,
			get_domain_name = function() return options.domain or "local" end,
			is_alt_screen_active = function() return options.alt or false end,
			get_foreground_process_name = function()
				if options.unknown_fg then return nil end
				return options.fg or "C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
			end,
			get_user_vars = function()
				if options.missing_vars then return nil end
				return { WEZTERM_PSREADLINE_PASTE = options.marker }
			end,
		}
		local sent = {}
		local w = {
			active_key_table = function() return options.key_table end,
			perform_action = function(_, action, target)
				equal(target, p)
				table.insert(sent, action)
			end,
		}
		actions.paste_clipboard(w, p)
		equal(#sent, 1)
		equal(sent[1].name, expected)
		if expected == "SendKey" then
			equal(sent[1].value.key, "v")
			equal(sent[1].value.mods, "CTRL")
		else
			equal(sent[1].value, "Clipboard")
		end
	end)
end

paste_case("Windows PowerShell の入力待ち", { marker = "1" }, "SendKey")
paste_case("PowerShell 7 の入力待ち", { marker = "1", fg = "C:\\Program Files\\PowerShell\\7\\pwsh.exe" }, "SendKey")
paste_case("大文字の実行ファイル名", { marker = "1", fg = "C:/Windows/POWERSHELL.EXE" }, "SendKey")
paste_case("コマンド実行中", { marker = "" }, "PasteFrom")
paste_case("PSReadLine/統合なし", {}, "PasteFrom")
paste_case("ユーザー変数取得なし", { missing_vars = true }, "PasteFrom")
paste_case("未知のマーカー値", { marker = "true" }, "PasteFrom")
paste_case("未知の前面プロセス", { marker = "1", unknown_fg = true }, "PasteFrom")
for _, item in ipairs({
	{ "SSH", "ssh.exe" }, { "Neovim", "nvim.exe" }, { "cmd", "cmd.exe" },
	{ "Git Bash", "bash.exe" }, { "WSL", "wsl.exe" }, { "別アプリ", "python.exe" },
}) do
	paste_case(item[1] .. " に古いマーカーが残る", { marker = "1", fg = item[2] }, "PasteFrom")
end
for _, domain in ipairs({ "WSL:Ubuntu", "SSH:example", "serial:test" }) do
	paste_case("別ドメイン: " .. domain, { marker = "1", domain = domain }, "PasteFrom")
end
paste_case("alternate screen", { marker = "1", alt = true }, "PasteFrom")
for _, mode in ipairs({ "copy_mode", "search_mode", "resize_pane" }) do
	paste_case("キーテーブル: " .. mode, { marker = "1", key_table = mode }, "PasteFrom")
end
for _, os in ipairs({ "x86_64-unknown-linux-gnu", "aarch64-apple-darwin" }) do
	paste_case("別 OS: " .. os, { marker = "1", os = os }, "PasteFrom")
end

local real_getenv = os.getenv
local environment = { WAYLAND_DISPLAY = "wayland-test", DISPLAY = ":test", WINDIR = "C:/Windows" }
os.getenv = function(name) return environment[name] end
local next_id = 0
local epoch = string.rep("a", 32)
local nonce = string.rep("b", 32)
local other = string.rep("c", 32)
local function fixture(options)
	options = options or {}
	next_id = next_id + 1
	stub.target_triple = options.os or "x86_64-unknown-linux-gnu"
	clipboard_success, clipboard_stdout, clipboard_exception = true, options.text or "無害な貼り付け\n\n", false
	clipboard_hook = nil
	process_calls, timers = {}, {}
	clock_now = 1000
	environment.WAYLAND_DISPLAY, environment.DISPLAY = "wayland-test", ":test"
	local vars = { WEZTERM_PSREADLINE_SSH_PASTE = options.marker or "1:" .. epoch, WEZTERM_PROG = options.prog }
	local sent, frames, notifications = {}, {}, {}
	local id = next_id
	local pane = {
		pane_id = function() return id end,
		get_domain_name = function() return options.domain or "local" end,
		is_alt_screen_active = function() return options.alt or false end,
		get_foreground_process_name = function() return options.fg or "/usr/bin/ssh" end,
		get_user_vars = function() return vars end,
		send_text = function(_, text) table.insert(frames, text) end,
	}
	local selected = pane
	local window = {
		window_id = function() return id end,
		active_key_table = function() return options.key_table end,
		active_pane = function() return selected end,
		perform_action = function(_, action, target) equal(target, pane); table.insert(sent, action) end,
		toast_notification = function(_, title, body) table.insert(notifications, { title = title, body = body }) end,
	}
	local function emit(name, value)
		vars[name] = value
		for _, callback in ipairs(events["user-var-changed"]) do callback(window, pane, name, value) end
	end
	return {
		pane = pane, window = window, vars = vars, sent = sent, frames = frames, notifications = notifications,
		paste = function() actions.paste_clipboard(window, pane) end,
		emit = emit,
		ready = function(value) emit("WEZTERM_PSREADLINE_SSH_READY", value or "1:" .. epoch .. ":" .. nonce) end,
		result = function(value) emit("WEZTERM_PSREADLINE_SSH_RESULT", value or "1:" .. epoch .. ":ok") end,
		select = function(value) selected = value end,
		update = function() for _, callback in ipairs(events["update-status"]) do callback(window, pane) end end,
	}
end

test("SSH の複数行・CRLF・日本語・絵文字・タブは改行のない Base64 フレームを一度だけ送る", function()
	local f = fixture({ text = "a\r\n\n日本語😀\t\n" })
	f.paste()
	equal(#f.sent, 1)
	equal(f.sent[1].name, "SendKey")
	equal(f.sent[1].value.key, "F12")
	equal(f.sent[1].value.mods, "CTRL|SHIFT")
	equal(#f.frames, 0)
	f.ready()
	equal(f.frames[1], "WZP1:" .. nonce .. ":28:YQ0KCuaXpeacrOiqnvCfmIAJCg==~")
	assert(not f.frames[1]:find("[\r\n]"))
	f.ready()
	equal(#f.frames, 1)
	f.result()
	f.paste()
	equal(#f.sent, 2)
end)

test("Wayland はテキストを改行追加なしで取得する", function()
	local f = fixture()
	f.paste()
	equal(table.concat(process_calls[1], "|"), "wl-paste|--no-newline|--type|text")
end)

test("X11 は xclip の UTF8_STRING を引数配列で取得する", function()
	local f = fixture({ text = "abc" })
	environment.WAYLAND_DISPLAY = nil
	f.paste(); f.ready()
	equal(table.concat(process_calls[1], "|"), "xclip|-selection|clipboard|-out|-target|UTF8_STRING")
	equal(f.frames[1], "WZP1:" .. nonce .. ":4:YWJj~")
end)

test("Windows はシステム PowerShell を NoProfile/STA で起動し ASCII の取得結果を送る", function()
	local f = fixture({ os = "x86_64-pc-windows-msvc", text = "YWJj" })
	f.paste(); f.ready()
	equal(process_calls[1][1], "C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe")
	equal(process_calls[1][3], "-NoProfile")
	equal(process_calls[1][5], "-STA")
	assert(process_calls[1][7]:find("ContainsText", 1, true))
	assert(process_calls[1][7]:find("Get-Clipboard -Raw", 1, true))
	equal(f.frames[1], "WZP1:" .. nonce .. ":4:YWJj~")
end)

for _, text in ipairs({ "a", "ab", "abc" }) do
	test("Base64 末尾のパディング: " .. #text .. " バイト", function()
		local expected = ({ "YQ==", "YWI=", "YWJj" })[#text]
		local f = fixture({ text = text })
		f.paste(); f.ready()
		equal(f.frames[1], "WZP1:" .. nonce .. ":4:" .. expected .. "~")
	end)
end

test("空クリップボードではキーも本文も送らない", function()
	local f = fixture({ text = "" })
	f.paste(); f.ready()
	equal(#f.sent, 0); equal(#f.frames, 0); equal(#f.notifications, 0)
end)

test("64 KiB ちょうどの UTF-8 本文を送れる", function()
	local f = fixture({ text = string.rep("a", 64 * 1024) })
	f.paste(); f.ready()
	equal(#f.sent, 1); equal(#f.frames, 1)
	equal(#f.frames[1], #("WZP1:" .. nonce .. ":87384:~") + 87384)
	equal(f.frames[1]:sub(-5), "YQ==~")
end)

test("クリップボードの取得中に入力待機が終われば chord も送らない", function()
	local f = fixture()
	clipboard_hook = function() f.vars.WEZTERM_PSREADLINE_SSH_PASTE = "" end
	f.paste(); f.ready()
	equal(#f.sent, 0); equal(#f.frames, 0)
end)

for _, failure in ipairs({ "exit", "exception" }) do
	test("クリップボード取得失敗を chord の前に止める: " .. failure, function()
		local f = fixture()
		clipboard_success, clipboard_exception = failure ~= "exit", failure == "exception"
		f.paste(); f.ready()
		equal(#f.sent, 0); equal(#f.frames, 0); equal(#f.notifications, 1)
	end)
end

for _, data in ipairs({ "a\0b", "\255", string.rep("a", 64 * 1024 + 1) }) do
	test("不正テキスト・NUL・64 KiB 超過を chord の前に止める: " .. #data .. " バイト", function()
		local f = fixture({ text = data })
		f.paste(); f.ready()
		equal(#f.sent, 0); equal(#f.frames, 0); equal(#f.notifications, 1)
	end)
end

for _, data in ipairs({ "AA==", "YQ=", "YQ==\n", "YR==", "YWF=", "YW=J", "YQ==YQ==" }) do
	test("Windows の不正 Base64 または NUL を止める: " .. data, function()
		local f = fixture({ os = "x86_64-pc-windows-msvc", text = data })
		f.paste(); f.ready()
		equal(#f.sent, 0); equal(#f.frames, 0); equal(#f.notifications, 1)
	end)
end

test("同一ペインは一つだけ待機し、二度目は本文を追加しない", function()
	local f = fixture()
	f.paste(); f.paste(); f.ready()
	equal(#f.sent, 1); equal(#f.frames, 1); equal(#process_calls, 1); equal(#f.notifications, 1)
end)

test("3 秒で READY 待機を破棄し、遅れた READY は無視する", function()
	local f = fixture()
	f.paste()
	equal(timers[1].seconds, 3)
	timers[1].callback(); f.ready()
	equal(#f.frames, 0); equal(#f.notifications, 1)
end)

for _, elapsed in ipairs({ 3, 5.5, -0.001 }) do
	test("timer 未処理でも期限到達・時刻後戻りの READY を拒否する: " .. elapsed, function()
		local f = fixture()
		f.paste()
		clock_now = clock_now + elapsed
		f.ready()
		equal(#f.frames, 0); equal(#f.notifications, 1)
		assert(f.notifications[1].body:find("準備が時間切れ", 1, true))
		timers[1].callback(); f.ready()
		equal(#f.frames, 0); equal(#f.notifications, 1)
	end)
end

test("期限の直前に届く READY は一度だけ送る", function()
	local f = fixture()
	f.paste(); clock_now = clock_now + 2.999; f.ready(); f.ready()
	equal(#f.frames, 1); equal(#f.notifications, 0)
end)

test("送信後は READY タイマーで待機を解除せず RESULT を待つ", function()
	local f = fixture()
	f.paste(); f.ready(); timers[1].callback(); f.paste()
	equal(#f.sent, 1); equal(#f.frames, 1); equal(#f.notifications, 1)
	f.result(); f.paste()
	equal(#f.sent, 2)
end)

for _, value in ipairs({ "1:" .. other .. ":" .. nonce, "1:" .. epoch .. ":short", "2:" .. epoch .. ":" .. nonce, "1:" .. epoch .. ":" .. nonce .. ":extra" }) do
	test("不正・古い READY を無視する: " .. value, function()
		local f = fixture()
		f.paste(); f.ready(value)
		equal(#f.frames, 0)
	end)
end

test("貼り付け開始前の READY と既に使った nonce を再利用しない", function()
	local f = fixture()
	f.vars.WEZTERM_PSREADLINE_SSH_READY = "1:" .. epoch .. ":" .. nonce
	f.paste(); f.ready(); equal(#f.frames, 0)
	f.ready("1:" .. epoch .. ":" .. other); equal(#f.frames, 1)
	f.result(); f.paste(); f.ready("1:" .. epoch .. ":" .. other); equal(#f.frames, 1)
end)

for _, changed in ipairs({ "", "1:" .. other, "2:" .. epoch }) do
	test("epoch の解除・変更では本文を破棄する: " .. changed, function()
		local f = fixture()
		f.paste(); f.emit("WEZTERM_PSREADLINE_SSH_PASTE", changed); f.ready()
		equal(#f.frames, 0)
	end)
end

test("READY 到着時に現在 marker が変わっていても本文を送らない", function()
	local f = fixture()
	f.paste(); f.vars.WEZTERM_PSREADLINE_SSH_PASTE = ""; f.ready()
	equal(#f.frames, 0)
end)

test("別ペインの READY は他の待機を完了させない", function()
	local first = fixture({ text = "first" })
	first.paste()
	local second = fixture({ text = "second" })
	second.paste(); second.ready()
	equal(#first.frames, 0); equal(#second.frames, 1)
end)

test("ペイン切替後の READY では本文を送らない", function()
	local f = fixture()
	f.paste(); f.select({ pane_id = function() return -1 end }); f.ready()
	equal(#f.frames, 0)
end)

test("定期更新がペイン切替を検出した後は戻っても古い READY を無視する", function()
	local f = fixture()
	f.paste(); f.select({ pane_id = function() return -1 end }); f.update(); f.select(f.pane); f.ready()
	equal(#f.frames, 0)
end)

test("閉じたペインの待機を定期更新で破棄する", function()
	local f = fixture()
	f.paste()
	f.pane.is_alt_screen_active = function() error("閉じたペイン") end
	f.update()
	f.pane.is_alt_screen_active = function() return false end
	f.ready()
	equal(#f.frames, 0)
end)

test("RESULT error は本文を再送せず固定の通知を出す", function()
	local f = fixture()
	f.paste(); f.result("1:" .. epoch .. ":error:cancelled"); f.ready()
	equal(#f.frames, 0); equal(#f.notifications, 1)
	assert(not f.notifications[1].body:find("cancelled", 1, true))
end)

test("古い RESULT と送信前の ok は待機を解除しない", function()
	local f = fixture()
	f.paste(); f.result("1:" .. other .. ":error:cancelled"); f.result(); f.ready()
	equal(#f.frames, 1); equal(#f.notifications, 0)
end)

for _, marker in ipairs({ "true", "1:short", "2:" .. epoch }) do
	test("未知 remote marker は通常貼り付けへ戻らない: " .. marker, function()
		local f = fixture({ marker = marker })
		f.paste()
		equal(#f.sent, 0); equal(#f.frames, 0); equal(#f.notifications, 1); equal(#process_calls, 0)
	end)
end

test("SSH の統合準備失敗マーカーでは取得・chord・通常貼り付けを止めて復旧方法を知らせる", function()
	local f = fixture({ marker = "unavailable" })
	f.paste()
	equal(#f.sent, 0); equal(#f.frames, 0); equal(#f.notifications, 1); equal(#process_calls, 0)
	assert(f.notifications[1].body:find("PSReadLine と統合を読み直してください", 1, true))
end)

for _, options in ipairs({ { alt = true }, { key_table = "copy_mode" } }) do
	test("remote marker があっても alternate screen / keytable は従来貼り付け", function()
		local f = fixture(options)
		f.paste()
		equal(f.sent[1].name, "PasteFrom"); equal(#process_calls, 0)
	end)
end

test("Git Bash の foreground と remote の WEZTERM_PROG が変わっていても marker を使う", function()
	local f = fixture({ fg = "C:/Program Files/Git/bin/bash.exe", prog = "pwsh.exe" })
	f.paste(); f.ready()
	equal(f.sent[1].name, "SendKey"); equal(#f.frames, 1)
end)

test("Linux の display が無ければ本文も chord も送らない", function()
	local f = fixture()
	environment.WAYLAND_DISPLAY, environment.DISPLAY = nil, nil
	f.paste()
	equal(#f.sent, 0); equal(#process_calls, 0); equal(#f.notifications, 1)
end)

test("macOS の SSH 貼り付けは未対応として止める", function()
	local f = fixture({ os = "aarch64-apple-darwin" })
	f.paste()
	equal(#f.sent, 0); equal(#process_calls, 0); equal(#f.notifications, 1)
end)

os.getenv = real_getenv

test("右クリック2経路と Ctrl+Shift+V が共有操作を使う", function()
	local config = {}
	require("bindings").apply(config)
	local right, reported, keyboard = 0, 0, 0
	for _, binding in ipairs(config.mouse_bindings) do
		if binding.event.Down.button == "Right" then
			equal(binding.action, actions.paste_clipboard)
			if binding.mouse_reporting then reported = reported + 1 else right = right + 1 end
		end
	end
	for _, binding in ipairs(config.keys) do
		if binding.key == "v" and binding.mods == "CTRL|SHIFT" then
			equal(binding.action, actions.paste_clipboard)
			keyboard = keyboard + 1
		end
	end
	equal(right, 1)
	equal(reported, 1)
	equal(keyboard, 1)
end)

local passed = 0
for _, record in ipairs(records) do if record.passed then passed = passed + 1 end end
local result = { total = #records, passed = passed, failed = #records - passed, tests = records }
local f = assert(io.open(real_wezterm.config_dir .. "/results/lua.json", "w"))
f:write(real_wezterm.json_encode(result), "\n")
f:close()
package.loaded.wezterm = real_wezterm
real_wezterm.log_info(string.format("PASTE_LUA_TESTS %d/%d passed", passed, #records))
assert(result.failed == 0, "貼り付けのテスト失敗: results/lua.json を参照")
return real_wezterm.config_builder()
