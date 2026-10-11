# WezTerm シェル統合 (PowerShell 7 / Windows PowerShell)
#
#   OSC 7   カレントディレクトリを端末に通知する。
#           → 新しいタブ・分割ペインが「今いるディレクトリ」で開く
#           → タブ名がディレクトリ名になる (lua/tabs.lua の cwd_label)
#   OSC 133 プロンプトと出力の位置を端末に通知する。
#           → Ctrl+Shift+Alt+↑/↓ で前後のプロンプトへジャンプできる
#           → Ctrl+Shift+Alt+C で直前のコマンドの出力をコピーできる
#   OSC 1337 SetUserVar
#           長いコマンドが終わったことを端末に通知する。
#           → 見ていないペインなら完了をトースト通知 (lua/notify.lua)
#
# lua/shells.lua が PowerShell を起動するときに -Command で自動的に
# ドットソースするため、プロファイルへの追記は不要。

# WezTerm 以外の端末で読み込まれても無害なように何もせず抜ける
if ($env:TERM_PROGRAM -ne 'WezTerm') { return }

# Windows の貼り付けは PSReadLine にクリップボードを読ませる。端末から改行を
# 送る経路を避けるため、Emacs モードでも Ctrl+v に Paste を明示的に割り当てる。
# 再読み込みでラッパーが残っていても更新できるよう、早期 return より前に置く。
function global:__WezTermEnablePSReadLinePaste {
	if ($env:OS -ne 'Windows_NT' -or -not (Get-Module PSReadLine) -or
		-not (Test-Path Function:\PSConsoleHostReadLine)) { return $false }
	try {
		Set-PSReadLineKeyHandler -Chord 'Ctrl+v' -Function Paste -ErrorAction Stop
		return $true
	} catch {
		# 対応していない環境や登録失敗では端末の通常貼り付けに任せる
		return $false
	}
}
$null = __WezTermEnablePSReadLinePaste

# SSH の貼り付けは接続元のクリップボードを ASCII フレームで受け取る。
# PSReadLine の入力中だけ能力を通知し、Enter を送らず公開 API で挿入する。
function global:__WezTermSshVar([string]$Name, [string]$Value) {
	$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Value))
	[Console]::Write("$([char]27)]1337;SetUserVar=$Name=$encoded$([char]27)\")
}
function global:__WezTermClearSshPaste {
	$global:__WezTermSshPasteEpoch = ''
	foreach ($name in @('WEZTERM_PSREADLINE_SSH_PASTE', 'WEZTERM_PSREADLINE_SSH_READY', 'WEZTERM_PSREADLINE_SSH_RESULT')) {
		__WezTermSshVar $name ''
	}
}
if (-not (Test-Path Variable:global:__WezTermSshPasteEpoch)) { $global:__WezTermSshPasteEpoch = '' }

