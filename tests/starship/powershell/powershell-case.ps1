param(
    [string]$Case = 'native-success',
    [ValidateSet('baseline','wrapped','integration-first','reinitialize')][string]$Mode = 'wrapped',
    [string]$ResultPath
)

# 実 Starship を別プロセス内で初期化し、本番プロファイルを使わず OSC と戻り値を記録する。
# Get-History は実コマンドレットを使い、履歴の時刻だけ Add-History で再現する。
$ErrorActionPreference = 'Continue'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$env:STARSHIP_CONFIG = Join-Path $PSScriptRoot 'starship.toml'
$env:STARSHIP_CACHE = Join-Path $PSScriptRoot 'cache'
$env:TERM_PROGRAM = 'WezTerm'
$env:TERM = 'xterm-256color'
$env:NO_COLOR = '1'
$env:WEZTERM_NOTIFY_AFTER = '10'
$integration = Join-Path $root 'shell/wezterm.ps1'
$native = Join-Path $env:SystemRoot 'System32/cmd.exe'
New-Item -ItemType Directory -Force $env:STARSHIP_CACHE | Out-Null
if ($PSVersionTable.PSVersion.Major -eq 5) {
    # 親 pwsh の PSModulePath を継承しても、Windows 標準の PSReadLine 2.0.0 を使う。
    Import-Module (Join-Path ${env:ProgramFiles} 'WindowsPowerShell/Modules/PSReadLine/2.0.0/PSReadLine.psd1')
} else { Import-Module PSReadLine }
$init = & starship init powershell
$initialPrompt = $function:prompt.ToString()
$initialReadLine = $function:PSConsoleHostReadLine.ToString()
if ($Mode -eq 'integration-first') { . $integration }
Invoke-Expression ($init -join "`n")
if ($PSVersionTable.PSVersion.Major -eq 5) {
    # sandbox 外の ScheduledJobs ディレクトリを Get-Job が作ろうとするため、追加の job adapter 自動読込を止める。
    # Starship 本体と既存コマンドレットを使う。job 数の機能はこのハーネスの検証対象外。
    $PSModuleAutoLoadingPreference = 'None'
}
$starshipPrompt = $function:prompt.ToString()
if ($Case -eq 'no-readline-callback') { Remove-Item Function:\PSConsoleHostReadLine }
if ($Mode -eq 'wrapped' -or $Mode -eq 'reinitialize') { . $integration }
if ($Mode -eq 'reinitialize') {
    Invoke-Expression ($init -join "`n")
    . $integration
}
if ($Case -eq 'double-load') { . $integration; . $integration }
if ($Case -eq 'strict') { Set-StrictMode -Version Latest }
if ($Case -eq 'strict-fresh') { Remove-Variable LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue; Set-StrictMode -Version Latest }
if ($Case -eq 'transient') {
    Enable-TransientPrompt
    $starshipModule = (Get-Command Enable-TransientPrompt).Module
    & $starshipModule { $script:TransientPrompt = $true }
}

