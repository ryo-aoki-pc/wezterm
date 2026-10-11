param([string]$ResultPath)

# -NoProfile の別プロセスで実行する。クリップボードとユーザープロファイルは変更しない。
# 実 PSReadLine の割り当てと、再現入力による入力待機マーカー・既存の C 印を検査する。
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$integration = Join-Path $root 'shell/wezterm.ps1'
$script:checks = @()
$esc = [char]27
$active = "$esc]1337;SetUserVar=WEZTERM_PSREADLINE_PASTE=MQ==$esc\"
$inactive = "$esc]1337;SetUserVar=WEZTERM_PSREADLINE_PASTE=$esc\"
$commandStart = "$esc]133;C$esc\"

function Check([string]$Name, [bool]$Pass) {
	$script:checks += [pscustomobject]@{ Name = $Name; Pass = $Pass }
}

function Import-TestPSReadLine {
	if ($PSVersionTable.PSVersion.Major -eq 5) {
		# 親 pwsh の PSModulePath を継承しても Windows 標準の 2.0.0 を使う。
		Import-Module (Join-Path ${env:ProgramFiles} 'WindowsPowerShell/Modules/PSReadLine/2.0.0/PSReadLine.psd1')
	} else { Import-Module PSReadLine }
	Set-PSReadLineOption -EditMode Emacs
}

function Paste-IsBound {
	# -Chord による絞り込みは PSReadLine 2.0.0 には無い。
	return @((Get-PSReadLineKeyHandler -Bound) | Where-Object { $_.Key -eq 'Ctrl+v' -and $_.Function -eq 'Paste' }).Count -eq 1
}

function Reset-TestFunctions {
	function global:prompt { 'paste-test> ' }
	$global:__PasteTestCalls = 0
	$global:__PasteTestInput = 'Write-Output paste-test'
	$global:__PasteTestThrow = $false
	$global:__PasteTestObservedOsc = ''
	function global:PSConsoleHostReadLine {
		$global:__PasteTestCalls++
		$global:__PasteTestObservedOsc = $global:__PasteTestWriter.ToString()
		if ($global:__PasteTestThrow) { throw 'paste-test readline failure' }
		$global:__PasteTestInput
	}
}

function Capture-ReadLine {
	param([string]$InitialOsc = '')
	$global:__PasteTestWriter = New-Object IO.StringWriter
	$originalWriter = [Console]::Out
	$value = $null
	$errorMessage = $null
	try {
		[Console]::SetOut($global:__PasteTestWriter)
		[Console]::Write($InitialOsc)
		$value = PSConsoleHostReadLine
	} catch { $errorMessage = $_.Exception.Message }
	finally { [Console]::SetOut($originalWriter) }
	$result = [pscustomobject]@{
		Value = $value
		Osc = $global:__PasteTestWriter.ToString()
		ObservedOsc = $global:__PasteTestObservedOsc
		ErrorMessage = $errorMessage
	}
	$global:__PasteTestWriter.Dispose()
	return $result
}

$bytes = [IO.File]::ReadAllBytes($integration)
Check 'Windows PowerShell 用 UTF-8 BOM を維持する' ($bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191)
$parseTokens = $null
$parseErrors = $null
$null = [Management.Automation.Language.Parser]::ParseFile($integration, [ref]$parseTokens, [ref]$parseErrors)
Check 'シェル統合の構文' ($parseErrors.Count -eq 0)

Import-TestPSReadLine
$readlineVersion = (Get-Module PSReadLine).Version.ToString()
Reset-TestFunctions
$beforePrompt = $function:prompt
$beforeReadLine = $function:PSConsoleHostReadLine
$env:TERM_PROGRAM = 'OtherTerminal'
. $integration
Check '非 WezTerm では関数を変更しない' ([object]::ReferenceEquals($function:prompt, $beforePrompt) -and [object]::ReferenceEquals($function:PSConsoleHostReadLine, $beforeReadLine))
Check '非 WezTerm では Ctrl+v を登録しない' (-not (Paste-IsBound))

