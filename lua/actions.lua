-- キーバインド (bindings.lua) とコマンドパレット (palette.lua) の両方から使う
-- アクションの定義（apply は持たないデータモジュール）。
-- 入口が 2 つあるものはここに置き、挙動を 1 か所で管理する
local wezterm = require("wezterm")
local statusbar = require("statusbar")
local procs = require("procs")
local M = {}

local act = wezterm.action
local nf = wezterm.nerdfonts

-- タブ名を変更: 現在の名前を初期値にして編集する（空欄で確定するとデフォルト名に戻る）。
-- prompt / initial_value は nightly 限定のため、押した時点のタブ名を
-- 初期値に入れられるようコールバック内でアクションを組み立てる
M.rename_tab = wezterm.action_callback(function(window, pane)
	window:perform_action(
		act.PromptInputLine({
			description = "タブ名を入力（空欄で確定するとデフォルト名に戻る）",
			prompt = (nf.md_pencil or ">") .. " ",
			initial_value = window:active_tab():get_title(),
			action = wezterm.action_callback(function(win, _, line)
				-- Esc でキャンセルすると line は nil
				if line then
					win:active_tab():set_title(line)
				end
			end),
		}),
		pane
	)
end)

-- ワークスペースを作成 / 既存へ移動: 名前を入力する
M.new_workspace = act.PromptInputLine({
	description = "ワークスペース名を入力（既存の名前ならそこへ移動）",
	prompt = (nf.cod_window or ">") .. " ",
	action = wezterm.action_callback(function(win, pane, line)
		if line and line ~= "" then
			win:perform_action(act.SwitchToWorkspace({ name = line }), pane)
		end
	end),
})

-- 今のワークスペースの名前を変える。現在の名前を初期値にする。
-- ※ 既にある名前へ変えると 2 つのワークスペースが 1 つに合流してしまうので断る
M.rename_workspace = wezterm.action_callback(function(window, pane)
	local current = window:active_workspace()
	window:perform_action(
		act.PromptInputLine({
			description = "ワークスペースの新しい名前を入力",
			prompt = (nf.cod_window or ">") .. " ",
			initial_value = current,
			action = wezterm.action_callback(function(win, _, line)
				if not line or line == "" or line == current then
					return
				end
				for _, name in ipairs(wezterm.mux.get_workspace_names()) do
					if name == line then
						statusbar.flash(win, "「" .. line .. "」は既にあります", "warn")
						return
					end
				end
				wezterm.mux.rename_workspace(current, line)
			end),
		}),
		pane
	)
end)

-- ssh 等（フォアグラウンドにいる間、画面の中身が別のマシンになるプロセス）の実行中か。
-- フォアグラウンドのプロセスで見る。Git Bash の中で起動した ssh は WezTerm から見えないので、
-- シェル統合が送る WEZTERM_PROG（実行中のコマンド行）で補う（lua/procs.lua）
local function in_remote_session(pane)
	local vars = pane:get_user_vars() or {}
	return procs.REMOTE[procs.running(pane:get_foreground_process_name(), vars.WEZTERM_PROG)] == true
end

-- 直前に実行したコマンドの出力を探す。
-- シェル統合 (shell/) が OSC 133 で画面を「プロンプト / 入力 / 出力」の範囲に区切るので、
-- 最後に Enter で確定した「入力」範囲の直後の「出力」範囲を取る。
-- 戻り値: 出力のテキスト（無ければ nil）, 無い理由
--   "empty"  直前のコマンドは何も出力しなかった（cd など）/ 実行中でまだ出力が無い
--   "nocmd"  シェル統合は動いているが、画面に実行したコマンドが無い
--            （開いた直後・clear・Ctrl+Shift+Alt+K の後）
--   "none"   区切りが見つからない（シェル統合が無い）
--   "remote" ssh 中で、ssh 先のシェルが区切りを送っていない
local function find_last_output(pane)
	local function text_of(z)
		return pane:get_text_from_semantic_zone(z)
	end
	-- 空白だけの「出力」範囲は画面の余白（clear の後などに残る）なので数えない
	local zones = {}
	for _, z in ipairs(pane:get_semantic_zones()) do
		if not (z.semantic_type == "Output" and not text_of(z):find("%S")) then
			table.insert(zones, z)
		end
	end

	-- 最後に確定した入力範囲を探す。末尾の入力範囲がカーソルと同じ行（以前）にあるなら、
	-- まだ Enter を押していない入力途中の文字なので飛ばす
	local cursor = pane:get_cursor_position()
	local k
	for i = #zones, 1, -1 do
		if zones[i].semantic_type == "Input" then
			local typing = i == #zones and cursor.y <= zones[i].end_y
			if not typing then
				k = i
				break
			end
		end
	end
	if not k then
		-- プロンプトや入力の範囲（入力途中のものも含む）があれば、シェル統合は動いている
		for _, z in ipairs(zones) do
			if z.semantic_type ~= "Output" then
				return nil, "nocmd"
			end
		end
		-- 起動メニューから直接 ssh を開いた場合も、手元のシェルが無いのでここに来る
		return nil, in_remote_session(pane) and "remote" or "none"
	end

	-- その入力の後ろ、次のプロンプトまでが出力
	local parts, prompt_after = {}, false
	for i = k + 1, #zones do
		local t = zones[i].semantic_type
		if t ~= "Output" then
			prompt_after = true
			break
		end
		table.insert(parts, text_of(zones[i]))
	end

	-- 入力の後ろにプロンプトが一度も来ていない = そのコマンドはまだ実行中。それが ssh / mosh なら
	-- ssh 先のシェルが区切りを送っていないので、出力範囲は ssh のセッション全体。丸ごとは返さない
	-- ssh 中かどうかは次のどちらかで見る
	--   コマンド行  cd dir && ssh host なども拾う（lua/procs.lua の main_program）。
	--               Git Bash から起動した ssh はプロセスが見えないので、こちらが頼り
	--   プロセス    エイリアスやスクリプトから起動した ssh も拾う（Linux・PowerShell など）
	if not prompt_after and (procs.REMOTE[procs.main_program(text_of(zones[k]))] or in_remote_session(pane)) then
		return nil, "remote"
	end

	-- 出力の後ろに付く空行・空白は落とす
	local text = (table.concat(parts, "\n"):gsub("%s+$", ""))
	if text == "" then
		return nil, "empty"
	end
	return text
