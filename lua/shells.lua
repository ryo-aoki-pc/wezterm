local wezterm = require("wezterm")
local M = {}

-- シェル統合スクリプト（OSC 7 でカレントディレクトリ、OSC 133 でプロンプト位置を通知）。
-- bash 系は環境変数 WEZTERM_SHELL_INTEGRATION でパスを渡し、~/.bashrc の 1 行に
-- 読み込ませる。PowerShell 系は起動引数でドットソースするので追記は不要。
-- 詳細は shell/wezterm.sh / shell/wezterm.ps1 と README を参照
local INTEGRATION_SH = wezterm.config_dir .. "/shell/wezterm.sh"
local INTEGRATION_PS1 = wezterm.config_dir .. "/shell/wezterm.ps1"

-- PowerShell 起動引数に足す統合読み込み。-Command はプロファイルを抑止しない
-- （抑止するのは -NoProfile）が、-NoExit が無いと実行後に閉じてしまう
local PS_INTEGRATION_ARGS = { "-NoExit", "-Command", ". '" .. INTEGRATION_PS1 .. "'" }

-- 配列を連結した新しい配列を返す（元の配列は変更しない）
local function concat_args(base, extra)
	local out = {}
	for _, v in ipairs(base) do
		table.insert(out, v)
	end
	for _, v in ipairs(extra) do
		table.insert(out, v)
	end
	return out
end

-- ファイルの有無を調べる。
-- ※ Microsoft Store 版 PowerShell 7 などの「アプリ実行エイリアス」は 0 バイトの
--   再解析ポイントで、io.open は「システムはファイルにアクセスできません」で失敗する。
--   一方 CreateProcess からは普通に起動できるので、存在扱いにしたい。
--   os.rename(path, path) は同名へのリネーム＝中身を変えない操作で、無いときだけ
--   ENOENT(2) を返すため、これを保険の判定に使う
-- ※ wezterm.glob / wezterm.read_dir は非同期で、設定評価中に呼ぶと
--   "attempt to yield from outside a coroutine" になり設定ごと落ちるため使えない
local function exists(path)
	local f = io.open(path, "r")
	if f then
		f:close()
		return true
	end
	local ok, _, errno = os.rename(path, path)
	if ok then
		return true
	end
	-- アクセス拒否(13)等は「有る」扱い。errno が取れないときも「無い」とは断定しない
	return errno ~= nil and errno ~= 2
end

local function first_existing(paths)
	for _, p in ipairs(paths) do
		if exists(p) then
			return p
		end
	end
	return nil
end

-- Visual Studio の開発者向けシェル用スクリプトが入ったディレクトリ（Common7/Tools）を
-- 標準インストールパスから探す。バージョン × エディションを総当りし、最初に見つかった
-- ディレクトリ（末尾 / 付き）と、表示用の VS バージョン（年）を返す。
-- ※ PowerShell 版 (Launch-VsDevShell.ps1) と cmd 版 (VsDevCmd.bat) は同じディレクトリに
--   入っているので、総当りは 1 回だけ行い、呼び出し側でファイル名を足す
local function find_vs_tools()
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
				local dir = base .. "/" .. ver .. "/" .. ed .. "/Common7/Tools/"
				if exists(dir .. "Launch-VsDevShell.ps1") then
					return dir, (year_of[ver] or ver)
				end
			end
		end
	end
	return nil
end

-- Windows 以外（Linux / macOS）かどうか。Windows 用の探索は USERPROFILE や
-- C:/ 配下のパスに依存するので、他 OS ではこの判定で丸ごとスキップする
local is_windows = wezterm.target_triple:find("windows") ~= nil

-- Linux / macOS: PATH 上の代表的なシェルを探す。default_prog は設定せず、
-- WezTerm の既定（$SHELL）に任せる
local function discover_unix()
	local list = {}
	local candidates = {
		{ label = "  bash", names = { "/bin/bash", "/usr/bin/bash" } },
		{ label = "  zsh",  names = { "/bin/zsh", "/usr/bin/zsh", "/usr/local/bin/zsh", "/opt/homebrew/bin/zsh" } },
		{ label = "  fish", names = { "/usr/bin/fish", "/usr/local/bin/fish", "/opt/homebrew/bin/fish" } },
		{ label = "  nu",   names = { "/usr/bin/nu", "/usr/local/bin/nu", "/opt/homebrew/bin/nu" } },
	}
	for _, c in ipairs(candidates) do
		local path = first_existing(c.names)
		if path then
			table.insert(list, { label = c.label, args = { path, "-l" } })
		end
	end
	return { default_prog = nil, list = list }
end

-- シェル一覧を一度だけ探索してキャッシュする。
-- 各エントリは launch_menu / SpawnCommand 兼用の形（label + args/domain + env）。
local cache