$env:TERM_PROGRAM = 'WezTerm'
. $integration
Check 'Emacs モードで Ctrl+v に Paste を登録する' (Paste-IsBound)
$wrappedPrompt = $function:prompt
$wrappedReadLine = $function:PSConsoleHostReadLine
. $integration
. $integration
Check '再読み込みでラッパーを重ねない' ([object]::ReferenceEquals($function:prompt, $wrappedPrompt) -and [object]::ReferenceEquals($function:PSConsoleHostReadLine, $wrappedReadLine))
foreach ($line in @('', ' ', "`t", 'Write-Output paste-test', "line1`n`n日本語", "line1`r`nline2")) {
	$global:__PasteTestInput = $line
	$beforeCalls = $global:__PasteTestCalls
	$captured = Capture-ReadLine
	$expected = $active + $inactive
	if ($line.Trim()) { $expected += $commandStart }
	Check "入力待機中だけマーカーを送り C 印と戻り値を維持 [$line]" (
		$captured.Value -ceq $line -and $captured.Osc -ceq $expected -and
		$captured.ObservedOsc -ceq $active -and -not $captured.ErrorMessage -and
		$global:__PasteTestCalls -eq $beforeCalls + 1)
}

Set-PSReadLineOption -EditMode Emacs
Check 'EditMode 再設定で割り当てが消えるケースを再現する' (-not (Paste-IsBound))
$captured = Capture-ReadLine
Check '次の入力待機で Ctrl+v を再登録する' ((Paste-IsBound) -and $captured.ObservedOsc -ceq $active)
Set-PSReadLineOption -EditMode Emacs
. $integration
Check '既存ラッパーが残る再読み込みでも Ctrl+v を再登録する' (Paste-IsBound)

# キー登録が例外になる場合、入力と C 印は維持して通常貼り付けへ戻す。
function global:Set-PSReadLineKeyHandler {
	param($Chord, $Function, $ErrorAction)
	throw 'paste-test key registration failure'
}
try {
	. $integration
	$global:__PasteTestInput = 'failure-fallback'
	$captured = Capture-ReadLine -InitialOsc $active
	Check 'キー登録失敗では古い有効マーカーを読取前に解除して入力を維持する' (
		$captured.Value -ceq 'failure-fallback' -and $captured.Osc -ceq ($active + $inactive + $inactive + $commandStart) -and
		$captured.ObservedOsc -ceq ($active + $inactive) -and -not $captured.ErrorMessage)
} finally { Remove-Item Function:\Set-PSReadLineKeyHandler }

# 元の入力関数が例外になっても解除を送り、例外をそのまま呼び出し側へ返す。
$global:__PasteTestThrow = $true
$captured = Capture-ReadLine
Check '入力関数の例外でも finally でマーカーを解除する' ($captured.Osc -ceq ($active + $inactive) -and $captured.ErrorMessage -eq 'paste-test readline failure')
$global:__PasteTestThrow = $false

# 入力関数だけが作り直されたプロファイル再読み込みでも元の関数を一度だけ呼ぶ。
Reset-TestFunctions
. $integration
$captured = Capture-ReadLine
Check '入力関数を作り直しても再読み込みで復帰する' ($global:__PasteTestCalls -eq 1 -and $captured.Osc -ceq ($active + $inactive + $commandStart))

Remove-Module PSReadLine
Reset-TestFunctions
. $integration
$captured = Capture-ReadLine -InitialOsc $active
Check 'PSReadLine なしでは古い有効マーカーを読取前に解除して既存の入力を維持する' (
	$captured.Value -ceq 'Write-Output paste-test' -and $captured.Osc -ceq ($active + $inactive + $inactive + $commandStart) -and
	$captured.ObservedOsc -ceq ($active + $inactive) -and -not $captured.ErrorMessage)

Import-TestPSReadLine
Reset-TestFunctions
Remove-Item Function:\PSConsoleHostReadLine
. $integration
Check '入力関数が無い環境では関数を追加せず Paste を登録しない' (-not (Test-Path Function:\PSConsoleHostReadLine) -and -not (Paste-IsBound))

Reset-TestFunctions
Set-StrictMode -Version Latest
. $integration
$captured = Capture-ReadLine
Check 'StrictMode でも入力待機と解除を送る' (-not $captured.ErrorMessage -and $captured.Osc -ceq ($active + $inactive + $commandStart))
Set-StrictMode -Off

$result = [ordered]@{
	Version = $PSVersionTable.PSVersion.ToString()
	PSReadLine = $readlineVersion
	Passed = @($checks | Where-Object Pass).Count
	Total = $checks.Count
	Checks = $checks
}
$json = $result | ConvertTo-Json -Depth 5
if ($ResultPath) { [IO.File]::WriteAllText($ResultPath, $json, (New-Object Text.UTF8Encoding($false))) } else { $json }
if ($result.Passed -ne $result.Total) { exit 1 }
