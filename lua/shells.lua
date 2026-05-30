local wezterm = require("wezterm")
local M = {}

local function exists(path)
	local f = io.open(path, "r")
	if f then
		f:close()
	end
	return f ~= nil
end

local function first_existing(paths)
	for _, p in ipairs(paths) do
		if exists(p) then
			return p
		end
	end
	return nil
end

-- シェル一覧を一度だけ探索してキャッシュする。
-- 各エントリは launch_menu / SpawnCommand 兼用の形（label + args/domain + env）。
local cache

local function discover()
	if cache then
		return cache
	end

	local home = os.getenv("USERPROFILE")
	local git_bash = home .. "/scoop/apps/git/current/bin/bash.exe"
	local git_bash_args = { git_bash, "-i", "-l" }
	local msys2_shell = "C:/msys64/msys2_shell.cmd"
	local qmk_bash = "C:/QMK_MSYS/usr/bin/bash.exe"
	local pwsh = first_existing({
		"C:/Program Files/PowerShell/7/pwsh.exe",
		home .. "/scoop/apps/pwsh/current/pwsh.exe",
	})

	local candidates = {
		{ ok = exists(git_bash),    label = "  Git Bash",            args = git_bash_args },
		{ ok = pwsh ~= nil,         label = "  PowerShell 7",        args = { pwsh, "-NoLogo" } },
		{ ok = true,                label = "  Windows PowerShell",  args = { "powershell.exe", "-NoLogo" } },
		{ ok = exists(msys2_shell), label = "  MSYS2 UCRT64",        args = { msys2_shell, "-defterm", "-here", "-no-start", "-ucrt64" } },
		{ ok = exists(msys2_shell), label = "  MSYS2 MSYS",          args = { msys2_shell, "-defterm", "-here", "-no-start", "-msys" } },
		{ ok = exists(qmk_bash),    label = "  QMK MSYS",            args = { qmk_bash, "-l", "-i" }, env = { MSYSTEM = "MINGW64", MSYS2_PATH_TYPE = "inherit" } },
	}

	local list = {}
	for _, c in ipairs(candidates) do
		if c.ok then
			table.insert(list, {
				label = c.label,
				args = c.args,
				set_environment_variables = c.env,
			})
		end
	end

	for _, dom in ipairs(wezterm.default_wsl_domains()) do
		local display = dom.name:gsub("^WSL:", "")
		table.insert(list, {
			label = "  " .. display,
			domain = { DomainName = dom.name },
		})
	end

	cache = {
		default_prog = exists(git_bash) and git_bash_args or nil,
		list = list,
	}
	return cache
end

-- 起動可能なシェル一覧（SpawnCommand 互換のエントリ配列）を返す。
-- launch_menu と「分割して起動」の両方から再利用する。
function M.list()
	return discover().list
end

function M.apply(config)
	local d = discover()

	if d.default_prog then
		config.default_prog = d.default_prog
	end

	config.wsl_domains = wezterm.default_wsl_domains()
	config.launch_menu = d.list
end

return M