function global:__WezTermReceiveSshPaste {
	if (-not $global:__WezTermSshPasteEpoch) { return }
	$epoch = $global:__WezTermSshPasteEpoch
	$nonce = [Guid]::NewGuid().ToString('N')
	$result = 'error:invalid'
	try {
		__WezTermSshVar WEZTERM_PSREADLINE_SSH_READY "2:${epoch}:$nonce"
		$bodyReady = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("2:${epoch}:${nonce}:body"))
		$bodyReadyOsc = "$([char]27)]1337;SetUserVar=WEZTERM_PSREADLINE_SSH_READY=$bodyReady$([char]27)\"
		$received = [WezTermSshPasteV2.Reader]::Read(87480, 5000, "WZP2:${nonce}:", $bodyReadyOsc, "~WZE2:${nonce}~")
		if ($received.Status -ne 'complete') { $result = "error:$($received.Status)"; return }
		$frame = $received.Frame
		if ($frame -cnotmatch '\AWZP2:([0-9a-f]{32}):([0-9]{1,7}):([A-Za-z0-9+/]*={0,2})\z') { return }
		if ($Matches[1] -cne $nonce) { return }
		$payload = $Matches[3]
		if ([int]$Matches[2] -ne $payload.Length -or $payload.Length % 4 -ne 0) { return }
		$bytes = [Convert]::FromBase64String($payload)
		if ($bytes.Length -gt 65536) { $result = 'error:oversize'; return }
		$text = (New-Object Text.UTF8Encoding($false, $true)).GetString($bytes)
		if ($text.IndexOf([char]0) -ge 0) { return }
		# PSReadLine の Paste と同じ CR・タブ処理。LF・空行・末尾改行は保つ。
		$text = $text.Replace("`r", '').Replace("`t", '    ')
		$selectionStart = 0
		$selectionLength = 0
		[Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)
		if ($selectionStart -ge 0 -and $selectionLength -gt 0) {
			[Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $text)
		} else {
			[Microsoft.PowerShell.PSConsoleReadLine]::Insert($text)
		}
		$result = 'ok'
	} catch {
		# 復号・挿入失敗で本文をコマンドとして出力しない。
		$result = 'error:invalid'
	} finally {
		__WezTermSshVar WEZTERM_PSREADLINE_SSH_READY ''
		__WezTermSshVar WEZTERM_PSREADLINE_SSH_RESULT "2:${epoch}:$result"
		# 使った応答は再利用させず、同じ入力待機内でも新しい epoch に切り替える。
		$global:__WezTermSshPasteEpoch = [Guid]::NewGuid().ToString('N')
		__WezTermSshVar WEZTERM_PSREADLINE_SSH_PASTE "2:$global:__WezTermSshPasteEpoch"
	}
}
# 1 文字ごとの PowerShell 解釈を避ける。正しい prefix の受信後にだけ本文を許可し、
# 本文が始まった後は取消・不正データでも必ず nonce 付き終端まで読む。
# 手入力の ~ や偽の終端では復帰せず、接続元から届く本文の尾部を排出する。
# 端末の入出力例外も不正として保持し、本文の尾部を親の入力へ戻さない。
# 型は SSH の初回読み込みだけで作り、再読み込み時は再利用する。
function global:__WezTermLoadSshReader {
	if ('WezTermSshPasteV2.Reader' -as [type]) { return }
	Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading;
namespace WezTermSshPasteV2 {
    public class FrameResult {
        public string Status;
        public string Frame;
    }
    public static class Reader {
        public static FrameResult Read(int maximum, int timeout, string prefix, string bodyReadyOsc, string terminator) {
            bool previous = Console.TreatControlCAsInput;
            bool started = false, cancelled = false, invalid = false, oversize = false;
            int matched = 0, endMatched = 0;
            var buffer = new StringBuilder();
            var watch = Stopwatch.StartNew();
            try {
                Console.TreatControlCAsInput = true;
                while (true) {
                    if (!started && watch.ElapsedMilliseconds >= timeout)
                        return new FrameResult {
                            Status = cancelled ? "cancelled" : invalid ? "invalid" : "timeout"
                        };
                    try {
                        if (!Console.KeyAvailable) {
                            Thread.Sleep(10);
                            continue;
                        }
                        var key = Console.ReadKey(true);
                        if (key.Key == ConsoleKey.C && (key.Modifiers & ConsoleModifiers.Control) != 0) {
                            cancelled = true;
                            buffer.Clear();
                            continue;
                        }
                        char c = key.KeyChar;
                        if (c == '\0') continue;
                        if (!started) {
                            if (c == prefix[matched]) {
                                matched++;
                            } else {
                                invalid = true;
                                matched = c == prefix[0] ? 1 : 0;
                            }
                            if (matched == prefix.Length) {
                                started = true;
                                buffer.Append(prefix);
                                Console.Write(bodyReadyOsc);
                            }
                            continue;
                        }
                        if (endMatched > 0 || c == terminator[0]) {
                            if (c == terminator[endMatched]) {
                                endMatched++;
                                if (endMatched == terminator.Length)
                                    return new FrameResult {
                                        Status = cancelled ? "cancelled" : invalid ? "invalid" : oversize ? "oversize" : "complete",
                                        Frame = cancelled || invalid || oversize ? null : buffer.ToString()
                                    };
                                continue;
                            }
                            invalid = true;
                            buffer.Clear();
                            endMatched = c == terminator[0] ? 1 : 0;
                        }
                        if (buffer.Length >= maximum) { oversize = true; buffer.Clear(); }
                        if (!cancelled && !invalid && !oversize) buffer.Append(c);
                    } catch (IOException) {
                        invalid = true;
                        buffer.Clear();
                        Thread.Sleep(10);
                    } catch (InvalidOperationException) {
                        invalid = true;
                        buffer.Clear();
                        Thread.Sleep(10);
                    }
                }
            } finally { Console.TreatControlCAsInput = previous; }
        }
    }
}
'@ -ErrorAction Stop
}
function global:__WezTermEnableSshPaste {
	if ($env:OS -ne 'Windows_NT' -or -not $env:SSH_CONNECTION -or
		-not (Get-Module PSReadLine) -or -not (Test-Path Function:\PSConsoleHostReadLine)) { return $false }
	try {
		__WezTermLoadSshReader
		Set-PSReadLineKeyHandler -Chord 'Ctrl+Shift+F12' -BriefDescription WezTermSshPaste -ScriptBlock {
			__WezTermReceiveSshPaste
		} -ErrorAction Stop
		return $true
	} catch { return $false }
}
$null = __WezTermEnableSshPaste

