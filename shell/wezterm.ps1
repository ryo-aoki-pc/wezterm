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

# プロンプトを出した時点の $Error の先頭。次の行で新しいエラーが記録されたかを、
# これと同じオブジェクトかどうかで見分ける（終了コードの判定に使う）
$global:__WezTermLastError = if ($global:Error.Count -gt 0) { $global:Error[0] }

# OSC 7 に載せるホスト名。WezTerm 側 (wezterm.hostname()) と同じ DNS ホスト名にそろえる。
# lua/tabs.lua はこれが自分のホスト名と違うと ssh 先とみなして「ホスト:ディレクトリ」表示に
# するため。$env:COMPUTERNAME は NetBIOS 名で 15 文字に切り詰められ、一致しないことがある
$global:__WezTermHostName = [System.Net.Dns]::GetHostName()
if (-not $global:__WezTermHostName) { $global:__WezTermHostName = 'localhost' }

function global:prompt {
	# $? は prompt の最初の文で取らないと、後続の処理で上書きされてしまう
	$ok = $?
	# プロファイルで Set-StrictMode を有効にしていても落ちないよう、この関数（と中から呼ぶ
	# 元の prompt）の中だけ切る。空の $Error の [0] や、ネイティブコマンドを一度も動かして
	# いないときの $LASTEXITCODE（未定義）を読むと例外になり、プロンプトが「PS>」に化けるため
	Set-StrictMode -Off
	# 直前に実行した行（空 Enter では増えない）。完了通知で使う
	$last = Get-History -Count 1

	# 終了コード（Windows Terminal のシェル統合と同じ考え方）。$? は成否しか持たず、
	# $LASTEXITCODE はネイティブコマンド（git など）が動いたときしか更新されない
	# （コマンドレットが失敗しても前の値が残る）ので、この行で記録されたエラーで見分ける
	#   成功                                        → 0
	#   この行の PowerShell のエラー（コマンドレット・throw） → 1
	#   この行のネイティブコマンドのエラー          → $LASTEXITCODE（0 もそのまま）
	#     ※ Windows PowerShell は stderr を 2>&1 などで受けると、終了コード 0 でも $? が
	#       偽になり NativeCommandError が記録される。PowerShell 7.3 以降の
	#       $PSNativeCommandUseErrorActionPreference による失敗は NativeCommandExitException
	#   この行のエラーが無い（ネイティブコマンドの失敗） → $LASTEXITCODE（0 や未設定なら 1）
	# 「この行のエラーか」は、前のプロンプトのときの $Error の先頭と別物かで見る
	# （エラーの InvocationInfo.HistoryId は Windows PowerShell のネイティブコマンドでは -1 で使えない。
	#   $Error の件数も上限 256 件に達すると増えないので使えない）
	$code = 0
	if (-not $ok) {
		$code = 1
		$err = if ($global:Error.Count -gt 0) { $global:Error[0] }
		if ($err -and -not [object]::ReferenceEquals($err, $global:__WezTermLastError)) {
			# 型は名前で比べる（Windows PowerShell にはこの型が無く、[型] と書くとその場でエラーになる）
			if ($err -is [System.Management.Automation.ErrorRecord] -and (
					$err.FullyQualifiedErrorId -like 'NativeCommandError*' -or
					$err.Exception.GetType().FullName -eq 'System.Management.Automation.NativeCommandExitException')) {
				$code = [int]$global:LASTEXITCODE
			}
		} elseif ($global:LASTEXITCODE) {
			$code = $global:LASTEXITCODE
		}
	}

	$esc = [char]27
	$st = "$esc\"  # 文字列終端 (ST)。ESC + バックスラッシュ
	$out = "$esc]133;D;$code$st"

	# 長いコマンドの完了通知。WEZTERM_NOTIFY_AFTER 秒（既定 10）以上かかったコマンドなら
	# 「終了コード<TAB>経過秒<TAB>コマンド」をユーザー変数 wezterm_cmd_done で送る。
	# 出すかどうか（見ていないペインのときだけ）は lua/notify.lua が決める。
	# 空 Enter では履歴が増えないので、通知済みの Id と比べて二度送らない
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
		# file:// URL に載せるため、英数字と - _ . ~ 以外を UTF-8 のパーセントエンコードにする
		#   - # と ? をそのまま送ると、WezTerm がそこから後ろを捨てる（パスが変わり、タブ名がずれて、
		#     新しいタブがホームで開く）
		#   - ASCII 以外の文字は、[Console]::Write がコンソールのコード ページ（日本語版 Windows は
		#     932）で書き出すため、そこに無い文字（é・ハングル・絵文字など）が化ける
		# EscapeDataString は / と : もエンコードするので、この 2 つは戻す（C: はドライブ名として
		# 読まれるよう、そのまま送る必要がある）
		$p = [Uri]::EscapeDataString($PWD.ProviderPath.Replace('\', '/')).Replace('%2F', '/').Replace('%3A', ':')
		# "C:/..." には先頭の / が無いので補う（file://host/C:/... が Windows の標準形）
		if (-not $p.StartsWith('/')) { $p = "/$p" }
		$out += "$esc]7;file://$global:__WezTermHostName$p$st"
	}

	# プロンプト開始 (A)
	$out += "$esc]133;A$st"
	# PSReadLine がプロンプト幅を誤らないよう、通知は戻り値に混ぜず直接書き出す
	[Console]::Write($out)

	# 元の prompt の出力に、入力開始 (B) の通知を付けて返す。
	# 元の prompt が $? で直前の失敗を表示できるよう（oh-my-posh・starship など）、失敗だったときは
	# $? を偽に戻してから呼ぶ（ここまでの処理で真になっている）。-ErrorAction Ignore のエラーは
	# $Error に残らない（VS Code のシェル統合と同じ方法）
	if (-not $ok) { Write-Error -Message 'wezterm' -ErrorAction Ignore }
	$text = & $global:__WezTermOriginalPrompt
	# 次の行で新しいエラーが出たかを見分ける印（元の prompt が出したエラーもここで含めておく）
	$global:__WezTermLastError = if ($global:Error.Count -gt 0) { $global:Error[0] }
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
