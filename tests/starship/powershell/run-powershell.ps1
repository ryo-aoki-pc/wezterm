param([string]$OutputDir = (Join-Path $PSScriptRoot 'results-final'))

# 各ケースを -NoProfile の別プロセスで実行し、ユーザープロファイル・設定を変更しない。
New-Item -ItemType Directory -Force $OutputDir | Out-Null
$shells = @(
    @{ Name='pwsh'; Path=(Get-Command pwsh).Source },
    @{ Name='windows-powershell'; Path=(Get-Command powershell).Source }
)
$statusCases = @('native-success','native-failure','cmdlet-failure','cmdlet-failure-stale-native','write-error','write-error-stale-native','native-stderr-success','native-stderr-failure','error-ignore','native-erroraction')
$otherCases = @('empty-history','short-command','threshold-exact','threshold-zero','threshold-invalid','threshold-negative','threshold-large','unicode-cwd','provider-cwd','double-load','strict','strict-fresh','empty-repeat','no-readline-callback','transient')
$jobs = @()
foreach ($shell in $shells) {
    foreach ($case in $statusCases) {
        foreach ($mode in @('baseline','wrapped')) {
            $jobs += [pscustomobject]@{ Shell=$shell; Case=$case; Mode=$mode }
        }
    }
    foreach ($case in $otherCases) { $jobs += [pscustomobject]@{ Shell=$shell; Case=$case; Mode='wrapped' } }
    foreach ($mode in @('integration-first','reinitialize')) { $jobs += [pscustomobject]@{ Shell=$shell; Case='native-success'; Mode=$mode } }
}
$active = @()
foreach ($job in $jobs) {
    while (@($active | Where-Object { -not $_.HasExited }).Count -ge 4) { Start-Sleep -Milliseconds 100 }
    $name = "$($job.Shell.Name)-$($job.Case)-$($job.Mode)"
    $result = Join-Path $OutputDir "$name.json"
    $log = Join-Path $OutputDir "$name.stderr.txt"
    $args = @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File', ('"' + (Join-Path $PSScriptRoot 'powershell-case.ps1') + '"'), '-Case', $job.Case, '-Mode', $job.Mode, '-ResultPath', ('"' + $result + '"'))
    $active += Start-Process -FilePath $job.Shell.Path -ArgumentList $args -WindowStyle Hidden -PassThru -RedirectStandardError $log -RedirectStandardOutput (Join-Path $OutputDir "$name.stdout.txt")
}
foreach ($process in $active) { $process.WaitForExit() }
$results = @($jobs | ForEach-Object {
    $name = "$($_.Shell.Name)-$($_.Case)-$($_.Mode)"
    Get-Content -Raw -LiteralPath (Join-Path $OutputDir "$name.json") | ConvertFrom-Json
})
$results | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutputDir 'summary.json') -Encoding utf8
"Recorded $($results.Count) cases in $OutputDir"
foreach ($shell in $shells) {
    & $shell.Path -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'powershell-hooks.ps1') -ResultPath (Join-Path $OutputDir "$($shell.Name)-hooks.json")
}
& (Join-Path $PSScriptRoot 'check-powershell.ps1') -OutputDir $OutputDir
