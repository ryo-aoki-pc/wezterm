-- ローカル PowerShell と SSH 先の PSReadLine への貼り付けをまとめる。
-- SSH では受信準備を確認してから ASCII のフレームを一度だけ送り、Enter は送らない。
local wezterm = require("wezterm")
local procs = require("procs")
local M = {}

local act = wezterm.action
local MARKER = "WEZTERM_PSREADLINE_SSH_PASTE"
local READY = "WEZTERM_PSREADLINE_SSH_READY"
local RESULT = "WEZTERM_PSREADLINE_SSH_RESULT"
local MAX_BYTES = 64 * 1024
local MAX_BASE64 = 4 * math.ceil(MAX_BYTES / 3)
local pending = {}
local nonces = {}
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local digits = {}
for i = 1, #alphabet do digits[alphabet:sub(i, i)] = i - 1 end
local ERROR_MESSAGES = {
	timeout = "SSH 先の貼り付け受信が時間切れになりました",
	cancelled = "SSH 先の貼り付けを取り消しました",
	oversize = "SSH 先で本文の大きさが上限を超えました",
	invalid = "SSH 先で貼り付けデータを受信できませんでした",
}

local function notify(window, message)
	window:toast_notification("PowerShell の貼り付け", message)
end

local function guid(value)
	return type(value) == "string" and #value == 32 and value:match("^[0-9a-f]+$") ~= nil
end

local function epoch_of(value)
	local epoch = type(value) == "string" and value:match("^1:([0-9a-f]+)$") or nil
	return guid(epoch) and epoch or nil
end

