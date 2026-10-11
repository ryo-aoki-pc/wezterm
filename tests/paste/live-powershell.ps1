param([string]$Label = 'ps5')
# 利用者のプロファイルを読まない専用ペイン。履歴は保存せず、試験コードだけ採取する。
if ($PSVersionTable.PSVersion.Major -eq 5) {
    Import-Module PSReadLine -RequiredVersion 2.0.0 -ErrorAction Stop
} else {
    Import-Module PSReadLine -ErrorAction Stop
}
Set-PSReadLineOption -EditMode Emacs -HistorySaveStyle SaveNothing
# 利用者の通常プロファイルで確認された、改行に関係する割り当てだけ再現する。
Set-PSReadLineKeyHandler -Chord 'Ctrl+Enter' -Function AddLine
$global:PasteProbeExecuted = 0
$global:PasteProbeValue = ''
function global:prompt { 'PASTE_TEST> ' }
. "$PSScriptRoot/../../shell/wezterm.ps1"
Set-PSReadLineKeyHandler -Key F11 -ScriptBlock {
    $request = Get-Content -LiteralPath "$env:WEZTERM_PASTE_TEST_OUTPUT/probe-request.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    [string]$buffer = ''
    [int]$cursor = 0
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$buffer, [ref]$cursor)
    $capture = [ordered]@{
        buffer = $buffer
        cursor = $cursor
        executed = $global:PasteProbeExecuted
        value = $global:PasteProbeValue
        powershell = $PSVersionTable.PSVersion.ToString()
        psreadline = (Get-Module PSReadLine).Version.ToString()
        edit_mode = (Get-PSReadLineOption).EditMode.ToString()
        # -NoProfile で起動したこのペインの履歴には、生成した試験コードだけがある。
        history = @(Get-History -Count 3 | ForEach-Object CommandLine)
    }
    [IO.File]::WriteAllText("$env:WEZTERM_PASTE_TEST_OUTPUT/$($request.id).buffer.json", ($capture | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
}
$ready = [ordered]@{
    powershell = $PSVersionTable.PSVersion.ToString()
    psreadline = (Get-Module PSReadLine).Version.ToString()
    edit_mode = (Get-PSReadLineOption).EditMode.ToString()
    ctrl_v = @(Get-PSReadLineKeyHandler | Where-Object Key -eq 'Ctrl+v' | ForEach-Object Function)
    ctrl_enter = @(Get-PSReadLineKeyHandler | Where-Object Key -eq 'Ctrl+Enter' | ForEach-Object Function)
}
[IO.File]::WriteAllText("$env:WEZTERM_PASTE_TEST_OUTPUT/$Label.ready.json", ($ready | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
