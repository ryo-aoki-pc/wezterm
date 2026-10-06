"""実 WezTerm/ConPTY で隔離した Starship 比較を実行する。ユーザー設定は変更しない。"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
OUT = HERE / 'live-results'
WEZTERM = Path(r'C:\Program Files\WezTerm\wezterm.exe')
GUI = WEZTERM.with_name('wezterm-gui.exe')
BASH = r'C:\Program Files\Git\bin\bash.exe'
PWSH = r'C:\Users\r-aoki\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
ANSI = re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]')
parser = argparse.ArgumentParser()
parser.add_argument('--pid', type=int)
parser.add_argument('--fix', action='store_true', help='修正後の結果を別ディレクトリへ保存')
args = parser.parse_args()
if args.fix:
    OUT = HERE / 'fix-results' / 'live'
OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'cache').mkdir(exist_ok=True)
proc = None
if args.pid:
    pid = args.pid
else:
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    gui_env = os.environ.copy()
    gui_env['WEZTERM_STARSHIP_TEST_OUTPUT'] = str(OUT)
    proc = subprocess.Popen([str(GUI), '--config-file', str(HERE / 'live-config.lua'),
        'start', '--always-new-process', '--no-auto-connect', '--class', 'codex-starship-test',
        '--cwd', str(ROOT), '--', BASH, '--noprofile', '--rcfile',
        str(HERE / 'live-bash-baseline.rc'), '-i'], startupinfo=startup, env=gui_env,
        stdout=(OUT / 'gui.stdout.log').open('w'), stderr=(OUT / 'gui.stderr.log').open('w'))
    pid = proc.pid
env = os.environ.copy()
env['WEZTERM_UNIX_SOCKET'] = str(Path(os.environ['USERPROFILE']) / '.local/share/wezterm' / f'gui-sock-{pid}')

def cli(*argv, data=None):
    cp = subprocess.run([str(WEZTERM), 'cli', '--no-auto-start', *map(str, argv)],
        input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env, timeout=15)
    if cp.returncode:
        raise RuntimeError(cp.stderr.decode('utf-8', errors='replace'))
    return cp.stdout.decode('utf-8', errors='replace')

def send(pane, command, wait=0.9):
    cli('send-text', '--pane-id', pane, '--no-paste', data=(command + '\r').encode('utf-8'))
    time.sleep(wait)

records = []
def snapshot(pane, name, action=None):
    cli('activate-pane', '--pane-id', pane)
    # ペイン切替・寸法変更による ConPTY/readline の再描画が終わってから観測する。
    time.sleep(0.4)
    req = {'id': name, 'token': str(time.time_ns()), 'pane_id': pane, 'action': action}
    target = OUT / f'{name}.json'
    if target.exists(): target.unlink()
    (OUT / 'request.json').write_text(json.dumps(req), encoding='utf-8')
    for _ in range(60):
        if target.exists():
            try:
                value = json.loads(target.read_text(encoding='utf-8'))
                break
            except json.JSONDecodeError:
                pass
        time.sleep(0.1)
    else:
        raise RuntimeError(f'計測タイムアウト: {name}')
    if 'error' in value: raise RuntimeError(value['error'])
    value['copy_status_plain'] = ANSI.sub('', value['copy_status'])
    text = cli('get-text', '--pane-id', pane, '--start-line', -300)
    (OUT / f'{name}.txt').write_text(text, encoding='utf-8')
    value['pane_text'] = text
    value['cli_state'] = json.loads(cli('list', '--format', 'json'))
    records.append(value)
    print(json.dumps({'case': name, 'types': sorted(set(z['semantic_type'] for z in value['zones'])),
        'copied': value['copied'], 'status': value['copy_status_plain'],
        'cwd': value['cwd'], 'key_table': value['key_table']}, ensure_ascii=False), flush=True)
    if action:
        # CopyMode.Close の overlay 解除は非同期。次の CLI 操作まで待つ。
        time.sleep(0.5)
    return value

panes = []
try:
    for _ in range(80):
        try:
            listing = json.loads(cli('list', '--format', 'json'))
            if listing: break
        except Exception: pass
        time.sleep(0.1)
    baseline = listing[0]['pane_id']
    panes.append(baseline)
    send(baseline, "printf 'BASE_OUTPUT\\n'")
    snapshot(baseline, 'baseline-output')
    # 同じペインでテーマを後から初期化し、過去の Input 範囲が残る場合も確認する。
    send(baseline, 'eval "$(starship init bash)"; . "$WEZTERM_SHELL_INTEGRATION"')
    send(baseline, "printf 'AFTER_THEME_OUTPUT\\n'")
    snapshot(baseline, 'baseline-then-starship')
    star = int(cli('spawn', '--window-id', listing[0]['window_id'], '--cwd', ROOT, '--',
        BASH, '--noprofile', '--rcfile', HERE / 'live-bash-starship.rc', '-i').strip())
    panes.append(star)
    time.sleep(1.5)
    send(star, "printf 'STAR_OUTPUT\\n'")
    snapshot(star, 'starship-output')
    send(star, 'false')
    snapshot(star, 'starship-failure')
    special = HERE / 'live-results' / '空 白#%'
    special.mkdir(exist_ok=True)
    send(star, "cd '" + special.as_posix() + "'")
    snapshot(star, 'starship-cwd')
    split = int(cli('split-pane', '--pane-id', star, '--right', '--', BASH,
        '--noprofile', '--rcfile', HERE / 'live-bash-starship.rc', '-i').strip())
    panes.append(split)
    time.sleep(1.2)
    snapshot(split, 'starship-split-cwd')
    snapshot(split, 'starship-resize-mode', 'resize')
    snapshot(split, 'starship-copy-mode', 'copy-mode')
    cli('zoom-pane', '--pane-id', split, '--zoom')
    zoomed = json.loads(cli('list', '--format', 'json'))
    (OUT / 'zoomed.json').write_text(json.dumps(zoomed, ensure_ascii=False, indent=2), encoding='utf-8')
    cli('zoom-pane', '--pane-id', split, '--unzoom')
    cli('activate-pane', '--pane-id', star)
    time.sleep(0.8)
    send(star, 'sleep 2.2; false', wait=3.5)
    snapshot(star, 'starship-notification')
    send(star, "printf 'LINE_%s\\n' {1..70}")
    snapshot(star, 'starship-prompt-jump', 'prompt')
    # Starship なしの比較ペイン。十分なスクロールバックを作り同じ action を実行する。
    base2 = int(cli('spawn', '--window-id', listing[0]['window_id'], '--cwd', ROOT, '--',
        BASH, '--noprofile', '--rcfile', HERE / 'live-bash-baseline.rc', '-i').strip())
    panes.append(base2)
    time.sleep(0.8)
    send(base2, "printf 'LINE_%s\\n' {1..70}")
    snapshot(base2, 'baseline-prompt-jump', 'prompt')
    for label, shell in [('pwsh', PWSH), ('windows-powershell', r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe')]:
        pane = int(cli('spawn', '--window-id', listing[0]['window_id'], '--cwd', ROOT, '--',
            shell, '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-NoExit', '-File', HERE / 'live-powershell.ps1').strip())
        panes.append(pane)
        time.sleep(2)
        send(pane, "Write-Output 'PS_OUTPUT'", 1)
        snapshot(pane, label + '-output')
        send(pane, 'cmd /c exit 7', 1)
        snapshot(pane, label + '-native-failure')
        send(pane, "Write-Error 'STARSHIP_TEST_ERROR'", 1)
        snapshot(pane, label + '-cmdlet-failure')
        send(pane, '', 0.6)
        snapshot(pane, label + '-empty-enter')
        send(pane, 'Start-Sleep -Seconds 2', 3.2)
        snapshot(pane, label + '-notification')
        send(pane, "Get-History -Count 2 | Select-Object Id,CommandLine,@{n='Seconds';e={($_.EndExecutionTime-$_.StartExecutionTime).TotalSeconds}} | ConvertTo-Json -Compress; Write-Output ('THRESHOLD=' + $env:WEZTERM_NOTIFY_AFTER + ';NOTIFIED=' + $global:__WezTermNotifiedId)", 1)
        snapshot(pane, label + '-history-diagnostic')
finally:
    (OUT / 'summary.json').write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding='utf-8')
    for pane in panes:
        try: cli('kill-pane', '--pane-id', pane)
        except Exception: pass
    if proc:
        try: proc.wait(timeout=8)
        except subprocess.TimeoutExpired: proc.terminate()