$command = switch ($Case) {
    'native-failure' { '& $native /d /c "exit /b 7"' }
    'cmdlet-failure' { 'Get-Item Z:\__wezterm_missing_path__ -ErrorAction SilentlyContinue' }
    'cmdlet-failure-stale-native' { '$global:LASTEXITCODE = 9; Get-Item Z:\__wezterm_missing_path__ -ErrorAction SilentlyContinue' }
    'write-error' { 'Write-Error "intentional wezterm test failure" -ErrorAction SilentlyContinue' }
    'write-error-stale-native' { '$global:LASTEXITCODE = 7; Write-Error "intentional wezterm test failure" -ErrorAction SilentlyContinue' }
    'native-stderr-success' { '& $native /d /c "echo intentional-stderr 1>&2 & exit /b 0" 2>&1 | Out-Null' }
    'native-stderr-failure' { '& $native /d /c "echo intentional-stderr 1>&2 & exit /b 7" 2>&1 | Out-Null' }
    'native-erroraction' { '$PSNativeCommandUseErrorActionPreference = $true; & $native /d /c "exit /b 7"' }
    'error-ignore' { 'Write-Error "intentional wezterm ignored error" -ErrorAction Ignore' }
    'strict-fresh' { 'Write-Output "success" | Out-Null' }
    default { '& $native /d /c "exit /b 0"' }
}
$elapsed = if ($Case -eq 'short-command') { 0.95 } elseif ($Case -eq 'threshold-exact') { 10 } else { 12.25 }
if ($Case -eq 'threshold-zero') { $env:WEZTERM_NOTIFY_AFTER = '0'; $elapsed = 0 }
if ($Case -eq 'threshold-invalid') { $env:WEZTERM_NOTIFY_AFTER = 'bad'; $elapsed = 12.25 }
if ($Case -eq 'threshold-negative') { $env:WEZTERM_NOTIFY_AFTER = '-1'; $elapsed = 12.25 }
if ($Case -eq 'threshold-large') { $env:WEZTERM_NOTIFY_AFTER = '999999999999999999999999'; $elapsed = 12.25 }
if ($Case -eq 'unicode-cwd') {
    $testDir = Join-Path $PSScriptRoot 'cwd # % 漢字 é 한글'
    New-Item -ItemType Directory -Force $testDir | Out-Null
    Set-Location -LiteralPath $testDir
}
if ($Case -eq 'provider-cwd') { Set-Location HKCU:\ }
if ($Case -ne 'empty-history') {
    $endTime = Get-Date
    Add-History -InputObject ([pscustomobject]@{
        # Invoke-Expression の InvocationInfo.Line に改行が付くため、Starship の cmdlet 判定とそろえる。
        CommandLine = $command + "`n"
        ExecutionStatus = 'Completed'
        StartExecutionTime = $endTime.AddSeconds(-$elapsed)
        EndExecutionTime = $endTime
    })
}
$writer = New-Object System.IO.StringWriter
$oldWriter = [Console]::Out
[Console]::SetOut($writer)
$capturedErrors = @()
$promptText = $null
# 元の prompt とラッパーに同じ $? を渡すため、直前のコマンドと prompt 呼び出しは同じ評価単位にする。
Invoke-Expression ($command + "`n" + '$promptText = prompt') 2>&1 | ForEach-Object { if ($_ -is [Management.Automation.ErrorRecord]) { $capturedErrors += $_.ToString() } }
$lastExitAfter = $global:LASTEXITCODE
$osc = $writer.ToString()
$writer.GetStringBuilder().Clear() | Out-Null
if ($Case -eq 'empty-repeat') { $secondPromptText = prompt; $secondOsc = $writer.ToString() }
[Console]::SetOut($oldWriter)
$oscRegex = [regex]'\x1b\]([^\x07\x1b]*)(?:\x07|\x1b\\)'
$oscItems = @($oscRegex.Matches($osc) | ForEach-Object { $_.Groups[1].Value })
$notifications = @($oscItems | Where-Object { $_ -like '1337;SetUserVar=wezterm_cmd_done=*' } | ForEach-Object {
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($_ -split '=',3)[2]))
})
$plain = [regex]::Replace([string]$promptText, '\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07\x1b]*(?:\x07|\x1b\\))', '')
$result = [ordered]@{
    Version = $PSVersionTable.PSVersion.ToString()
    PSReadLine = (Get-Module PSReadLine).Version.ToString()
    Case = $Case
    Mode = $Mode
    Prompt = $promptText
    PlainPrompt = $plain
    Osc = $osc
    OscItems = $oscItems
    Notifications = $notifications
    LastExitCode = $lastExitAfter
    PromptIsStarship = ($function:prompt.ToString() -eq $starshipPrompt)
    PromptContainsWezterm = ($function:prompt.ToString() -match '__WezTermOriginalPrompt')
    ReadLineContainsWezterm = if (Test-Path Function:\PSConsoleHostReadLine) { $function:PSConsoleHostReadLine.ToString() -match '__WezTermOriginalReadLine' } else { $false }
    Errors = @($capturedErrors)
    ErrorCount = $global:Error.Count
    ErrorLine = if ($global:Error.Count -gt 0) { $global:Error[0].InvocationInfo.Line } else { $null }
    SecondOsc = if ($Case -eq 'empty-repeat') { $secondOsc } else { $null }
}
$json = $result | ConvertTo-Json -Depth 8
if ($ResultPath) { [IO.File]::WriteAllText($ResultPath, $json, (New-Object Text.UTF8Encoding($false))) } else { $json }
