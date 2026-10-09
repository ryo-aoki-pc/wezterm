"""SSH 先の Starship を実 WezTerm ペインで比較する。既存設定は変更しない。

ssh-check.py --prepare-only --keep-temp の後、python -X utf8 tests/starship/ssh-live-run.py。
リモートの一時配置は ssh-check.py --cleanup で除去する。
"""
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
DEPLOYED = '--deployed' in sys.argv[1:]
FIX = '--fix' in sys.argv[1:] or DEPLOYED
OUT = HERE / ('ssh-fix-results' if FIX else 'ssh-results') / ('deployed-live' if DEPLOYED else 'live')
WEZTERM = Path(r'C:\Program Files\WezTerm\wezterm.exe')
BASH = r'C:\Program Files\Git\bin\bash.exe'
SSH = r'C:\Windows\System32\OpenSSH\ssh.exe'
ANSI = re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]')
OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'cache').mkdir(exist_ok=True)
prepared = json.loads((OUT.parent / 'prepared.json').read_text(encoding='utf-8'))
print(json.dumps({'prepared_type': type(prepared).__name__}), flush=True)
if isinstance(prepared, list):
    prepared = next(p for p in prepared if p['host'] == 'kawasaki-pi')
if 'hosts' in prepared:
    prepared = prepared['hosts']['kawasaki-pi']
host = prepared.get('host', 'kawasaki-pi')
remote_dir = prepared['remote_tempdir']
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 0
gui_env = os.environ.copy()
gui_env['WEZTERM_STARSHIP_TEST_OUTPUT'] = str(OUT)
proc = subprocess.Popen([str(WEZTERM.with_name('wezterm-gui.exe')), '--config-file',
    str(HERE / 'live-config.lua'), 'start', '--always-new-process', '--no-auto-connect',
    '--class', 'codex-ssh-starship-test', '--cwd', str(ROOT), '--', BASH,
    '--noprofile', '--rcfile', str(HERE / 'live-bash-starship.rc'), '-i'],
    startupinfo=startup, env=gui_env, stdout=(OUT / 'gui.stdout.log').open('w'),
    stderr=(OUT / 'gui.stderr.log').open('w'))
env = os.environ.copy()
env['WEZTERM_UNIX_SOCKET'] = str(Path(os.environ['USERPROFILE']) /
    '.local/share/wezterm' / f'gui-sock-{proc.pid}')

def cli(*args, data=None):
    r = subprocess.run([str(WEZTERM), 'cli', '--no-auto-start', *map(str, args)],
        input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env, timeout=20)
    if r.returncode:
        raise RuntimeError(r.stderr.decode('utf-8', 'replace'))
    return r.stdout.decode('utf-8', 'replace')

def send(pane, command, wait=1.0):
    cli('send-text', '--pane-id', pane, '--no-paste', data=(command + '\r').encode())
    time.sleep(wait)

records, panes = [], []
def snapshot(pane, name, action=None):
    cli('activate-pane', '--pane-id', pane)
    time.sleep(0.4)
    target = OUT / (name + '.json')
    if target.exists(): target.unlink()
    request = {'id': name, 'token': str(time.time_ns()), 'pane_id': pane, 'action': action}
    (OUT / 'request.json').write_text(json.dumps(request), encoding='utf-8')
    for _ in range(100):
        if target.exists():
            try:
                result = json.loads(target.read_text(encoding='utf-8'))
                break
            except json.JSONDecodeError: pass
        time.sleep(0.1)
    else: raise RuntimeError('snapshot timeout: ' + name)
    if 'error' in result: raise RuntimeError(result['error'])
    result['copy_status_plain'] = ANSI.sub('', result['copy_status'])
    result['pane_text'] = cli('get-text', '--pane-id', pane, '--start-line', -300)
    result['cli_state'] = json.loads(cli('list', '--format', 'json'))
    (OUT / (name + '.txt')).write_text(result['pane_text'], encoding='utf-8')
    records.append(result)
    print(json.dumps({'id': name, 'copied': result['copied'],
        'status': result['copy_status_plain'], 'running': result['running_program'],
        'cwd': result['cwd'], 'tab': result.get('formatted_tab'), 'vars': result['vars']},
        ensure_ascii=False), flush=True)
    if action: time.sleep(0.5)
    return result

options = ['-tt', '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
    '-o', 'ConnectTimeout=8', host]
rc_command = lambda name: 'bash --noprofile --rcfile ' + shlex.quote(remote_dir + '/' + name + '/test.rc') + ' -i'
cases = [
    ('login-bash', None, False),
    ('official-bash', 'env TERM_PROGRAM=WezTerm HISTFILE=/dev/null bash -il', False),
    ('worktree-bash', rc_command('worktree-recommended'), False),
    ('starship-only-bash', rc_command('starship-only'), False),
    ('login-native', None, True),
    ('worktree-native', rc_command('worktree-recommended'), True),
]
if FIX:
    # 通常のユーザープロファイルを読み、統合のパスだけ一時版へ向ける。
    # TERM_PROGRAM 未転送の実際の SSH と同じ条件で公式統合との共存を確認する。
    login_fixed = ('env HISTFILE=/dev/null WEZTERM_SHELL_INTEGRATION=' +
        shlex.quote(remote_dir + '/integration.sh') + ' bash -il')
    # prepare 時の本配置を同じホスト内で複製した控えと比較する。
    login_previous = ('env HISTFILE=/dev/null WEZTERM_SHELL_INTEGRATION=' +
        shlex.quote(prepared['production_snapshot']) + ' bash -il') if prepared.get('production_snapshot') else None
    cases = [
        ('fixed-login-bash', login_fixed, False),
        ('fixed-login-native', login_fixed, True),
        ('fixed-official-bash', rc_command('official-worktree'), False),
        ('worktree-bash', rc_command('worktree-recommended'), False),
        ('worktree-native', rc_command('worktree-recommended'), True),
        ('login-bash', login_previous, False),
        ('login-native', login_previous, True),
    ]
