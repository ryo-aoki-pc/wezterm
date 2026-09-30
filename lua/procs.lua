-- ペインで今動いているプログラムの判定（apply は持たないデータモジュール）。
-- タブのアイコン・タイトル（tabs.lua）と、出力コピーの ssh 判定（actions.lua）から使う
local M = {}

-- フォアグラウンドにいる間、画面の中身が別のマシンになるプログラム
M.REMOTE = { ["ssh"] = true, ["mosh"] = true, ["mosh-client"] = true }

-- パスからプログラム名を取り出す（パス末尾 → 小文字化 → .exe 除去。\ と / の両方に対応）。
-- 例: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" → "pwsh"。nil や空文字なら ""
function M.basename(path)
	local name = (path or ""):match("([^/\\]+)$") or ""
	return (name:lower():gsub("%.exe$", ""))
end

-- コマンド行で、実際に動くプログラムの前に置かれる語（飛ばして次の語を見る）
local PREFIXES = {
	["sudo"] = true,
	["doas"] = true,
	["exec"] = true,
	["command"] = true,
	["builtin"] = true,
	["env"] = true,
	["time"] = true,
	["nice"] = true,
	["nohup"] = true,
	["winpty"] = true,
}

-- 1 つのコマンド（; や && で区切る前の単位）から、実際に動くプログラムの名前を取り出す（無ければ ""）。
-- 例: "TERM=xterm-256color sudo -E ssh -p 22 host" → "ssh"
-- 先頭の変数代入（NAME=値）・上の前置き・オプション（- で始まる語）・数字だけの語
-- （nice -n 10 の 10）を飛ばした最初の語。引用符は外す。
-- ※ 値を取るオプションの値（sudo -u root ssh … の root）は見分けられず、プログラム名とみなす
-- ※ エイリアスや関数は展開しない（alias s='ssh host' の s は s のまま）
function M.program_of(cmdline)
	for word in (cmdline or ""):gmatch("%S+") do
		word = (word:gsub("[\"']", ""))
		if
			word ~= ""
			and not PREFIXES[word]
			and not word:find("^%-")
			and not word:find("^%d+$")
			and not word:find("^[%a_][%w_]*=")
		then
			return M.basename(word)
		end
	end
	return ""
end

-- コマンド行（入力したとおりの 1 行）で、今動いていそうなプログラムの名前を選ぶ（無ければ ""）。
-- ; && || | & と改行で区切った各コマンドのうち、ssh / mosh があればそれ（cd dir && ssh host、
-- clear; ssh host など）、無ければ最初のコマンドのプログラム。
-- ※ 引用符の中の区切り文字も区切りとみなす（ssh の判定の目安なので、厳密には解析しない）
function M.main_program(cmdline)
	local first = ""
	for seg in ((cmdline or "") .. "\n"):gmatch("([^;&|\n]*)[;&|\n]") do
		local p = M.program_of(seg)
		if M.REMOTE[p] then
			return p
		end
		if first == "" then
			first = p
		end
	end
	return first
end

-- WEZTERM_PROG で補ってよいフォアグラウンド: シェル自身・WSL の入口・不明（""）
local SHELLS = {
	[""] = true,
	["bash"] = true,
	["sh"] = true,
	["zsh"] = true,
	["fish"] = true,
	["nu"] = true,
	["pwsh"] = true,
	["powershell"] = true,
	["cmd"] = true,
	["wsl"] = true,
	["wslhost"] = true,
}

-- ペインで今動いているプログラムの名前（小文字・拡張子なし。例: "pwsh" / "vim" / "ssh"）。
--   fg   WezTerm が調べたフォアグラウンドプロセスのパス
--   prog シェル統合が送るユーザー変数 WEZTERM_PROG（実行中のコマンド行。待機中は空。nil も可）
-- Git Bash / MSYS2 から起動したプログラムは Windows 上で親プロセスが消えるため WezTerm には
-- bash.exe しか見えず、WSL の中は wsl.exe（か不明）にしか見えない。フォアグラウンドがシェル・
-- WSL の入口・不明のときだけコマンド行で補う（ssh.exe などが見えていればそちらが確か）
function M.running(fg, prog)
	local name = M.basename(fg)
	if SHELLS[name] and prog and prog ~= "" then
		local p = M.main_program(prog)
		if p ~= "" then
			return p
		end
	end
	return name
end

return M
