# 実 PSReadLine で Starship と統合を読む。ユーザープロファイルは読まない。
Import-Module PSReadLine
Set-PSReadLineOption -HistorySaveStyle SaveNothing
Invoke-Expression (& starship init powershell | Out-String)
. "$PSScriptRoot/../../shell/wezterm.ps1"