if DEPLOYED:
    # 配置反映後はパス指定の上書きも付けず、実際の通常 SSH を確認する。
    cases = [('fixed-login-bash', None, False), ('fixed-login-native', None, True)]
if FIX:
    (OUT / 'fixture.json').write_text(json.dumps({
        'source_sha256': prepared.get('source_sha256'),
        'production_sha256': prepared.get('production_sha256'),
        'production_origin': prepared.get('production_origin'),
        'production_snapshot': prepared.get('production_snapshot'),
        'deployed': DEPLOYED,
    }, ensure_ascii=False, indent=2), encoding='utf-8')
try:
    for _ in range(90):
        try:
            listing = json.loads(cli('list', '--format', 'json'))
            if listing: break
        except RuntimeError: pass
        time.sleep(0.1)
    else: raise RuntimeError('GUI initialization timeout')
    window = listing[0]['window_id']
    control = listing[0]['pane_id']
    panes.append(control)
    time.sleep(1.5)
    snapshot(control, 'local-initial')
    for label, remote_command, native in cases:
        args = [SSH, *options] + ([remote_command] if remote_command else [])
        if native:
            pane = int(cli('spawn', '--window-id', window, '--cwd', ROOT, '--', *args).strip())
            panes.append(pane)
        else:
            pane = int(cli('spawn', '--window-id', window, '--cwd', ROOT, '--', BASH,
                '--noprofile', '--rcfile', HERE / 'live-bash-starship.rc', '-i').strip())
            panes.append(pane)
            time.sleep(1.2)
            # Git Bash からは ssh という先頭語で起動し、WEZTERM_PROG 判定も実測する。
            args[0] = 'ssh'
            send(pane, shlex.join(args), wait=2.5)
        time.sleep(2.5)
        # 通常ログインも、最初の試験コマンドから履歴をファイルへ保存しない。
        send(pane, "HISTFILE=/dev/null; HISTCONTROL=; WEZTERM_NOTIFY_AFTER=1; "
            "__ssh_test_state() { printf '__SSH_STATE__ status=%s pipeline=%s bp=%s term=%s history=%s\\n' "
            '"${STARSHIP_CMD_STATUS-NA}" "${STARSHIP_PIPE_STATUS[*]-NA}" "${BP_PIPESTATUS[*]-NA}" '
            '"${TERM_PROGRAM-unset}" "$HISTFILE"; }; __ssh_test_state', 1.5)
        snapshot(pane, label + '-initial')
        marker = 'REMOTE_' + label.upper().replace('-', '_') + '_OUTPUT'
        send(pane, "printf '" + marker + "\\n'")
        snapshot(pane, label + '-output')
        send(pane, 'false')
        send(pane, '__ssh_test_state')
        snapshot(pane, label + '-failure-state')
        send(pane, 'false | true')
        send(pane, '__ssh_test_state')
        snapshot(pane, label + '-pipeline-state')
        send(pane, 'sleep 2.2; false', wait=0.5)
        snapshot(pane, label + '-running')
        time.sleep(2.5)
        snapshot(pane, label + '-notification')
        send(pane, "printf 'SSH_LINE_%s\\n' {1..70}")
        snapshot(pane, label + '-jump', 'prompt')
        send(pane, '', 0.6)
        snapshot(pane, label + '-empty-enter')
        if FIX and label.startswith('fixed-'):
            send(pane, "printf '%s\\n' 'MULTILINE_START\nMULTILINE_END'")
            snapshot(pane, label + '-multiline')
            send(pane, "(printf 'SUBSHELL_OUTPUT\\n'; exit 7)")
            snapshot(pane, label + '-subshell')
            send(pane, '__ssh_test_state')
            snapshot(pane, label + '-subshell-state')
            send(pane, 'eval "$(starship init bash)"')
            send(pane, "printf 'REINIT_OUTPUT\\n'")
            snapshot(pane, label + '-reinit')
            send(pane, '. "$WEZTERM_SHELL_INTEGRATION"; . "$WEZTERM_SHELL_INTEGRATION"')
            send(pane, "printf 'RESOURCE_OUTPUT\\n'")
            snapshot(pane, label + '-resource')
        if not native:
            send(pane, 'exit', 1.5)
            send(pane, "printf 'LOCAL_RETURN_OUTPUT\\n'")
            snapshot(pane, label + '-local-return')
finally:
    (OUT / 'summary.json').write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding='utf-8')
    for pane in panes:
        try: cli('kill-pane', '--pane-id', pane)
        except Exception: pass
    try: proc.wait(timeout=8)
    except subprocess.TimeoutExpired: proc.terminate()