local function encode(text)
	local out = {}
	for i = 1, #text, 3 do
		local a, b, c = text:byte(i, i + 2)
		local value = a * 65536 + (b or 0) * 256 + (c or 0)
		out[#out + 1] = alphabet:sub(value // 262144 + 1, value // 262144 + 1)
		out[#out + 1] = alphabet:sub((value // 4096) % 64 + 1, (value // 4096) % 64 + 1)
		out[#out + 1] = b and alphabet:sub((value // 64) % 64 + 1, (value // 64) % 64 + 1) or "="
		out[#out + 1] = c and alphabet:sub(value % 64 + 1, value % 64 + 1) or "="
	end
	return table.concat(out)
end

-- Windows の取得結果も検証し、異常な stdout や NUL を受信側へ送らない。
local function decode(value)
	if #value > MAX_BASE64 or #value % 4 ~= 0 or value:find("[^A-Za-z0-9+/=]") then return nil end
	local out = {}
	for i = 1, #value, 4 do
		local a, b, c, d = value:sub(i, i), value:sub(i + 1, i + 1), value:sub(i + 2, i + 2), value:sub(i + 3, i + 3)
		if not digits[a] or not digits[b] then return nil end
		if c == "=" then
			if d ~= "=" or i + 3 ~= #value or digits[b] % 16 ~= 0 then return nil end
		elseif not digits[c] then
			return nil
		elseif d == "=" then
			if i + 3 ~= #value or digits[c] % 4 ~= 0 then return nil end
		elseif not digits[d] then
			return nil
		end
		local n = digits[a] * 262144 + digits[b] * 4096 + (digits[c] or 0) * 64 + (digits[d] or 0)
		out[#out + 1] = string.char(n // 65536)
		if c ~= "=" then out[#out + 1] = string.char((n // 256) % 256) end
		if d ~= "=" then out[#out + 1] = string.char(n % 256) end
	end
	return table.concat(out)
end

local WINDOWS_CLIPBOARD = [=[
$ErrorActionPreference = 'Stop'
try {
  Add-Type -AssemblyName System.Windows.Forms
  $data = [Windows.Forms.Clipboard]::GetDataObject()
  if ($null -eq $data) { exit 0 }
  if (-not [Windows.Forms.Clipboard]::ContainsText()) { exit 2 }
  $text = Get-Clipboard -Raw
  if ($null -eq $text) { exit 0 }
  [Console]::Out.Write([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($text)))
} catch { exit 1 }
]=]

local function clipboard()
	local windows = wezterm.target_triple:find("windows") ~= nil
	local argv
	if windows then
		local windir = os.getenv("WINDIR") or "C:/Windows"
		argv = { windir .. "/System32/WindowsPowerShell/v1.0/powershell.exe", "-NoLogo", "-NoProfile", "-NonInteractive", "-STA", "-Command", WINDOWS_CLIPBOARD }
	elseif wezterm.target_triple:find("linux") then
		if os.getenv("WAYLAND_DISPLAY") and os.getenv("WAYLAND_DISPLAY") ~= "" then
			argv = { "wl-paste", "--no-newline", "--type", "text" }
		elseif os.getenv("DISPLAY") and os.getenv("DISPLAY") ~= "" then
			argv = { "xclip", "-selection", "clipboard", "-out", "-target", "UTF8_STRING" }
		else
			return nil, "接続元のクリップボードを取得できません"
		end
	else
		return nil, "この OS からの SSH 貼り付けは未対応です"
	end
	local ok, success, stdout = pcall(wezterm.run_child_process, argv)
	if not ok or not success or type(stdout) ~= "string" then
		return nil, "テキストのクリップボードを取得できません"
	end
	if windows and #stdout > MAX_BASE64 then return nil, "貼り付けは UTF-8 で 64 KiB までです" end
	local text = stdout
	if windows then text = decode(stdout) end
	if not text then return nil, "クリップボードの取得結果が不正です" end
	if #text > MAX_BYTES then return nil, "貼り付けは UTF-8 で 64 KiB までです" end
	if text:find("\0", 1, true) or utf8.len(text) == nil then
		return nil, "貼り付けできない文字が含まれています"
	end
	return windows and stdout or encode(text)
end

local function active(window, pane)
	local current = window:active_pane()
	return current and current:pane_id() == pane:pane_id()
end

local function usable(window, pane, epoch)
	-- ペインを閉じた直後にも定期更新が来るため、消えたペインは失効として扱う。
	local ok, result = pcall(function()
		return not pane:is_alt_screen_active()
			and window:active_key_table() == nil
			and active(window, pane)
			and epoch_of((pane:get_user_vars() or {})[MARKER]) == epoch
	end)
	return ok and result
end

local function forget(id)
	if pending[id] then pending[id].payload = nil end
	pending[id] = nil
end

local function now()
	return tonumber(wezterm.time.now():format("%s%.f"))
end

local function timeout(window, id)
	forget(id)
	notify(window, "SSH 先の貼り付け準備が時間切れになりました")
end

local function remote(window, pane, epoch)
	local id = pane:pane_id()
	local previous = pending[id]
	if previous and previous.epoch == epoch then
		notify(window, "貼り付けの応答を待っています")
		return
	end
	forget(id)
	if not active(window, pane) then return end
	local payload, reason = clipboard()
	if not payload then notify(window, reason); return end
	if payload == "" then return end
	-- 取得中にペインや待機状態が変わった場合は、キーも本文も送らない。
	if not usable(window, pane, epoch) then return end
	local started = now()
	if not started then notify(window, "貼り付けの待機時刻を確認できません"); return end
	local state = { epoch = epoch, payload = payload, prior_ready = (pane:get_user_vars() or {})[READY], window = window, pane = pane,
		started_at = started, ready_deadline = started + 3 }
	pending[id] = state
	window:perform_action(act.SendKey({ key = "F12", mods = "CTRL|SHIFT" }), pane)
	wezterm.time.call_after(3, function()
		if pending[id] == state and not state.sent then
			timeout(window, id)
		end
	end)
end

function M.clipboard(window, pane)
	local fallback = act.PasteFrom("Clipboard")
	if pane:is_alt_screen_active() or window:active_key_table() ~= nil then
		forget(pane:pane_id())
		window:perform_action(fallback, pane)
		return
	end
	local vars = pane:get_user_vars() or {}
	local marker = vars[MARKER]
	if marker and marker ~= "" then
		local epoch = epoch_of(marker)
		if not epoch then
			forget(pane:pane_id())
			local message = marker == "unavailable"
				and "SSH 先の貼り付け統合を準備できません。PSReadLine と統合を読み直してください"
				or "SSH 先の貼り付け統合の版が未対応です"
			notify(window, message)
			return
		end
		remote(window, pane, epoch)
		return
	end
	forget(pane:pane_id())
	-- PR #39 のローカル Windows 経路は、引き続き PSReadLine の Paste を使う。
	if wezterm.target_triple:find("windows") and pane:get_domain_name() == "local" then
		local name = procs.basename(pane:get_foreground_process_name())
		if vars.WEZTERM_PSREADLINE_PASTE == "1" and (name == "powershell" or name == "pwsh") then
			fallback = act.SendKey({ key = "v", mods = "CTRL" })
		end
	end
	window:perform_action(fallback, pane)
end

function M.apply(_config)
	wezterm.on("user-var-changed", function(window, pane, name, value)
		local id = pane:pane_id()
		local state = pending[id]
		if name == MARKER then
			local epoch = epoch_of(value)
			if state and state.epoch ~= epoch then forget(id) end
			if nonces[id] and nonces[id].epoch ~= epoch then nonces[id] = nil end
			return
		end
		if not state then return end
		if not usable(window, pane, state.epoch) then forget(id); return end
		if name == READY and not state.sent and type(value) == "string" then
			-- UI が止まり、期限の timer より READY が先に処理されても本文を送らない。
			-- 実時刻を使うので、開始時刻より時計が戻った場合も失効させる。
			local current = now()
			if not current or current < state.started_at or current >= state.ready_deadline then
				timeout(window, id)
				return
			end
			local epoch, nonce = value:match("^1:([0-9a-f]+):([0-9a-f]+)$")
			if epoch ~= state.epoch or not guid(nonce) or value == state.prior_ready then return end
			local seen = nonces[id]
			if seen and seen.epoch == epoch and seen[nonce] then return end
			if not seen or seen.epoch ~= epoch then seen = { epoch = epoch }; nonces[id] = seen end
			seen[nonce] = true
			local frame = string.format("WZP1:%s:%d:%s~", nonce, #state.payload, state.payload)
			state.sent = true
			state.payload = nil
			local ok = pcall(function() pane:send_text(frame) end)
			if not ok then forget(id); notify(window, "SSH 先への貼り付け送信に失敗しました") end
		elseif name == RESULT and type(value) == "string" then
			local epoch, result = value:match("^1:([0-9a-f]+):(.+)$")
			if epoch ~= state.epoch or not guid(epoch) then return end
			if result == "ok" and state.sent then
				forget(id)
			elseif result:match("^error:[a-z_]+$") then
				forget(id)
				local reason = result:match("^error:([a-z_]+)$")
				notify(window, ERROR_MESSAGES[reason] or "SSH 先で貼り付けを受信できませんでした")
			end
		end
	end)
	wezterm.on("update-status", function(_window, _pane)
		for id, state in pairs(pending) do
			if not usable(state.window, state.pane, state.epoch) then forget(id) end
		end
	end)
end

return M