end

-- ※ 狭いウィンドウでもステータスバーに収まるよう短くする（詳しい説明は docs/troubleshooting.md の
--   トラブルシューティング）
local NO_OUTPUT_MESSAGES = {
	empty = "直前の出力は空です",
	nocmd = "コピーできる出力がありません",
	none = "コピーできません（要シェル統合）",
	remote = "ssh 先の出力は区切れません",
}

-- 直前のコマンドの出力だけをクリップボードへコピーする（Ctrl+Shift+Alt+C）
M.copy_last_output = wezterm.action_callback(function(window, pane)
	local text, reason = find_last_output(pane)
	if not text then
		statusbar.flash(window, NO_OUTPUT_MESSAGES[reason], "warn")
		return
	end
	window:copy_to_clipboard(text, "Clipboard")
	local _, newlines = text:gsub("\n", "")
	statusbar.flash(window, string.format("出力 %d 行をコピー", newlines + 1), "ok")
end)

-- スクロールバック全体をテキストファイルに書き出し、OS 既定のテキストエディタで開く。
-- 長いログの検索・保存用。書き出し先は一時ディレクトリの固定名なので、
-- 何度使ってもファイルは 1 つだけ（前回の内容は上書き）。
-- ※ os.tmpname() は Windows でドライブ直下のパスを返し書き込めないことがあるので使わない
local SEP = package.config:sub(1, 1)

local function scrollback_path()
	local dir = os.getenv("TEMP") or os.getenv("TMP") or os.getenv("TMPDIR") or "/tmp"
	return (dir:gsub("[/\\]$", "")) .. SEP .. "wezterm-scrollback.txt"
end

M.open_scrollback = wezterm.action_callback(function(window, pane)
	-- 折り返された行は 1 行に戻して取り出す（エディタ側で折り返せるように）
	local rows = pane:get_dimensions().scrollback_rows
	local text = (pane:get_logical_lines_as_text(rows):gsub("%s+$", ""))
	local path = scrollback_path()
	local f, err = io.open(path, "w")
	if not f then
		statusbar.flash(window, "書き出しに失敗: " .. tostring(err), "warn")
		return
	end
	f:write(text, "\n")
	f:close()
	wezterm.open_with(path)
	local _, newlines = text:gsub("\n", "")
	statusbar.flash(window, string.format("%d 行をエディタで開きます", newlines + 1), "ok")
end)

-- 画面上の URL にラベルを付け、選んだものをブラウザで開く（QuickSelect の変種）。
-- 末尾の句読点・閉じ括弧・日本語を URL に含めないよう、使える文字を ASCII に限り、
-- 最後の 1 文字は . , : ; ? ! 以外にする。
-- ※ パターンに ]] を含むため、レベル 2 の長括弧 [==[ ]==] で書く
local URL_PATTERN = [==[https?://[A-Za-z0-9_\-.~:/?#@!$&*+,;=%]*[A-Za-z0-9_\-~/#@$&*+=%]]==]

M.open_url = act.QuickSelectArgs({
	label = "URL を開く",
	patterns = { URL_PATTERN },
	action = wezterm.action_callback(function(window, pane)
		local url = window:get_selection_text_for_pane(pane)
		window:perform_action(act.ClearSelection, pane)
		if url and url ~= "" then
			wezterm.open_with(url)
		end
	end),
})

-- 今のペインを分割から外して、新しいタブ / 新しいウィンドウへ移す
M.move_pane_to_new_tab = wezterm.action_callback(function(_, pane)
	local tab = pane:move_to_new_tab()
	tab:activate()
end)

M.move_pane_to_new_window = wezterm.action_callback(function(_, pane)
	pane:move_to_new_window()
end)

-- この設定のフォルダをファイルマネージャで開く
M.open_config_dir = wezterm.action_callback(function()
	wezterm.open_with(wezterm.config_dir)
end)

return M
