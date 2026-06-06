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

-- Visual Studio の Developer PowerShell 用スクリプト（Launch-VsDevShell.ps1）を
-- 標準インストールパスから探す。年度 × エディションを総当りし最初の一つを返す。
local function find_vsdevshell()
	local bases = {
		"C:/Program Files/Microsoft Visual Studio",        -- 2022 / 2026（64bit 既定）
		"C:/Program Files (x86)/Microsoft Visual Studio",  -- 2019 以前
	}
	local years = { "2026", "2022", "2019" } -- 新しい順。複数導入時は最新を優先
	local editions = { "Community", "Professional", "Enterprise", "Preview", "BuildTools" }
	for _, base in ipairs(bases) do
		for _, year in ipairs(years) do
			for _, ed in ipairs(editions) do
				local p = base .. "/" .. year .. "/" .. ed .. "/Common7/Tools/Launch-VsDevShell.ps1"
				if exists(p) then
					return p
				end
			end
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
	-- Visual Studio の Developer PowerShell。Launch-VsDevShell.ps1 を
	-- Windows PowerShell から呼び、-NoExit でセッションを維持する。
	local vsdevshell = find_vsdevshell()
	local vsdevshell_args = vsdevshell and {
		"powershell.exe", "-NoLogo", "-ExecutionPolicy", "Bypass", "-NoExit",
		"-Command", "& '" .. vsdevshell .. "' -Arch amd64 -HostArch amd64 -SkipAutomaticLocation",
	} or nil

	local candidates = {
		{ ok = exists(git_bash),    label = "  Git Bash",            args = git_bash_args },
		{ ok = pwsh ~= nil,         label = "  PowerShell 7",        args = { pwsh, "-NoLogo" } },
		{ ok = true,                label = "  Windows PowerShell",  args = { "powershell.exe", "-NoLogo" } },
		{ ok = vsdevshell ~= nil,   label = "  Developer PowerShell", args = vsdevshell_args },
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
