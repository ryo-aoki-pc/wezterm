local wezterm = require("wezterm")
local palette = require("colors").palette
local ui = require("ui")
local procs = require("procs")
local M = {}

local nf = wezterm.nerdfonts

-- 丸型のパワーライン区切り（ピル状タブ）※定義は ui.lua
local LEFT_CAP = ui.LEFT_CAP
local RIGHT_CAP = ui.RIGHT_CAP
local ZOOM_ICON = nf.md_magnify or ""
-- 見ていない間に出力があったタブに付ける印（非アクティブタブのみ）
-- U+25CF = 黒丸。Nerd Font が無い環境でも出るようフォールバックに使う
local UNSEEN_ICON = nf.md_circle_medium or utf8.char(0x25cf)

-- 汎用端末アイコン（未知のプロセス・プロセス名が取れない場合のフォールバック）
local GENERIC_ICON = nf.cod_terminal or nf.md_console or utf8.char(0xe795)

-- 実行中プロセス名 → Nerd Font アイコン
-- ※ キーが存在しない wezterm バージョンでも nil エラーにならないよう or でガード
local PROCESS_ICONS = {
	-- シェル
	["pwsh"] = nf.md_powershell or GENERIC_ICON,
	["powershell"] = nf.md_powershell or GENERIC_ICON,
	["cmd"] = nf.cod_terminal_cmd or GENERIC_ICON,
	["bash"] = nf.cod_terminal_bash or GENERIC_ICON,
	["sh"] = nf.cod_terminal_bash or GENERIC_ICON,
	["zsh"] = nf.dev_terminal or GENERIC_ICON,
	["fish"] = nf.md_fish or GENERIC_ICON,
	["nu"] = nf.md_console or GENERIC_ICON,
	-- WSL / Linux
	["wsl"] = nf.linux_tux or GENERIC_ICON,
	["wslhost"] = nf.linux_tux or GENERIC_ICON,
	-- エディタ
	["nvim"] = nf.custom_neovim or nf.custom_vim or GENERIC_ICON,
	["vim"] = nf.custom_vim or GENERIC_ICON,
	-- 開発ツール
	["node"] = nf.md_nodejs or GENERIC_ICON,
	["python"] = nf.md_language_python or GENERIC_ICON,
	["python3"] = nf.md_language_python or GENERIC_ICON,
	["git"] = nf.dev_git or GENERIC_ICON,
	["lazygit"] = nf.dev_git or GENERIC_ICON,
	["gh"] = nf.oct_mark_github or GENERIC_ICON,
	["cargo"] = nf.dev_rust or GENERIC_ICON,
	["rustc"] = nf.dev_rust or GENERIC_ICON,
	["go"] = nf.md_language_go or GENERIC_ICON,
	["docker"] = nf.md_docker or GENERIC_ICON,
	["kubectl"] = nf.md_docker or GENERIC_ICON,
	["ssh"] = nf.cod_remote or GENERIC_ICON,
	-- モニタリング
	["top"] = nf.md_chart_line or GENERIC_ICON,
	["htop"] = nf.md_chart_line or GENERIC_ICON,
	["btop"] = nf.md_chart_line or GENERIC_ICON,
}

-- ConEmu 方式 (OSC 9;4) の進捗表示用グリフ（12.5% 刻みの円スライス）
local PROGRESS_SLICES = {
	nf.md_circle_slice_1,
	nf.md_circle_slice_2,
	nf.md_circle_slice_3,
	nf.md_circle_slice_4,
	nf.md_circle_slice_5,
	nf.md_circle_slice_6,
	nf.md_circle_slice_7,
	nf.md_circle_slice_8,
}
local ICON_PROGRESS_ERROR = nf.md_close_circle or ""
local ICON_PROGRESS_BUSY = nf.md_dots_circle or ""

-- ペインが報告した進捗（winget / pacman / yazi 等が OSC 9;4 で送る）から
-- 「表示テキスト + 色」を返す ※pane.progress は nightly 限定フィールド。
-- フィールドが無いバージョンや未報告 ("None") のときは nil を返して何も描かない
local function progress_cell(pane)
	local pr = pane and pane.progress
	if not pr or pr == "None" then
		return nil
	end
	if pr == "Indeterminate" then
		return ICON_PROGRESS_BUSY, palette.accent2
	end
	if type(pr) == "table" then
		if pr.Percentage then
			local pct = math.min(100, math.max(0, pr.Percentage))
			local slice = PROGRESS_SLICES[math.min(8, math.max(1, math.ceil(pct / 12.5)))] or ""
			return string.format("%s %d%%", slice, pct), palette.ok
		end
		if pr.Error then
			return string.format("%s %d%%", ICON_PROGRESS_ERROR, pr.Error), palette.ansi[2]
		end
	end
	return nil