local function discover()
	if cache then
		return cache
	end

	if not is_windows then
		cache = discover_unix()
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
	-- PowerShell 7。Microsoft Store 版は実体が
	-- C:/Program Files/WindowsApps/Microsoft.PowerShell_<版>_x64__.../pwsh.exe と
	-- バージョン番号入りで、しかも親フォルダが ACL で列挙できないため直接は書けない。
	-- 代わりに安定した入口であるアプリ実行エイリアスを候補に入れる
	local pwsh = first_existing({
		"C:/Program Files/PowerShell/7/pwsh.exe",                -- 公式インストーラ（MSI）
		home .. "/scoop/apps/pwsh/current/pwsh.exe",             -- scoop
		home .. "/AppData/Local/Microsoft/WindowsApps/pwsh.exe", -- Microsoft Store 版（アプリ実行エイリアス）
	})
	-- Visual Studio の開発者向けシェル。PowerShell 版と cmd 版を同じ Common7/Tools から作る
	local vs_tools, vsversion = find_vs_tools()
	local vsdevshell = vs_tools and (vs_tools .. "Launch-VsDevShell.ps1") or nil
	-- Developer PowerShell。Launch-VsDevShell.ps1 を Windows PowerShell から呼び、
	-- -NoExit でセッションを維持する。
	-- ※ 既に -Command を持つので PS_INTEGRATION_ARGS は足さず、コマンド文字列の
	--   末尾に統合の読み込みを繋げる（-Command は 1 回しか指定できない）
	local vsdevshell_args = vsdevshell and {
		"powershell.exe", "-NoLogo", "-ExecutionPolicy", "Bypass", "-NoExit",
		"-Command", "& '" .. vsdevshell .. "' -Arch amd64 -HostArch amd64 -SkipAutomaticLocation"
			.. "; . '" .. INTEGRATION_PS1 .. "'",
	} or nil
	-- メニュー表示名に VS のバージョン（年）を付ける（例: "Developer PowerShell (2026)"）
	local vsdevshell_label = vsdevshell and ("  Developer PowerShell (" .. vsversion .. ")")
		or "  Developer PowerShell"

	-- Developer Command Prompt（Developer PowerShell の cmd 版）。VsDevCmd.bat は
	-- Launch-VsDevShell.ps1 と同じディレクトリにあるが、BuildTools 等で欠けることも
	-- あり得るので個別に存在を確かめる。
	-- ※ バッチのパスと引数は argv を分けて渡す。cmd /k は引用符の扱いが特殊なので、
	--   " を自前で組み立てず WezTerm のコマンドライン組み立てに任せる
	-- ※ cmd 向けのシェル統合スクリプトは無いため、統合の読み込みは足さない
	local vsdevcmd = vs_tools and exists(vs_tools .. "VsDevCmd.bat") and (vs_tools .. "VsDevCmd.bat")
		or nil
	local vsdevcmd_args = vsdevcmd and {
		"cmd.exe", "/k", vsdevcmd, "-arch=amd64", "-host_arch=amd64", "-no_logo",
	} or nil
	local vsdevcmd_label = vsdevcmd and ("  Developer Command Prompt (" .. vsversion .. ")")
		or "  Developer Command Prompt"

	local candidates = {
		{ ok = git_bash ~= nil,     label = "  Git Bash",            args = git_bash_args },
		{ ok = pwsh ~= nil,         label = "  PowerShell 7",        args = pwsh and concat_args({ pwsh, "-NoLogo" }, PS_INTEGRATION_ARGS) },
		{ ok = true,                label = "  Windows PowerShell",  args = concat_args({ "powershell.exe", "-NoLogo" }, PS_INTEGRATION_ARGS) },
		-- ※ cmd.exe は Windows なら必ずあるので、powershell.exe と同じく実体パスを
		--   探さず名前解決に任せる（シェル統合は cmd 向けが無いので付けない）
		{ ok = true,                label = "  Command Prompt",      args = { "cmd.exe" } },
		{ ok = vsdevshell ~= nil,   label = vsdevshell_label,        args = vsdevshell_args },
		{ ok = vsdevcmd ~= nil,     label = vsdevcmd_label,          args = vsdevcmd_args },
		{ ok = exists(msys2_shell), label = "  MSYS2 UCRT64",        args = { msys2_shell, "-defterm", "-here", "-no-start", "-ucrt64" } },
		{ ok = exists(msys2_shell), label = "  MSYS2 MSYS",          args = { msys2_shell, "-defterm", "-here", "-no-start", "-msys" } },
		-- ※ env を指定するエントリでは、全体設定 (M.apply の set_environment_variables) に
		--   頼らず WEZTERM_SHELL_INTEGRATION を明示的に含めておく
		{ ok = exists(qmk_bash),    label = "  QMK MSYS",            args = { qmk_bash, "-l", "-i" }, env = { MSYSTEM = "MINGW64", MSYS2_PATH_TYPE = "inherit", WEZTERM_SHELL_INTEGRATION = INTEGRATION_SH } },
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

	-- default_wsl_domains() は内部で wsl.exe を起動するため、ここで一度だけ呼んで
	-- 結果を使い回す（launch_menu への展開と config.wsl_domains の両方で使う）
	local wsl_domains = wezterm.default_wsl_domains()
	for _, dom in ipairs(wsl_domains) do
		local display = dom.name:gsub("^WSL:", "")
		table.insert(list, {
			label = "  " .. display,
			domain = { DomainName = dom.name },
		})
	end

	cache = {
		default_prog = git_bash_args,
		list = list,
		wsl_domains = wsl_domains,
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

	-- bash 系シェルへ統合スクリプトのパスを渡す。ここで全体に設定しておくことで、
	-- launch_menu の項目だけでなく default_prog（起動直後のタブ）や
	-- Ctrl+Shift+D/E で分割したペインにも同じように行き渡る
	config.set_environment_variables = { WEZTERM_SHELL_INTEGRATION = INTEGRATION_SH }

	if d.default_prog then
		config.default_prog = d.default_prog
	end

	if d.wsl_domains then
		config.wsl_domains = d.wsl_domains
	end
	config.launch_menu = d.list
end

return M
