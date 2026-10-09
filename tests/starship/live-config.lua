-- 本番モジュールを実 WezTerm で検証する専用設定。ユーザー設定は変更しない。
local wezterm = require("wezterm")
local root = wezterm.config_dir .. "/../.."
package.path = root .. "/lua/?.lua;" .. package.path
local real_on, format_tab_title = wezterm.on
wezterm.on = function(name, fn)
  if name == "format-tab-title" then format_tab_title = fn end
  return real_on(name, fn)
end
local config = dofile(root .. "/wezterm.lua")
wezterm.on = real_on
local out = os.getenv("WEZTERM_STARSHIP_TEST_OUTPUT") or (wezterm.config_dir .. "/live-results")
local test_env = config.set_environment_variables
test_env.WEZTERM_SHELL_INTEGRATION = root .. "/shell/wezterm.sh"
test_env.STARSHIP_CACHE = out .. "/cache"
test_env.STARSHIP_CONFIG = wezterm.config_dir .. "/live-starship.toml"
test_env.WEZTERM_NOTIFY_AFTER = "1"
config.set_environment_variables = test_env
config.check_for_updates = false
config.status_update_interval = 200
config.automatically_reload_config = false

-- 実際のコピー関数を呼び、クリップボードへの書き込みだけを捕捉する。
local callback_bodies = {}
local real_callback = wezterm.action_callback
wezterm.action_callback = function(fn)
  local action = real_callback(fn)
  callback_bodies[action] = fn
  return action
end
package.loaded.actions = nil
local copy_action = require("actions").copy_last_output
wezterm.action_callback = real_callback
local copy_body = callback_bodies[copy_action]
local last_request
local function write_json(path, data)
  local f = assert(io.open(path, "w"))
  f:write(wezterm.json_encode(data))
  f:close()
end
wezterm.on("update-status", function(window, pane)
  local f = io.open(out .. "/request.json", "r")
  if not f then return end
  local raw = f:read("*a")
  f:close()
  local ok, req = pcall(wezterm.json_parse, raw)
  if not ok or (req.token or req.id) == last_request then return end
  if req.pane_id and pane:pane_id() ~= req.pane_id then return end
  last_request = req.token or req.id
  local good, result = pcall(function()
    local zones = pane:get_semantic_zones()
    local texts = {}
    for i, z in ipairs(zones) do texts[i] = pane:get_text_from_semantic_zone(z) end
    local copied, status
    local proxy = setmetatable({
      copy_to_clipboard = function(_, value) copied = value end,
      set_right_status = function(_, value) status = value end,
    }, { __index = function(_, key)
      return function(_, ...) return window[key](window, ...) end
    end })
    copy_body(proxy, pane)
    local result = {
      id = req.id, pane_id = pane:pane_id(), zones = zones, zone_texts = texts,
      vars = pane:get_user_vars(), cursor = pane:get_cursor_position(),
      cwd = tostring(pane:get_current_working_dir()), title = pane:get_title(),
      dimensions = pane:get_dimensions(), copied = copied or false,
      copy_status = status or "", key_table = window:active_key_table() or "",
    }
    result.foreground_process_name = pane:get_foreground_process_name() or ""
    result.running_program = require("procs").running(result.foreground_process_name,
      result.vars.WEZTERM_PROG)
    if format_tab_title then
      local elements = format_tab_title({ tab_index = 0, is_active = true, tab_title = "",
        active_pane = { title = result.title, user_vars = result.vars,
          foreground_process_name = result.foreground_process_name,
          current_working_dir = pane:get_current_working_dir(), is_zoomed = false,
          progress = pane:get_progress() } }, {}, {}, config, false, 40)
      local pieces = {}
      for _, e in ipairs(elements) do
        if e.Text then table.insert(pieces, e.Text) end
      end
      result.formatted_tab = table.concat(pieces)
    end
    if req.action == "prompt" then
      window:perform_action(wezterm.action.ScrollToPrompt(-1), pane)
      result.after_prompt = pane:get_dimensions()
      result.after_prompt_text = pane:get_lines_as_text()
      -- CopyMode の MoveToViewportTop は上端から 5 行の余白を取る。
      -- その行の選択文字列を期待する絶対行と比較し、viewport の移動を観測する。
      local target_row = 0
      for _, z in ipairs(zones) do
        if z.semantic_type == "Prompt" and z.start_y < result.dimensions.physical_top then
          target_row = math.max(target_row, z.start_y)
        end
      end
      result.prompt_target_row = target_row
      result.prompt_probe_offset = result.dimensions.physical_top <= 5 and 1 or 5
      local probe_row = target_row + result.prompt_probe_offset
      result.prompt_probe_expected = pane:get_text_from_region(0, probe_row,
        result.dimensions.cols, probe_row)
      window:perform_action(wezterm.action.ActivateCopyMode, pane)
      window:perform_action(wezterm.action.CopyMode("MoveToViewportTop"), pane)
      window:perform_action(wezterm.action.CopyMode { SetSelectionMode = "Line" }, pane)
      result.prompt_probe_line = window:get_selection_text_for_pane(pane)
      window:perform_action(wezterm.action.CopyMode("Close"), pane)
    elseif req.action == "resize" then
      window:perform_action(wezterm.action.ActivateKeyTable {
        name = "resize_pane", one_shot = false, timeout_milliseconds = 2000,
      }, pane)
      result.key_table = window:active_key_table()
      window:perform_action(wezterm.action.PopKeyTable, pane)
    elseif req.action == "copy-mode" then
      window:perform_action(wezterm.action.ActivateCopyMode, pane)
      result.key_table = window:active_key_table()
      window:perform_action(wezterm.action.CopyMode("Close"), pane)
    end
    return result
  end)
  if not good then result = { id = req.id, error = tostring(result) } end
  write_json(out .. "/" .. req.id .. ".json", result)
end)
return config