end

-- ホスト名を比較用にそろえる（小文字化し、最初の "." より後のドメイン部を落とす）
local function short_host(host)
	return ((host or ""):lower():match("^[^.]*"))
end

local LOCAL_HOST = short_host(wezterm.hostname())

-- ペインが OSC 7 で報告したカレントディレクトリを短い表示名にする。
-- 例: "C:/Users/foo/dev/myapp" -> "myapp"、ホームそのものなら "~"。
-- 報告元が別のホスト（ssh 先のシェルが OSC 7 を送っている）なら "myhost:myapp" のように
-- ホスト名を付け、2 つ目の戻り値で true を返す。
-- 報告が無いシェル（シェル統合を入れていない / WSL など）では nil を返し、
-- 呼び出し側が従来どおりペインのタイトルへフォールバックする
local function cwd_label(pane)
	local cwd = pane and pane.current_working_dir
	if not cwd then
		return nil
	end
	-- current_working_dir は Url オブジェクト。file_path が OS ネイティブ形式のパス
	local path = cwd.file_path
	if not path or path == "" then
		return nil
	end
	-- シェル統合はホスト名を file://<ホスト>/... に載せて送る。空・localhost・自分の
	-- ホスト名（wezterm.hostname()）ならローカル
	local host = short_host(cwd.host)
	local remote = host ~= "" and host ~= "localhost" and host ~= LOCAL_HOST
	-- 末尾の区切りを落としてから比較・切り出しする（Windows は \ と / が混在しうる）
	path = (path:gsub("[/\\]$", ""))
	-- Windows のパスは URL の形のまま "/C:/Users/foo" と先頭に / が付いてくるので外す
	-- （外さないとホーム（USERPROFILE）と一致せず "~" にならない）
	path = (path:gsub("^/(%a:)", "%1"))
	local dir
	if not remote then
		local home = os.getenv("USERPROFILE") or os.getenv("HOME")
		if home then
			local function norm(v)
				return (v:gsub("\\", "/"):gsub("/$", "")):lower()
			end
			if norm(path) == norm(home) then
				dir = "~"
			end
		end
	end
	dir = dir or path:match("([^/\\]+)$") or "/" -- 区切りを落として空になるのはルート
	if remote then
		return host .. ":" .. dir, true
	end
	return dir, false
end

-- ペインで今動いているプログラムの名前（lua/procs.lua の running。例: "pwsh" / "ssh"）。
-- Git Bash の中で動くプログラムは WezTerm から見えないので、シェル統合が送る
-- ユーザー変数 WEZTERM_PROG（実行中のコマンド行）で補う。取れなければ ""
local function program_name(pane)
	local vars = pane and pane.user_vars
	return procs.running(pane and pane.foreground_process_name, vars and vars.WEZTERM_PROG)
end

-- プログラム名からアイコンを決定する。例: "pwsh" → PowerShell アイコン（未知・"" は汎用）
local function process_icon(name)
	return PROCESS_ICONS[name] or GENERIC_ICON
end

-- 明示的なタブ名が無いときのタイトル。上から順に採用する（name は program_name の結果）
--   1) ssh 先のシェルが OSC 7 を送っている → 「ホスト:ディレクトリ」
--   2) ssh 等の実行中 → ペインタイトル（多くの Linux の既定 bashrc が "user@host:dir" を
--      設定する。"user@" は省く）。このとき OSC 7 の値は接続前のローカルのディレクトリの
--      ままなので使わない
--   3) ローカルのカレントディレクトリ名（シェル統合が OSC 7 を送っている場合）
--   4) ペインのタイトル
local function auto_title(pane, name)
	local label, remote = cwd_label(pane)
	if remote then
		return label
	end
	if procs.REMOTE[name] then
		-- 先頭、または空白の後ろの "user@" を省く（コピーモード中は "Copy mode: user@host:dir"）
		local title = ((pane.title or ""):gsub("^[^@%s]+@", ""):gsub("(%s)[^@%s]+@", "%1"))
		if title ~= "" then
			return title
		end
	end
	return label or pane.title or ""
end

