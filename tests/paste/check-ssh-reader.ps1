param([string]$IntegrationPath, [string]$ResultPath)
# Console だけを制御用 shim に置換し、製品 Reader の入出力例外を注入して検証する。
# 専用 -NoProfile プロセスで実行し、実入力・clipboard・profile は変更しない。
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
$source = [IO.File]::ReadAllText($IntegrationPath)
$match = [regex]::Match($source, "(?s)Add-Type -TypeDefinition @'\r?\n(.*?)\r?\n'@")
if (-not $match.Success) { throw 'Reader のソースを見つけられない' }
$reader = $match.Groups[1].Value.Replace('namespace WezTermSshPasteV2', 'namespace WezTermSshPasteFaultTests').Replace('Console.', 'FaultConsole.')
$shim = @'
namespace WezTermSshPasteFaultTests {
    public static class FaultConsole {
        public static bool TreatControlCAsInput;
        public static System.Collections.Generic.Queue<System.ConsoleKeyInfo> Keys;
        public static string Ready;
        public static string Operation;
        public static int FaultAt, Remaining, AvailableCalls, ReadCalls;
        public static bool InvalidOperation;
        public static void Reset(string input, string operation, int faultAt, int count, bool invalidOperation) {
            Keys = new System.Collections.Generic.Queue<System.ConsoleKeyInfo>();
            foreach (char c in input) Keys.Enqueue(new System.ConsoleKeyInfo(c, System.ConsoleKey.A, false, false, false));
            Ready = ""; Operation = operation; FaultAt = faultAt; Remaining = count;
            AvailableCalls = 0; ReadCalls = 0; InvalidOperation = invalidOperation;
            TreatControlCAsInput = false;
        }
        private static void Fault(string operation, int call) {
            if (Operation != operation || call < FaultAt || Remaining <= 0) return;
            Remaining--;
            if (InvalidOperation) throw new System.InvalidOperationException("controlled input failure");
            throw new System.IO.IOException("controlled input failure");
        }
        public static bool KeyAvailable {
            get { Fault("available", ++AvailableCalls); return Keys.Count > 0; }
        }
        public static System.ConsoleKeyInfo ReadKey(bool intercept) {
            Fault("read", ++ReadCalls); return Keys.Dequeue();
        }
        public static void Write(string text) { Fault("write", 1); Ready += text; }
    }
}
'@
Add-Type -TypeDefinition ($reader + "`n" + $shim) -ErrorAction Stop
$prefix = 'WZP2:0123456789abcdef0123456789abcdef:'
$frame = $prefix + '4:QQ=='
$ending = '~WZE2:0123456789abcdef0123456789abcdef~'
$script:checks = @()
function Check([string]$Name, [bool]$Pass) { $script:checks += [pscustomobject]@{name=$Name;pass=$Pass} }
function Read-Case([string]$InputText, [string]$Operation, [int]$FaultAt, [int]$Count, [bool]$InvalidOperation) {
    [WezTermSshPasteFaultTests.FaultConsole]::Reset($InputText, $Operation, $FaultAt, $Count, $InvalidOperation)
    [WezTermSshPasteFaultTests.Reader]::Read(87480, 50, $prefix, 'BODYREADY', $ending)
}
$result = Read-Case ($frame + $ending) '' 0 0 $false
Check '通常受信の本文と終端消費を保つ' ($result.Status -eq 'complete' -and $result.Frame -ceq $frame -and [WezTermSshPasteFaultTests.FaultConsole]::Keys.Count -eq 0)
Check '通常受信で正しいヘッダー後にだけACKする' ([WezTermSshPasteFaultTests.FaultConsole]::Ready -ceq 'BODYREADY')
Check '通常受信後にCtrlC設定を復元する' (-not [WezTermSshPasteFaultTests.FaultConsole]::TreatControlCAsInput)
foreach ($invalid in @($false, $true)) {
    $kind = if ($invalid) { 'InvalidOperationException' } else { 'IOException' }
    foreach ($op in @('available', 'read')) {
        $result = Read-Case ($frame + $ending) $op ($prefix.Length + 3) 1 $invalid
        Check "本文中の $kind / $op は終端まで捨てる" ($result.Status -eq 'invalid' -and $null -eq $result.Frame -and [WezTermSshPasteFaultTests.FaultConsole]::Keys.Count -eq 0 -and [WezTermSshPasteFaultTests.FaultConsole]::Ready -ceq 'BODYREADY')
        Check "本文中の $kind / $op 後にCtrlC設定を復元する" (-not [WezTermSshPasteFaultTests.FaultConsole]::TreatControlCAsInput)
    }
    $result = Read-Case ($frame + $ending) 'read' ($frame.Length + 10) 1 $invalid
    Check "終端の途中の $kind も照合位置を保って読み捨てる" ($result.Status -eq 'invalid' -and $null -eq $result.Frame -and [WezTermSshPasteFaultTests.FaultConsole]::Keys.Count -eq 0)
    $result = Read-Case ($prefix + $ending) 'write' 1 1 $invalid
    Check "ACK書き込みの $kind も終端まで捨てる" ($result.Status -eq 'invalid' -and $null -eq $result.Frame -and [WezTermSshPasteFaultTests.FaultConsole]::Keys.Count -eq 0 -and [WezTermSshPasteFaultTests.FaultConsole]::Ready -eq '')
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $result = Read-Case '' 'available' 1 100 $invalid
    Check "ヘッダー前の持続 $kind は絶対期限で終了する" ($result.Status -eq 'invalid' -and $watch.ElapsedMilliseconds -lt 500 -and [WezTermSshPasteFaultTests.FaultConsole]::Ready -eq '' -and -not [WezTermSshPasteFaultTests.FaultConsole]::TreatControlCAsInput)
    $result = Read-Case ($frame + $ending) 'available' ($prefix.Length + 3) 10 $invalid
    Check "ヘッダー後の持続 $kind は期限超過後も終端を消費する" ($result.Status -eq 'invalid' -and $null -eq $result.Frame -and [WezTermSshPasteFaultTests.FaultConsole]::Keys.Count -eq 0)
}
$result = Read-Case ($prefix + '~4:QQ==' + $ending) '' 0 0 $false
Check '本文前の通常~は入力欄へ戻らず本物の終端まで捨てる' ($result.Status -eq 'invalid' -and $null -eq $result.Frame -and [WezTermSshPasteFaultTests.FaultConsole]::Keys.Count -eq 0)
$result = Read-Case ($frame + '~WZE2:ffffffffffffffffffffffffffffffff~' + $ending) '' 0 0 $false
Check '偽の終端は本物の識別子付き終端まで捨てる' ($result.Status -eq 'invalid' -and $null -eq $result.Frame -and [WezTermSshPasteFaultTests.FaultConsole]::Keys.Count -eq 0)
$result = Read-Case ($frame + '~WZE2:01234' + $ending) '' 0 0 $false
Check '部分的な終端は本物の識別子付き終端まで捨てる' ($result.Status -eq 'invalid' -and $null -eq $result.Frame -and [WezTermSshPasteFaultTests.FaultConsole]::Keys.Count -eq 0)
$result = Read-Case ($prefix + $ending) '' 0 0 $false
Check '本文なしの取消終端も入力キューへ残さない' ($result.Status -eq 'complete' -and $result.Frame -ceq $prefix -and [WezTermSshPasteFaultTests.FaultConsole]::Keys.Count -eq 0)

$result = [ordered]@{version=$PSVersionTable.PSVersion.ToString();source_sha256=(Get-FileHash -LiteralPath $IntegrationPath -Algorithm SHA256).Hash.ToLowerInvariant();passed=@($checks | Where-Object pass).Count;total=$checks.Count;checks=$checks}
$json = $result | ConvertTo-Json -Depth 5
if ($ResultPath) { [IO.File]::WriteAllText($ResultPath,$json,(New-Object Text.UTF8Encoding($false))) } else { $json }
if ($result.passed -ne $result.total) { exit 1 }
