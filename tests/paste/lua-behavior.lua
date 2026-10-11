-- 本番の貼り付け操作を WezTerm 内蔵 Lua と API stub で検査する。
-- 実行: wezterm --config-file tests/paste/lua-behavior.lua ls-fonts --text a
-- 設定エラーでも終了コードは 0 になり得るため、results/lua.json を確認する。
local real_wezterm = require("wezterm")
package.path = real_wezterm.config_dir .. "/../../lua/?.lua;" .. package.path

local stub = {
	target_triple = "x86_64-pc-windows-msvc",
	action_callback = function(callback) return callback end,
}
setmetatable(stub, { __index = real_wezterm })
stub.action = setmetatable({}, {
	__index = function(_, name)
		return function(value) return { name = name, value = value } end
	end,
})
package.loaded.wezterm = stub
package.loaded.shells = { list = function() return {} end }
local actions = require("actions")
local records = {}
local function equal(actual, expected)
	assert(actual == expected, "期待値=" .. tostring(expected) .. " 実際=" .. tostring(actual))
end
local function test(name, callback)
	local ok, err = pcall(callback)
	table.insert(records, { name = name, passed = ok, error = not ok and tostring(err) or nil })
end

local function paste_case(name, options, expected)
	test(name, function()
		stub.target_triple = options.os or "x86_64-pc-windows-msvc"
		local p = {
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
