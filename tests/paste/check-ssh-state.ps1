param([string]$IntegrationPath, [string]$ResultPath)
# 専用 -NoProfile プロセスで状態の失敗経路を検証する。入力・clipboard・profile は触らない。
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
$env:TERM_PROGRAM = 'WezTerm'
$env:SSH_CONNECTION = 'ssh-state-test'
if ($PSVersionTable.PSVersion.Major -eq 5) {
    Import-Module (Join-Path ${env:ProgramFiles} 'WindowsPowerShell/Modules/PSReadLine/2.0.0/PSReadLine.psd1')
} else { Import-Module PSReadLine }
Set-PSReadLineOption -EditMode Emacs -HistorySaveStyle SaveNothing
$script:checks = @()
$global:SshStateThrow = $false
$global:SshStateCalls = 0
$global:SshStateObserved = ''
function global:prompt { 'state> ' }
function global:PSConsoleHostReadLine {
    $global:SshStateCalls++
    $global:SshStateObserved = $global:SshStateWriter.ToString()
    if ($global:SshStateThrow) { throw 'controlled readline failure' }
    'controlled line'
}
function Check([string]$Name, [bool]$Pass) { $script:checks += [pscustomobject]@{name=$Name;pass=$Pass} }
function Vars([string]$Text) {
    $values = @{}
    foreach ($match in [regex]::Matches($Text, '\x1b\]1337;SetUserVar=([^=;]+)=([^\x1b\x07]*)(?:\x1b\\|\x07)')) {
        $values[$match.Groups[1].Value] = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($match.Groups[2].Value))
    }
    $values
}
function Capture {
    $global:SshStateWriter = New-Object IO.StringWriter
    $old = [Console]::Out
    $failure = $null
    try { [Console]::SetOut($global:SshStateWriter); $value = PSConsoleHostReadLine }
    catch { $failure = $_.Exception.Message }
    finally { [Console]::SetOut($old) }
    $observed = Vars $global:SshStateObserved
    $final = Vars $global:SshStateWriter.ToString()
    $global:SshStateWriter.Dispose()
    [pscustomobject]@{value=$value;failure=$failure;observed=$observed;final=$final}
}
. $IntegrationPath
$capture = Capture
Check 'SSH入力中だけ有効epochを通知する' ($capture.observed.WEZTERM_PSREADLINE_SSH_PASTE -cmatch '^1:[0-9a-f]{32}$')
Check 'SSHはlocal clipboard能力を通知しない' ($capture.observed.WEZTERM_PSREADLINE_PASTE -ceq '')
Check 'ReadLine戻り値と呼出し回数を保つ' ($capture.value -ceq 'controlled line' -and $global:SshStateCalls -eq 1)
foreach ($name in @('WEZTERM_PSREADLINE_SSH_PASTE','WEZTERM_PSREADLINE_SSH_READY','WEZTERM_PSREADLINE_SSH_RESULT')) {
    Check "ReadLine終了で $name を解除する" ($capture.final[$name] -ceq '')
}
Check '終了でepochも解除する' ($global:__WezTermSshPasteEpoch -ceq '')
$wrapped = $function:PSConsoleHostReadLine
. $IntegrationPath
. $IntegrationPath
Check '再読み込みでwrapperを重ねない' ([object]::ReferenceEquals($wrapped,$function:PSConsoleHostReadLine))
Set-PSReadLineOption -EditMode Emacs
$null = Capture
Check '入力のたびに専用キーを復旧する' (@(Get-PSReadLineKeyHandler -Bound | Where-Object Function -eq WezTermSshPaste).Count -eq 1)
$global:SshStateThrow = $true
$capture = Capture
Check 'ReadLine例外を保つ' ($capture.failure -eq 'controlled readline failure')
Check '例外でも入力能力を解除する' ($capture.final.WEZTERM_PSREADLINE_SSH_PASTE -ceq '' -and $global:__WezTermSshPasteEpoch -ceq '')
$global:SshStateThrow = $false
function global:Set-PSReadLineKeyHandler { param($Chord,$Function,$BriefDescription,$ScriptBlock,$ErrorAction); throw 'controlled registration failure' }
try {
    . $IntegrationPath
    $capture = Capture
    Check '登録失敗はunavailableを通知し通常貼り付けを抑止する' ($capture.observed.WEZTERM_PSREADLINE_SSH_PASTE -ceq 'unavailable')
    Check '登録失敗でも入力関数を維持する' ($capture.value -ceq 'controlled line' -and -not $capture.failure)
    Check '登録失敗後も終了で解除する' ($capture.final.WEZTERM_PSREADLINE_SSH_PASTE -ceq '')
} finally { Remove-Item Function:\Set-PSReadLineKeyHandler }
Set-StrictMode -Version Latest
. $IntegrationPath
$capture = Capture
Check 'StrictModeでもepochを通知して解除する' (-not $capture.failure -and $capture.observed.WEZTERM_PSREADLINE_SSH_PASTE -cmatch '^1:[0-9a-f]{32}$' -and $capture.final.WEZTERM_PSREADLINE_SSH_PASTE -ceq '')
Set-StrictMode -Off
Remove-Module PSReadLine
$capture = Capture
Check 'PSReadLine無効化で能力を消して入力関数を保つ' ($capture.observed.WEZTERM_PSREADLINE_SSH_PASTE -ceq 'unavailable' -and $capture.value -ceq 'controlled line')
$result = [ordered]@{version=$PSVersionTable.PSVersion.ToString();passed=@($checks | Where-Object pass).Count;total=$checks.Count;checks=$checks}
$json = $result | ConvertTo-Json -Depth 5
if($ResultPath){[IO.File]::WriteAllText($ResultPath,$json,(New-Object Text.UTF8Encoding($false)))}else{$json}
if($result.passed -ne $result.total){exit 1}
