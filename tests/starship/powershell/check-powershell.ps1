param([string]$OutputDir = (Join-Path $PSScriptRoot 'results-final'))

$all = @(Get-ChildItem -LiteralPath $OutputDir -Filter '*.json' | Where-Object { $_.Name -notin @('summary.json','checks.json','pwsh-hooks.json','windows-powershell-hooks.json') } | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json })
# 個別 JSON を整理した後も summary.json だけで再集計できる。
if ($all.Count -eq 0) { $all = @(Get-Content -Raw -LiteralPath (Join-Path $OutputDir 'summary.json') | ConvertFrom-Json) }
$all | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutputDir 'summary.json') -Encoding utf8
$script:checks = @()
function Check([string]$Version,[string]$Case,[string]$Name,[bool]$Pass,[string]$Group='standard') {
    $script:checks += [pscustomobject]@{ Version=$Version; Case=$Case; Name=$Name; Pass=$Pass; Group=$Group }
}
$esc = [char]27
foreach ($item in $all) {
    if ($item.Mode -eq 'wrapped') {
        $code = if ($item.Case -in @('native-failure','native-stderr-failure','native-erroraction')) { 7 } elseif ($item.Case -in @('cmdlet-failure','cmdlet-failure-stale-native','write-error','write-error-stale-native','error-ignore')) { 1 } else { 0 }
        $d = @($item.OscItems | Where-Object { $_ -like '133;D;*' })
        Check $item.Version $item.Case '終了コード OSC 133 D' ($d.Count -eq 1 -and $d[0] -eq "133;D;$code")
        Check $item.Version $item.Case 'OSC 133 A は1個' (@($item.OscItems | Where-Object { $_ -eq '133;A' }).Count -eq 1)
        Check $item.Version $item.Case '戻り値 OSC 133 B は1個' ([regex]::Matches($item.Prompt,'\x1b\]133;B\x1b\\').Count -eq 1)
        Check $item.Version $item.Case 'prompt ラッパー維持' $item.PromptContainsWezterm
        Check $item.Version $item.Case 'ReadLine ラッパー条件' ($item.ReadLineContainsWezterm -eq ($item.Case -ne 'no-readline-callback'))
        $notifyExpected = if ($item.Case -in @('empty-history','short-command')) { 0 } else { 1 }
        Check $item.Version $item.Case '完了通知個数と閾値' (@($item.Notifications).Count -eq $notifyExpected)
        if ($notifyExpected -eq 1) {
            $elapsed = if ($item.Case -eq 'threshold-exact') { 10 } elseif ($item.Case -eq 'threshold-zero') { 0 } else { 12 }
            Check $item.Version $item.Case '完了通知 code/elapsed/payload' ($item.Notifications[0].StartsWith("$code`t$elapsed`t") -and $item.Notifications[0].Length -gt 5)
        }
        $cwd = @($item.OscItems | Where-Object { $_ -like '7;file://*' })
        if ($item.Case -eq 'provider-cwd') {
            Check $item.Version $item.Case '非 FileSystem では OSC 7 を抑止' ($cwd.Count -eq 0)
        } else {
            Check $item.Version $item.Case 'FileSystem は OSC 7 を送信' ($cwd.Count -eq 1)
            if ($item.Case -eq 'unicode-cwd') {
                Check $item.Version $item.Case 'OSC 7 UTF-8 と URL 特殊文字のエンコード' ($cwd[0] -match 'cwd%20%23%20%25%20%E6%BC%A2%E5%AD%97%20%C3%A9%20%ED%95%9C%EA%B8%80$')
            }
        }
        if ($item.Case -eq 'empty-repeat') { Check $item.Version $item.Case '同じ履歴で通知を再送しない' ($item.SecondOsc -notmatch 'SetUserVar=wezterm_cmd_done') }
        if ($item.Case -eq 'threshold-large') { Check $item.Version $item.Case '大きい閾値でも新規 Error を作らない' ($item.ErrorCount -eq 0) 'known-failure' }
    }
    if ($item.Mode -eq 'baseline') {
        $wrapped = @($all | Where-Object { $_.Version -eq $item.Version -and $_.Case -eq $item.Case -and $_.Mode -eq 'wrapped' })[0]
        Check $item.Version $item.Case 'Starship 単体と可視プロンプトが一致' ($item.PlainPrompt -ceq $wrapped.PlainPrompt)
        Check $item.Version $item.Case 'Starship 単体と LASTEXITCODE が一致' ($item.LastExitCode -eq $wrapped.LastExitCode)
        Check $item.Version $item.Case 'Starship 単体と Error 件数が一致' ($item.ErrorCount -eq $wrapped.ErrorCount)
    }
    if ($item.Mode -in @('integration-first','reinitialize')) {
        Check $item.Version ($item.Case + '/' + $item.Mode) 'Starship 初期化後に統合を再ソースして OSC が復帰' ($item.PromptContainsWezterm -and $item.OscItems.Count -gt 0) 'known-failure'
    }
}
$hooks = @(Get-ChildItem -LiteralPath $OutputDir -Filter '*-hooks.json' | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json })
foreach ($hook in $hooks) { foreach ($entry in $hook.Checks) { Check $hook.Version 'callback' $entry.Name $entry.Pass } }
$standard = @($checks | Where-Object Group -eq 'standard')
$known = @($checks | Where-Object Group -eq 'known-failure')
$report = [ordered]@{
    ProcessCases=$all.Count
    CallbackChecks=@($checks | Where-Object Case -eq 'callback').Count
    StandardPassed=@($standard | Where-Object Pass).Count
    StandardTotal=$standard.Count
    KnownFailures=@($known | Where-Object { -not $_.Pass }).Count
    UnexpectedFailures=@($standard | Where-Object { -not $_.Pass })
    Checks=$checks
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutputDir 'checks.json') -Encoding utf8
[pscustomobject]$report | Select-Object ProcessCases,CallbackChecks,StandardPassed,StandardTotal,KnownFailures,UnexpectedFailures | ConvertTo-Json -Depth 4
if (@($report.UnexpectedFailures).Count -gt 0) { exit 1 }
