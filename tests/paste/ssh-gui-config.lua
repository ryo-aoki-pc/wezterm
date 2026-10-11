-- 実 GUI の shared action と SSH PSReadLine の OSC 応答を検証する専用設定。
local wezterm = require("wezterm")
package.path = wezterm.config_dir .. "/../../lua/?.lua;" .. package.path
package.loaded.shells = { list = function() return {} end, for_split = function() return {} end }
local actions = require("actions")
local config = wezterm.config_builder()
require("bindings").apply(config)
require("paste").apply(config)
config.font = wezterm.font("JetBrains Mono")
config.initial_cols = 120
config.initial_rows = 40
config.enable_tab_bar = false
config.check_for_updates = false
config.automatically_reload_config = false
config.status_update_interval = 100
config.window_close_confirmation = "NeverPrompt"
config.exit_behavior = "Hold"
config.front_end = "Software"
local out = assert(os.getenv("WEZTERM_SSH_PASTE_GUI_OUTPUT"))
local last_token, timer_started = nil, false
local probes = {}

local function write(name, value)
	local file = assert(io.open(out .. "/" .. name, "wb"))
	file:write(wezterm.json_encode(value))
	file:close()
end

wezterm.on("user-var-changed", function(_window, pane, name, value)
	if name == "WEZTERM_SSH_PASTE_TEST" and probes[pane:pane_id()] then
		local identifier = probes[pane:pane_id()]
		probes[pane:pane_id()] = nil
		write(identifier .. ".probe.json", wezterm.json_parse(value))
	end
end)

local function route(name)
	if name == "shared" then return actions.paste_clipboard end
	for _, binding in ipairs(config.keys) do
		if name == "key" and binding.key == "v" and binding.mods == "CTRL|SHIFT" then return binding.action end
	end
	for _, binding in ipairs(config.mouse_bindings) do
		if binding.event.Down and binding.event.Down.button == "Right" and binding.mods == "NONE"
			and (binding.mouse_reporting == true) == (name == "right-reporting") then return binding.action end
	end
	error("試験の貼り付け経路が見つかりません")
end

local function process(window, pane)
	local file = io.open(out .. "/request.json", "rb")
	if not file then return end
	local raw = file:read("*a")
	file:close()
	local parsed, req = pcall(wezterm.json_parse, raw)
	if not parsed or req.token == last_token or req.pane_id ~= pane:pane_id() then return end
	last_token = req.token
	local ok, result = pcall(function()
		if req.operation == "paste" then
			-- この試験が作った無害なテキストだけを隔離した clip に入れる。
			window:copy_to_clipboard(req.text, "Clipboard")
			window:perform_action(route(req.route), pane)
		elseif req.operation == "probe" then
			probes[pane:pane_id()] = req.id
			window:perform_action(wezterm.action.SendKey({ key = "F11" }), pane)
		elseif req.operation == "enter" then
			window:perform_action(wezterm.action.SendKey({ key = "Enter" }), pane)
		elseif req.operation == "cancel" then
			window:perform_action(wezterm.action.SendKey({ key = "c", mods = "CTRL" }), pane)
		elseif req.operation == "select" then
			window:perform_action(wezterm.action.SendKey({ key = "F10" }), pane)
		elseif req.operation ~= "snapshot" then error("不明な試験操作") end
		local vars = pane:get_user_vars() or {}
		return {
			marker = vars.WEZTERM_PSREADLINE_SSH_PASTE or "",
			ready = vars.WEZTERM_PSREADLINE_SSH_READY or "",
			result = vars.WEZTERM_PSREADLINE_SSH_RESULT or "",
			init = vars.WEZTERM_SSH_PASTE_TEST_INIT and wezterm.json_parse(vars.WEZTERM_SSH_PASTE_TEST_INIT) or nil,
			foreground = pane:get_foreground_process_name(),
			alt_screen = pane:is_alt_screen_active(),
		}
	end)
	write(req.id .. ".action.json", ok and result or { error = tostring(result) })
end

wezterm.on("update-status", function(window, pane)
	if timer_started then return end
	timer_started = true
	local function tick()
		local ok = pcall(process, window, window:active_pane())
		if not ok then return end
		wezterm.time.call_after(0.05, tick)
	end
	process(window, pane)
	wezterm.time.call_after(0.05, tick)
end)
return config