# 自分のラッパーが残っていれば二重に包まない。プロファイルの再読み込みなどで
# prompt / PSReadLine が作り直されたときは、新しい関数を包み直す。
# 未定義の変数を先に Test-Path で確かめ、Set-StrictMode の初回読み込みにも対応する
$__wz_prompt_wrapped = (Test-Path Variable:global:__WezTermWrappedPrompt) -and
	[object]::ReferenceEquals($function:prompt, $global:__WezTermWrappedPrompt)
$__wz_readline_present = Test-Path Function:\PSConsoleHostReadLine
$__wz_readline_wrapped = $__wz_readline_present -and
	(Test-Path Variable:global:__WezTermWrappedReadLine) -and
	[object]::ReferenceEquals($function:PSConsoleHostReadLine, $global:__WezTermWrappedReadLine)
if ($__wz_prompt_wrapped -and (-not $__wz_readline_present -or $__wz_readline_wrapped)) { return }
# 片方だけが作り直された場合、残っているラッパーを元に戻してから両方を登録する。
# これで元の prompt / 入力関数として自分自身を保存してしまう再帰を防ぐ
if ($__wz_prompt_wrapped) { $function:prompt = $global:__WezTermOriginalPrompt }
if ($__wz_readline_wrapped) { $function:PSConsoleHostReadLine = $global:__WezTermOriginalReadLine }
$global:__WezTermIntegrationLoaded = $true

# 既存の prompt 関数（ユーザープロファイルや oh-my-posh が定義したもの）を保存して
# ラップする。中身は書き換えず、前後に通知を足すだけにする
$global:__WezTermOriginalPrompt = $function:prompt

# 完了通知を送った履歴の Id（同じコマンドで二度通知しないため）
$__wz_h = Get-History -Count 1
$global:__WezTermNotifiedId = if ($__wz_h) { $__wz_h.Id } else { 0 }

# プロンプトを出した時点の $Error の先頭。次の行で新しいエラーが記録されたかを、
# これと同じオブジェクトかどうかで見分ける（終了コードの判定に使う）
$global:__WezTermLastError = if ($global:Error.Count -gt 0) { $global:Error[0] }

# OSC 7 に載せるホスト名。WezTerm 側 (wezterm.hostname()) と同じ DNS ホスト名にそろえる。
# lua/tabs.lua はこれが自分のホスト名と違うと ssh 先とみなして「ホスト:ディレクトリ」表示に
# するため。$env:COMPUTERNAME は NetBIOS 名で 15 文字に切り詰められ、一致しないことがある
$global:__WezTermHostName = [System.Net.Dns]::GetHostName()
if (-not $global:__WezTermHostName) { $global:__WezTermHostName = 'localhost' }

