# WezTerm シェル統合 (PowerShell 7 / Windows PowerShell)
#
#   OSC 7   カレントディレクトリを端末に通知する。
#           → 新しいタブ・分割ペインが「今いるディレクトリ」で開く
#           → タブ名がディレクトリ名になる (lua/tabs.lua の cwd_label)
#   OSC 133 プロンプトの位置を端末に通知する。
#           → Ctrl+Shift+Alt+↑/↓ で前後のプロンプトへジャンプできる
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

function global:prompt {
	# $? は prompt の最初の文で取らないと、後続の処理で上書きされてしまう
	$ok = $?
	$code = if ($ok) { 0 } elseif ($null -ne $global:LASTEXITCODE) { $global:LASTEXITCODE } else { 1 }

	$esc = [char]27
	$st = "$esc\"  # 文字列終端 (ST)。ESC + バックスラッシュ
	$out = "$esc]133;D;$code$st"

	# OSC 7: ファイルシステム以外のプロバイダ（レジストリ等）では送らない
	if ($PWD.Provider.Name -eq 'FileSystem') {
		$p = $PWD.ProviderPath.Replace('\', '/')
		# file:// URL に載せるため最低限のパーセントエンコードを行う
		# （% を先に処理しないと後続の置換結果まで壊れる）
		$p = $p.Replace('%', '%25').Replace(' ', '%20')
		# "C:/..." には先頭の / が無いので補う（file://host/C:/... が Windows の標準形）
		if (-not $p.StartsWith('/')) { $p = "/$p" }
		$hostname = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { 'localhost' }
		$out += "$esc]7;file://$hostname$p$st"
	}

	# プロンプト開始 (A)
	$out += "$esc]133;A$st"
	# PSReadLine がプロンプト幅を誤らないよう、通知は戻り値に混ぜず直接書き出す
	[Console]::Write($out)

	# 元の prompt の出力に、入力開始 (B) の通知を付けて返す
	$text = & $global:__WezTermOriginalPrompt
	return "$text$esc]133;B$st"
}
