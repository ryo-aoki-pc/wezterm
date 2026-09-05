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
-- 標準インストールパスから探す。バージョン × エディションを総当りし、最初に
-- 見つかったスクリプトのパスと、表示用の VS バージョン（年）を返す。
local function find_vsdevshell()
	local bases = {
		"C:/Program Files/Microsoft Visual Studio",        -- 2022（64bit）
		"C:/Program Files (x86)/Microsoft Visual Studio",  -- 2026(=18) / 2019 以前
	}
	-- フォルダ名は年（2022 等）またはメジャーバージョン（VS2026 = 18）。新しい順で探索。
	local versions = { "18", "2026", "2022", "2019" }
	-- メジャーバージョン → VS の年（年フォルダはそのまま表示する）
	local year_of = { ["18"] = "2026", ["17"] = "2022", ["16"] = "2019", ["15"] = "2017" }
	local editions = { "Community", "Professional", "Enterprise", "Preview", "BuildTools" }
	for _, base in ipairs(bases) do
		for _, ver in ipairs(versions) do
			for _, ed in ipairs(editions) do
				local p = base .. "/" .. ver .. "/" .. ed .. "/Common7/Tools/Launch-VsDevShell.ps1"
				if exists(p) then
					return p, (year_of[ver] or ver)
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
	-- Git for Windows の bash。bin/bash.exe は MSYSTEM=MINGW64 を設定する
	-- ラッパーなので、usr/bin/bash.exe ではなくこちらを使う
	local git_bash = first_existing({
		"C:/Program Files/Git/bin/bash.exe",                -- 公式インストーラ（全ユーザー）
		home .. "/AppData/Local/Programs/Git/bin/bash.exe", -- 公式インストーラ（現在のユーザーのみ）
		home .. "/scoop/apps/git/current/bin/bash.exe",     -- scoop
	})
	local git_bash_args = git_bash and { git_bash, "-i", "-l" } or nil
	local msys2_shell = "C:/msys64/msys2_shell.cmd"
	local qmk_bash = "C:/QMK_MSYS/usr/bin/bash.exe"
	local pwsh = first_existing({
		"C:/Program Files/PowerShell/7/pwsh.exe",
		home .. "/scoop/apps/pwsh/current/pwsh.exe",
	})
	-- Visual Studio の Developer PowerShell。Launch-VsDevShell.ps1 を
	-- Windows PowerShell から呼び、-NoExit でセッションを維持する。
	local vsdevshell, vsversion = find_vsdevshell()
	local vsdevshell_args = vsdevshell and {
		"powershell.exe", "-NoLogo", "-ExecutionPolicy", "Bypass", "-NoExit",
		"-Command", "& '" .. vsdevshell .. "' -Arch amd64 -HostArch amd64 -SkipAutomaticLocation",
	} or nil
	-- メニュー表示名に VS のバージョン（年）を付ける（例: "Developer PowerShell (2026)"）
	local vsdevshell_label = vsdevshell and ("  Developer PowerShell (" .. vsversion .. ")")
		or "  Developer PowerShell"

	local candidates = {
		{ ok = git_bash ~= nil,     label = "  Git Bash",            args = git_bash_args },
		{ ok = pwsh ~= nil,         label = "  PowerShell 7",        args = { pwsh, "-NoLogo" } },
		{ ok = true,                label = "  Windows PowerShell",  args = { "powershell.exe", "-NoLogo" } },
		{ ok = vsdevshell ~= nil,   label = vsdevshell_label,        args = vsdevshell_args },
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
		default_prog = git_bash_args,
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
