-- 専用 GUI/ConPTY の貼り付け検証。利用者の起動メニューや SSH 設定は読まない。
local wezterm = require("wezterm")
local root = wezterm.config_dir .. "/../.."
package.path = root .. "/lua/?.lua;" .. package.path
package.loaded.shells = { list = function() return {} end, for_split = function() return {} end }
local actions = require("actions")
local config = wezterm.config_builder()
require("bindings").apply(config)
require("paste").apply(config)
config.font = wezterm.font("Consolas")
config.initial_cols = 120
config.initial_rows = 40
config.enable_tab_bar = false
config.check_for_updates = false
config.automatically_reload_config = false
config.status_update_interval = 100
config.window_close_confirmation = "NeverPrompt"
config.exit_behavior = "Close"
local out = os.getenv("WEZTERM_PASTE_TEST_OUTPUT") or wezterm.config_dir .. "/results"
local last_token
local timer_started = false

local function configured_action(route)
	if route == "shared" then return actions.paste_clipboard end
	if route == "baseline" then return wezterm.action.PasteFrom("Clipboard") end
	if route == "key" then
		for _, binding in ipairs(config.keys) do
			if binding.key == "v" and binding.mods == "CTRL|SHIFT" then return binding.action end
		end
	else
		for _, binding in ipairs(config.mouse_bindings) do
			local down = binding.event.Down
			if down and down.button == "Right" and binding.mods == "NONE"
				and (binding.mouse_reporting == true) == (route == "right-reporting") then
				return binding.action
			end
		end
	end
	error("貼り付けの設定が見つからない: " .. tostring(route))
end

local function process_request(window, pane)
	local file = io.open(out .. "/request.json", "rb")
	if not file then return end
	local raw = file:read("*a")
	file:close()
	local parsed, req = pcall(wezterm.json_parse, raw)
	if not parsed or req.token == last_token or req.pane_id ~= pane:pane_id() then return end
	last_token = req.token
	local ok, result = pcall(function()
		if req.operation == "paste" then
			-- req.text はこの検証で生成した無害なコードだけ。
			window:copy_to_clipboard(req.text, "Clipboard")
			window:perform_action(configured_action(req.route), pane)
		elseif req.operation == "probe" then
			window:perform_action(wezterm.action.SendKey({ key = "F11" }), pane)
		elseif req.operation == "enter" then
			window:perform_action(wezterm.action.SendKey({ key = "Enter" }), pane)
		elseif req.operation == "cancel" then
			window:perform_action(wezterm.action.SendKey({ key = "c", mods = "CTRL" }), pane)
		elseif req.operation ~= "snapshot" then error("不明な操作") end
		local vars = pane:get_user_vars() or {}
		local effective = window:effective_config()
		return {
			marker = vars.WEZTERM_PSREADLINE_PASTE or "",
			foreground = pane:get_foreground_process_name(),
			domain = pane:get_domain_name(),
			alt_screen = pane:is_alt_screen_active(),
			key_table = window:active_key_table(),
			canonicalize_pasted_newlines = effective.canonicalize_pasted_newlines
				and tostring(effective.canonicalize_pasted_newlines) or "platform-default",
			allow_win32_input_mode = effective.allow_win32_input_mode,
		}
	end)
	local dest = assert(io.open(out .. "/" .. req.id .. ".action.json", "wb"))
	dest:write(wezterm.json_encode(ok and result or { error = tostring(result) }))
	dest:close()
end

-- 非表示 GUI では描画に伴う update-status が休止するため専用タイマーを使う。
wezterm.on("update-status", function(window, pane)
	if timer_started then return end
	timer_started = true
	local function tick()
		local ok, err = pcall(process_request, window, window:active_pane())
		if not ok then wezterm.log_error(err) end
		wezterm.time.call_after(0.05, tick)
	end
	process_request(window, pane)
	wezterm.time.call_after(0.05, tick)
end)
return config
