param([Parameter(Mandatory=$true)][string]$IntegrationPath, [string]$Label = 'ps5')
# SSH の専用ペイン。利用者のプロファイル・履歴・クリップボードは触らない。
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -eq 5) {
    Import-Module PSReadLine -RequiredVersion 2.0.0 -ErrorAction Stop
} else { Import-Module PSReadLine -ErrorAction Stop }
Set-PSReadLineOption -EditMode Emacs -HistorySaveStyle SaveNothing
Set-PSReadLineKeyHandler -Chord 'Ctrl+Enter' -Function AddLine
$env:TERM_PROGRAM = 'WezTerm'
$global:SSHPasteProbeExecuted = 0
$global:SSHPasteProbeValue = ''
$global:SSHPasteProbeIntegration = $IntegrationPath
$global:SSHPasteProbeLabel = $Label
$global:SSHPasteProbeGroups = @(& "$env:WINDIR\System32\whoami.exe" /groups)
function global:prompt { 'SSH_PASTE_TEST> ' }
function global:Write-SSHPasteProbe {
    param([string]$Kind = 'buffer')
    [string]$buffer = ''
    [int]$cursor = 0
    [int]$selectionStart = -1
    [int]$selectionLength = 0
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$buffer, [ref]$cursor)
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $capture = [ordered]@{
        kind = $Kind
        label = $global:SSHPasteProbeLabel
        buffer = $buffer
        cursor = $cursor
        selection_start = $selectionStart
        selection_length = $selectionLength
        executed = $global:SSHPasteProbeExecuted
        value = $global:SSHPasteProbeValue
        powershell = $PSVersionTable.PSVersion.ToString()
        psreadline = (Get-Module PSReadLine).Version.ToString()
        edit_mode = (Get-PSReadLineOption).EditMode.ToString()
        user = $identity.Name
        administrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        groups = $global:SSHPasteProbeGroups
        process_id = $PID
        ssh_connection_present = [bool]$env:SSH_CONNECTION
        shell_integration_loaded = [bool](Test-Path Function:\__WezTermEnableSshPaste)
    }
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($capture | ConvertTo-Json -Compress -Depth 5)))
    [Console]::Write("$([char]27)]1337;SetUserVar=WEZTERM_SSH_PASTE_TEST=$encoded$([char]27)\")
}
. $IntegrationPath
Set-PSReadLineKeyHandler -Key F11 -ScriptBlock { Write-SSHPasteProbe }
Set-PSReadLineKeyHandler -Key F10 -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::SelectAll($null, $null)
    Write-SSHPasteProbe -Kind selected
}
# 起動後の F11 で環境と入力待機状態を確認する。
