param([string]$ResultPath)

# PSReadLine の実入力は WezTerm 実ペインで確認する。このハーネスは callback の戻り値・OSC を再現入力で検査する。
$root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$integration = Join-Path $root 'shell/wezterm.ps1'
$env:STARSHIP_CONFIG = Join-Path $PSScriptRoot 'starship.toml'
$env:STARSHIP_CACHE = Join-Path $PSScriptRoot 'cache'
$env:TERM = 'xterm-256color'
if ($PSVersionTable.PSVersion.Major -eq 5) {
    Import-Module (Join-Path ${env:ProgramFiles} 'WindowsPowerShell/Modules/PSReadLine/2.0.0/PSReadLine.psd1')
} else { Import-Module PSReadLine }
Invoke-Expression ((& starship init powershell) -join "`n")
$starshipPrompt = $function:prompt.ToString()
$beforeReadLine = $function:PSConsoleHostReadLine.ToString()
$env:TERM_PROGRAM = 'OtherTerminal'
. $integration
$checks = @()
$checks += [pscustomobject]@{ Name='非 WezTerm で prompt を変更しない'; Pass=($function:prompt.ToString() -eq $starshipPrompt) }
$checks += [pscustomobject]@{ Name='非 WezTerm で readline を変更しない'; Pass=($function:PSConsoleHostReadLine.ToString() -eq $beforeReadLine) }
$checks += [pscustomobject]@{ Name='非 WezTerm で Loaded を設定しない'; Pass=(-not $global:__WezTermIntegrationLoaded) }
$env:TERM_PROGRAM = 'WezTerm'
$global:ReadLineCalls = 0
function global:PSConsoleHostReadLine { $global:ReadLineCalls++; return $global:ReadLineResult }
. $integration
$firstPrompt = $function:prompt.ToString()
$firstReadLine = $function:PSConsoleHostReadLine.ToString()
. $integration
. $integration
$checks += [pscustomobject]@{ Name='再読み込みで prompt を重ねない'; Pass=($function:prompt.ToString() -eq $firstPrompt) }
$checks += [pscustomobject]@{ Name='再読み込みで readline を重ねない'; Pass=($function:PSConsoleHostReadLine.ToString() -eq $firstReadLine) }
$writer = New-Object IO.StringWriter
$oldWriter = [Console]::Out
[Console]::SetOut($writer)
$readlineDetails = @()
foreach ($line in @('', ' ', "`t", 'echo hello', "line1`nline2", '日本語')) {
    $global:ReadLineResult = $line
    $before = $global:ReadLineCalls
    $writer.GetStringBuilder().Clear() | Out-Null
    $value = PSConsoleHostReadLine
    $osc = $writer.ToString()
    $expected = if ($line.Trim()) { "$([char]27)]133;C$([char]27)\" } else { '' }
    $checks += [pscustomobject]@{ Name="readline 戻り値 [$line]"; Pass=($value -ceq $line) }
    $checks += [pscustomobject]@{ Name="readline C 通知 [$line]"; Pass=($osc -ceq $expected -and $global:ReadLineCalls -eq ($before+1)) }
    $readlineDetails += [pscustomobject]@{ Input=$line; Output=$value; Osc=$osc }
}
[Console]::SetOut($oldWriter)
$result = [ordered]@{ Version=$PSVersionTable.PSVersion.ToString(); Passed=@($checks | Where-Object Pass).Count; Total=$checks.Count; Checks=$checks; ReadLine=$readlineDetails }
$json = $result | ConvertTo-Json -Depth 6
if ($ResultPath) { [IO.File]::WriteAllText($ResultPath, $json, (New-Object Text.UTF8Encoding($false))) } else { $json }