function global:prompt {
	# $? は prompt の最初の文で取らないと、後続の処理で上書きされてしまう
	$ok = $?
	# プロファイルで Set-StrictMode を有効にしていても落ちないよう、この関数（と中から呼ぶ
	# 元の prompt）の中だけ切る。空の $Error の [0] や、ネイティブコマンドを一度も動かして
	# いないときの $LASTEXITCODE（未定義）を読むと例外になり、プロンプトが「PS>」に化けるため
	Set-StrictMode -Off
	# 直前に実行した行（空 Enter では増えない）。完了通知で使う
	$last = Get-History -Count 1

	# 終了コード（Windows Terminal のシェル統合と同じ考え方）。$? は成否しか持たず、
	# $LASTEXITCODE はネイティブコマンド（git など）が動いたときしか更新されない
	# （コマンドレットが失敗しても前の値が残る）ので、この行で記録されたエラーで見分ける
	#   成功                                        → 0
	#   この行の PowerShell のエラー（コマンドレット・throw） → 1
	#   この行のネイティブコマンドのエラー          → $LASTEXITCODE（0 もそのまま）
	#     ※ Windows PowerShell は stderr を 2>&1 などで受けると、終了コード 0 でも $? が
	#       偽になり NativeCommandError が記録される。PowerShell 7.3 以降の
	#       $PSNativeCommandUseErrorActionPreference による失敗は NativeCommandExitException
	#   この行のエラーが無い（ネイティブコマンドの失敗） → $LASTEXITCODE（0 や未設定なら 1）
	# 「この行のエラーか」は、前のプロンプトのときの $Error の先頭と別物かで見る
	# （エラーの InvocationInfo.HistoryId は Windows PowerShell のネイティブコマンドでは -1 で使えない。
	#   $Error の件数も上限 256 件に達すると増えないので使えない）
	$code = 0
	if (-not $ok) {
		$code = 1
		$err = if ($global:Error.Count -gt 0) { $global:Error[0] }
		if ($err -and -not [object]::ReferenceEquals($err, $global:__WezTermLastError)) {
			# 型は名前で比べる（Windows PowerShell にはこの型が無く、[型] と書くとその場でエラーになる）
			if ($err -is [System.Management.Automation.ErrorRecord] -and (
					$err.FullyQualifiedErrorId -like 'NativeCommandError*' -or
					$err.Exception.GetType().FullName -eq 'System.Management.Automation.NativeCommandExitException')) {
				$code = [int]$global:LASTEXITCODE
			}
		} elseif ($global:LASTEXITCODE) {
			$code = $global:LASTEXITCODE
		}
	}

	$esc = [char]27
	$st = "$esc\"  # 文字列終端 (ST)。ESC + バックスラッシュ
	$out = "$esc]133;D;$code$st"

	# 長いコマンドの完了通知。WEZTERM_NOTIFY_AFTER 秒（既定 10）以上かかったコマンドなら
	# 「終了コード<TAB>経過秒<TAB>コマンド」をユーザー変数 wezterm_cmd_done で送る。
	# 出すかどうか（見ていないペインのときだけ）は lua/notify.lua が決める。
	# 空 Enter では履歴が増えないので、通知済みの Id と比べて二度送らない
	if ($last -and $last.Id -ne $global:__WezTermNotifiedId) {
		$global:__WezTermNotifiedId = $last.Id
		$threshold = 10
		if ($env:WEZTERM_NOTIFY_AFTER -match '^\d+$') { $threshold = [int]$env:WEZTERM_NOTIFY_AFTER }
		$elapsed = [int][math]::Floor(($last.EndExecutionTime - $last.StartExecutionTime).TotalSeconds)
		if ($elapsed -ge $threshold) {
			# SetUserVar の値は base64 で送る決まり（WezTerm 側で復号される）
			$value = "$code`t$elapsed`t$($last.CommandLine)"
			$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($value))
			$out += "$esc]1337;SetUserVar=wezterm_cmd_done=$b64$st"
		}
	}

	# OSC 7: ファイルシステム以外のプロバイダ（レジストリ等）では送らない
	if ($PWD.Provider.Name -eq 'FileSystem') {
		# file:// URL に載せるため、英数字と - _ . ~ 以外を UTF-8 のパーセントエンコードにする
		#   - # と ? をそのまま送ると、WezTerm がそこから後ろを捨てる（パスが変わり、タブ名がずれて、
		#     新しいタブがホームで開く）
		#   - ASCII 以外の文字は、[Console]::Write がコンソールのコード ページ（日本語版 Windows は
		#     932）で書き出すため、そこに無い文字（é・ハングル・絵文字など）が化ける
		# EscapeDataString は / と : もエンコードするので、この 2 つは戻す（C: はドライブ名として
		# 読まれるよう、そのまま送る必要がある）
		$p = [Uri]::EscapeDataString($PWD.ProviderPath.Replace('\', '/')).Replace('%2F', '/').Replace('%3A', ':')
		# "C:/..." には先頭の / が無いので補う（file://host/C:/... が Windows の標準形）
		if (-not $p.StartsWith('/')) { $p = "/$p" }
		$out += "$esc]7;file://$global:__WezTermHostName$p$st"
	}

	# プロンプト開始 (A)
	$out += "$esc]133;A$st"
	# PSReadLine がプロンプト幅を誤らないよう、通知は戻り値に混ぜず直接書き出す
	[Console]::Write($out)

	# 元の prompt の出力に、入力開始 (B) の通知を付けて返す。
	# 元の prompt が $? で直前の失敗を表示できるよう（oh-my-posh・starship など）、失敗だったときは
	# $? を偽に戻してから呼ぶ（ここまでの処理で真になっている）。-ErrorAction Ignore のエラーは
	# $Error に残らない（VS Code のシェル統合と同じ方法）
	if (-not $ok) { Write-Error -Message 'wezterm' -ErrorAction Ignore }
	$text = & $global:__WezTermOriginalPrompt
	# 次の行で新しいエラーが出たかを見分ける印（元の prompt が出したエラーもここで含めておく）
	$global:__WezTermLastError = if ($global:Error.Count -gt 0) { $global:Error[0] }
	return "$text$esc]133;B$st"
}

$global:__WezTermWrappedPrompt = $function:prompt

# 出力の開始位置 (133;C) を送る。これで「直前の出力をコピー」(Ctrl+Shift+Alt+C) が
# PowerShell でも出力の範囲を取れる。
# Enter で確定した直後・コマンドの実行前に呼ばれる PSConsoleHostReadLine（PSReadLine が
# 定義する入力読み取り関数）をラップする（VS Code のシェル統合と同じ手法）。
# PSReadLine が読み込まれていない環境では関数が無いので何もしない
if (Test-Path Function:\PSConsoleHostReadLine) {
	$global:__WezTermOriginalReadLine = $function:PSConsoleHostReadLine

	function global:PSConsoleHostReadLine {
		# EditMode を後から設定するとキー割り当てが消えるため、入力のたびに登録する。
		# マーカーは PSReadLine の入力待機中だけに限定し、Read-Host や実行中の
		# コマンドへ Ctrl+v を送らない。読み取りが例外になっても finally で解除する。
		$sshSession = [bool]$env:SSH_CONNECTION
		$sshReady = __WezTermEnableSshPaste
		$pasteReady = (__WezTermEnablePSReadLinePaste) -and -not $sshSession
		$pasteValue = if ($pasteReady) { 'MQ==' } else { '' }
		$esc = [char]27
		try {
			# 対応していないときも空を送り、前のプログラムが残したマーカーを消す。
			[Console]::Write("$esc]1337;SetUserVar=WEZTERM_PSREADLINE_PASTE=$pasteValue$esc\")
			if ($sshSession) {
				__WezTermClearSshPaste
				if ($sshReady) {
					$global:__WezTermSshPasteEpoch = [Guid]::NewGuid().ToString('N')
					__WezTermSshVar WEZTERM_PSREADLINE_SSH_PASTE "2:$global:__WezTermSshPasteEpoch"
				} else {
					# 統合の登録失敗を通常貼り付けと区別し、本文を端末キーとして送らせない。
					__WezTermSshVar WEZTERM_PSREADLINE_SSH_PASTE 'unavailable'
				}
			}
			$line = & $global:__WezTermOriginalReadLine
		} finally {
			if ($sshSession) { __WezTermClearSshPaste }
			[Console]::Write("$esc]1337;SetUserVar=WEZTERM_PSREADLINE_PASTE=$esc\")
		}
		# 空 Enter はコマンドを実行しないので送らない（空の出力範囲を作らない）
		if ($line -and $line.Trim()) {
			[Console]::Write("$([char]27)]133;C$([char]27)\")
		}
		$line
	}
}
$global:__WezTermWrappedReadLine = if (Test-Path Function:\PSConsoleHostReadLine) { $function:PSConsoleHostReadLine }