function M.apply(config)
	-- ファンシータブバー: タイトルフォント行高の約1.75倍の高さになり、
	-- タブの上下に余白が生まれる（レトロタブバーは1セル固定で調整不可）
	config.use_fancy_tab_bar = true
	config.tab_bar_at_bottom = false
	config.hide_tab_bar_if_only_one_tab = false
	config.tab_max_width = 40
	config.show_new_tab_button_in_tab_bar = true
	-- タブ内の×ボタンを消してピルの見た目を保つ（閉じるのは Ctrl+Shift+W）※nightly 限定
	config.show_close_tab_button_in_tabs = false

	-- タブバーのフォントと背景
	-- ※ フォント指定は必須: デフォルトの Roboto は Nerd Font / Powerline / 日本語
	--   グリフを持たないため、ピルの丸キャップやアイコンが豆腐になる
	-- ※ 背景は不透明のまま（window.lua の可読性方針と #5348 の回避策を維持）
	config.window_frame = {
		font = wezterm.font_with_fallback(ui.font_family),
		font_size = 11.0, -- 本文(12)より少し小さめ。タブバーの高さもこれで決まる
		active_titlebar_bg = palette.tab_bar_bg,
		inactive_titlebar_bg = palette.tab_bar_bg,
	}

	-- アクティブなタブだけを暗い面のピルにし、番号とアイコンを青で示す。
	-- 非アクティブなタブは面を付けず、色も指定しない（colors.lua の inactive_tab /
	-- inactive_tab_hover の灰色 / 白になる）。
	-- ※ 引数の hover は使わない。レトロタブバーの桁で判定されるため、ファンシータブバーでは
	--   マウスの位置とずれる。ホバーは inactive_tab_hover に任せる（WezTerm がピクセル単位で判定する）
	-- ※ タブバーは 1 つのフォントで描かれ、太字（Intensity）などの属性は効かない
	wezterm.on("format-tab-title", function(tab, tabs, panes, conf, hover, max_width)
		local name = program_name(tab.active_pane)
		local icon = process_icon(name)
		-- タイトルは明示的に付けたタブ名 (Ctrl+Shift+Alt+T) を最優先し、
		-- 無ければ auto_title（接続先 / カレントディレクトリ / ペインタイトル）
		local title = tab.tab_title
		if not title or #title == 0 then
			title = auto_title(tab.active_pane, name)
		end
		-- ズーム中のペインは虫眼鏡を表示
		local zoom = tab.active_pane.is_zoomed and (" " .. ZOOM_ICON) or ""
		-- WezTerm はファンシータブバーのタイトルを tab_max_width で切り詰めない
		-- （上限はウィンドウ幅をタブの数で割った幅だけ）ので、ここで切り詰める
		title = wezterm.truncate_right(title, 24)
		local head = string.format(" %d %s  ", tab.tab_index + 1, icon) -- 番号 + プロセスアイコン
		local body = title .. zoom .. " "

		local elements
		if tab.is_active then
			elements = {
				-- 左の丸キャップ
				{ Background = { Color = palette.tab_bar_bg } },
				{ Foreground = { Color = palette.surface } },
				{ Text = LEFT_CAP },
				-- 本体（番号とアイコンは青、タイトルは白）
				{ Background = { Color = palette.surface } },
				{ Foreground = { Color = palette.accent } },
				{ Text = head },
				{ Foreground = { Color = palette.fg } },
				{ Text = body },
			}
		else
			-- 丸キャップの代わりに空白を置き、アクティブと同じ幅にする（切り替えても並びがずれない）。
			-- 最初のセルに色が無いので、タブの箱と文字が inactive_tab(_hover) の色になる
			elements = {
				{ Text = " " .. head .. body },
			}
		end

		-- 実行中コマンドの進捗（報告があるときだけ本体の右側に差し込む）
		local ptext, pcolor = progress_cell(tab.active_pane)
		if ptext then
			table.insert(elements, { Foreground = { Color = pcolor } })
			table.insert(elements, { Text = ptext .. " " })
		elseif not tab.is_active and tab.active_pane.has_unseen_output then
			-- 進捗を報告しないコマンド（ビルド・テスト等）でも、見ていない間に出力が
			-- あればドットで知らせる。そのタブに切り替えると自動的に消える
			table.insert(elements, { Foreground = { Color = palette.warn } })
			table.insert(elements, { Text = UNSEEN_ICON .. " " })
		end

		-- 右の丸キャップ（非アクティブは空白）
		if tab.is_active then
			table.insert(elements, { Background = { Color = palette.tab_bar_bg } })
			table.insert(elements, { Foreground = { Color = palette.surface } })
			table.insert(elements, { Text = RIGHT_CAP })
		else
			table.insert(elements, { Text = " " })
		end

		return elements
	end)
end

return M
