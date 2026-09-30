# WezTerm シェル統合 (PowerShell 7 / Windows PowerShell)
#
#   OSC 7   カレントディレクトリを端末に通知する。
#           → 新しいタブ・分割ペインが「今いるディレクトリ」で開く
#           → タブ名がディレクトリ名になる (lua/tabs.lua の cwd_label)
#   OSC 133 プロンプトと出力の位置を端末に通知する。
#           → Ctrl+Shift+Alt+↑/↓ で前後のプロンプトへジャンプできる
#           → Ctrl+Shift+Alt+C で直前のコマンドの出力をコピーできる
#   OSC 1337 SetUserVar
#           長いコマンドが終わったことを端末に通知する。
#           → 見ていないペインなら完了をトースト通知 (lua/notify.lua)
#
# lua/shells.lua が PowerShell を起動するときに -Command で自動的に
# ドットソースするため、プロファイルへの追記は不要。

# WezTerm 以外の端末で読み込まれても無害なように何もせず抜ける
if ($env:TERM_PROGRAM -ne 'WezTerm') { return }

# 二重ロード防止（プロンプト関数を何重にもラップしないため）
if ($global:__WezTermIntegrationLoaded) { return }
$global:__WezTermIntegrationLoaded = $true

# 既存の prompt 関数（ユーザープロファイルや oh-my-posh が定義したもの）を保存して
# ラップする。中身は書き換えず、前後に通知を足すだけにする
$global:__WezTermOriginalPrompt = $function:prompt

# 完了通知を送った履歴の Id（同じコマンドで二度通知しないため）
$__wz_h = Get-History -Count 1
$global:__WezTermNotifiedId = if ($__wz_h) { $__wz_h.Id } else { 0 }

# OSC 7 に載せるホスト名。WezTerm 側 (wezterm.hostname()) と同じ DNS ホスト名にそろえる。
# lua/tabs.lua はこれが自分のホスト名と違うと ssh 先とみなして「ホスト:ディレクトリ」表示に
# するため。$env:COMPUTERNAME は NetBIOS 名で 15 文字に切り詰められ、一致しないことがある
$global:__WezTermHostName = [System.Net.Dns]::GetHostName()
if (-not $global:__WezTermHostName) { $global:__WezTermHostName = 'localhost' }

function global:prompt {
	# $? は prompt の最初の文で取らないと、後続の処理で上書きされてしまう
	$ok = $?
	$code = if ($ok) { 0 } elseif ($null -ne $global:LASTEXITCODE) { $global:LASTEXITCODE } else { 1 }

	$esc = [char]27
	$st = "$esc\"  # 文字列終端 (ST)。ESC + バックスラッシュ
	$out = "$esc]133;D;$code$st"

	# 長いコマンドの完了通知。WEZTERM_NOTIFY_AFTER 秒（既定 10）以上かかったコマンドなら
	# 「終了コード<TAB>経過秒<TAB>コマンド」をユーザー変数 wezterm_cmd_done で送る。
	# 出すかどうか（見ていないペインのときだけ）は lua/notify.lua が決める。
	# 空 Enter では履歴が増えないので、通知済みの Id と比べて二度送らない
	$last = Get-History -Count 1
	if ($last -and $last.Id -ne $global:__WezTermNotifiedId) {
		$global:__WezTermNotifiedId = $last.Id
		$threshold = 10
		if ($env:WEZTERM_NOTIFY_AFTER -match '^\d+$') { $threshold = [int]$env:WEZTERM_NOTIFY_AFTER }
		$elapsed = [int][math]::Floor(($last.EndExecutionTime - $last.StartExecutionTime).TotalSeconds)
		if ($elapsed -ge $threshold) {
			# SetUserVar の値は base64 で送る決まり（WezTerm 側で復号される）
			$value = "$code`t$elapsed`t$($last.CommandLine)"
			$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($value))
			$out += "$esc]1337;SetUserVar=wezterm_cmd_done=$b64$st"
		}
	}

	# OSC 7: ファイルシステム以外のプロバイダ（レジストリ等）では送らない
	if ($PWD.Provider.Name -eq 'FileSystem') {
		$p = $PWD.ProviderPath.Replace('\', '/')
		# file:// URL に載せるため最低限のパーセントエンコードを行う
		# （% を先に処理しないと後続の置換結果まで壊れる）
		$p = $p.Replace('%', '%25').Replace(' ', '%20')
		# "C:/..." には先頭の / が無いので補う（file://host/C:/... が Windows の標準形）
		if (-not $p.StartsWith('/')) { $p = "/$p" }
		$out += "$esc]7;file://$global:__WezTermHostName$p$st"
	}

	# プロンプト開始 (A)
	$out += "$esc]133;A$st"
	# PSReadLine がプロンプト幅を誤らないよう、通知は戻り値に混ぜず直接書き出す
	[Console]::Write($out)

	# 元の prompt の出力に、入力開始 (B) の通知を付けて返す
	$text = & $global:__WezTermOriginalPrompt
	return "$text$esc]133;B$st"
}

# 出力の開始位置 (133;C) を送る。これで「直前の出力をコピー」(Ctrl+Shift+Alt+C) が
# PowerShell でも出力の範囲を取れる。
# Enter で確定した直後・コマンドの実行前に呼ばれる PSConsoleHostReadLine（PSReadLine が
# 定義する入力読み取り関数）をラップする（VS Code のシェル統合と同じ手法）。
# PSReadLine が読み込まれていない環境では関数が無いので何もしない
if (Test-Path Function:\PSConsoleHostReadLine) {
	$global:__WezTermOriginalReadLine = $function:PSConsoleHostReadLine

	function global:PSConsoleHostReadLine {
		$line = & $global:__WezTermOriginalReadLine
		# 空 Enter はコマンドを実行しないので送らない（空の出力範囲を作らない）
		if ($line -and $line.Trim()) {
			[Console]::Write("$([char]27)]133;C$([char]27)\")
		}
		$line
	}
}
