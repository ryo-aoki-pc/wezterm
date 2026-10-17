"""隔離した Windows WezTerm/ConPTY で実際の貼り付け action を検証する。"""
import argparse
import ctypes
from ctypes import wintypes
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
WEZTERM = Path(r'C:\Program Files\WezTerm\wezterm.exe')
GUI = WEZTERM.with_name('wezterm-gui.exe')
PS5 = Path(os.environ['SystemRoot']) / 'System32/WindowsPowerShell/v1.0/powershell.exe'


class TestDesktop:
    """新規 desktop に GUI を起動し、利用者の画面へ一度も表示しない。"""
    def __init__(self):
        self.user = ctypes.WinDLL('user32', use_last_error=True)
        self.user.GetProcessWindowStation.restype = wintypes.HANDLE
        self.user.GetThreadDesktop.argtypes = [wintypes.DWORD]
        self.user.GetThreadDesktop.restype = wintypes.HANDLE
        self.user.CreateDesktopW.argtypes = [wintypes.LPCWSTR, ctypes.c_void_p, ctypes.c_void_p,
                                            wintypes.DWORD, wintypes.DWORD, ctypes.c_void_p]
        self.user.CreateDesktopW.restype = wintypes.HANDLE
        self.user.SetThreadDesktop.argtypes = [wintypes.HANDLE]
        self.user.CloseDesktop.argtypes = [wintypes.HANDLE]
        self.user.GetUserObjectInformationW.argtypes = [wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p,
                                                       wintypes.DWORD, ctypes.POINTER(wintypes.DWORD)]
        station = self.user.GetProcessWindowStation()
        self.original_desktop = self.user.GetThreadDesktop(ctypes.WinDLL('kernel32').GetCurrentThreadId())
        station_name = ctypes.create_unicode_buffer(256)
        needed = wintypes.DWORD()
        if not self.user.GetUserObjectInformationW(station, 2, station_name, ctypes.sizeof(station_name), ctypes.byref(needed)):
            raise ctypes.WinError(ctypes.get_last_error())
        self.name = station_name.value
        self.desktop_name = f'codex-paste-{os.getpid()}-{time.time_ns()}'
        self.desktop = self.user.CreateDesktopW(self.desktop_name, None, None, 0, 0x1ff, None)
        if not self.desktop or not self.user.SetThreadDesktop(self.desktop):
            raise ctypes.WinError(ctypes.get_last_error())
        self.path = self.name + '\\' + self.desktop_name

    def close(self):
        self.user.SetThreadDesktop(self.original_desktop)
        self.user.CloseDesktop(self.desktop)


def read_json(path, timeout=10):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            return json.loads(path.read_text(encoding='utf-8-sig'))
        except (FileNotFoundError, json.JSONDecodeError):
            time.sleep(0.03)
    raise TimeoutError(f'試験ファイル待機: {path.name}')


def write_json(path, value):
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(value, ensure_ascii=False), encoding='utf-8')
    # Windows では Lua が短時間読む間、置換用の共有権限がなく競合することがある。
    for attempt in range(100):
        try:
            temporary.replace(path)
            return
        except PermissionError:
            if attempt == 99:
                raise
            time.sleep(0.01)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--quick', action='store_true', help='各シェルで基本 CRLF ケースだけを試す')
    parser.add_argument('--shared-clipboard', action='store_true',
                        help='標準クリップボードを試験コードで置換する。元データは読まないため復元しない')
    parser.add_argument('--double-cr', action='store_true', help='block の CRCRLF を追加比較する')
    parser.add_argument('--pwsh', metavar='<パス>', default=None,
                        help='PowerShell 7 の実行ファイル。既定は PATH の pwsh')
    args = parser.parse_args()
    if os.name != 'nt':
        parser.error('Windows の GUI/ConPTY 検証専用です')
    if not args.shared_clipboard:
        parser.error('試験コードでクリップボードを置換するには --shared-clipboard を明示してください')
    pwsh = shutil.which(args.pwsh or 'pwsh')
    if not pwsh:
        parser.error('PowerShell 7 の実行ファイルが見つかりません。PATH に pwsh を置くか、--pwsh で渡してください')
    pwsh = Path(pwsh)
    out = HERE / 'results' / time.strftime('%Y%m%d-%H%M%S')
    out.mkdir(parents=True)
    desktop = TestDesktop()
    proc = None
    panes = []
    records = []
    summary = {'results': str(out), 'quick': args.quick, 'double_cr': args.double_cr,
               'cases': records, 'shells': {}, 'markers': [], 'reloads': []}
    env = os.environ.copy()
    env['WEZTERM_PASTE_TEST_OUTPUT'] = str(out)
    # 履歴やプロファイルから個人情報を取り込まず、検証専用シェルだけを起動する。
    def shell_command(executable, label):
        return [str(executable), '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass',
                '-NoExit', '-File', str(HERE / 'live-powershell.ps1'), '-Label', label]
    try:
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = 0
        startup.lpDesktop = desktop.path
        with (out / 'gui.log').open('wb') as log:
            proc = subprocess.Popen([str(GUI), '--config-file', str(HERE / 'live-config.lua'),
                'start', '--always-new-process', '--no-auto-connect', '--class', 'codex-paste-test',
                '--cwd', str(ROOT), '--', *shell_command(PS5, 'ps5')], env=env,
                startupinfo=startup, creationflags=subprocess.CREATE_NO_WINDOW, stdout=log, stderr=log)
        env['WEZTERM_UNIX_SOCKET'] = str(Path(os.environ['USERPROFILE']) / '.local/share/wezterm' / f'gui-sock-{proc.pid}')
        def cli(*arguments, data=None):
            result = subprocess.run([str(WEZTERM), 'cli', '--no-auto-start', '--class', 'codex-paste-test',
                *map(str, arguments)], env=env, input=data, capture_output=True, timeout=15,
                creationflags=subprocess.CREATE_NO_WINDOW, startupinfo=startup)
            if result.returncode:
                raise RuntimeError(result.stderr.decode('utf-8', errors='replace'))
            return result.stdout.decode('utf-8', errors='replace')
        deadline = time.monotonic() + 15
        listing = None
        while time.monotonic() < deadline:
            try:
                listing = json.loads(cli('list', '--format', 'json'))
                if listing:
                    break
            except RuntimeError:
                pass
            if proc.poll() is not None:
                raise RuntimeError('専用 GUI が終了しました。gui.log を確認してください')
            time.sleep(0.1)
        if not listing:
            raise TimeoutError('専用 GUI の起動待機')
        panes.append(listing[0]['pane_id'])
        summary['wezterm'] = subprocess.check_output([str(WEZTERM), '--version'], text=True).strip()
        summary['sources'] = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in [ROOT / 'lua/actions.lua', ROOT / 'lua/bindings.lua', ROOT / 'shell/wezterm.ps1',
                         HERE / 'live-config.lua', HERE / 'live-powershell.ps1', HERE / 'live-run.py']}
        serial = 0
        def request(pane, operation, **extra):
            nonlocal serial
            serial += 1
            identifier = f'{serial:05d}-{operation}'
            write_json(out / 'request.json', {'id': identifier, 'token': str(time.time_ns()),
                'pane_id': pane, 'operation': operation, **extra})
            result = read_json(out / f'{identifier}.action.json')
            if 'error' in result:
                raise RuntimeError(result['error'])
            return result
        def probe(pane):
            identifier = f'probe-{time.time_ns()}'
            write_json(out / 'probe-request.json', {'id': identifier})
            request(pane, 'probe')
            return read_json(out / f'{identifier}.buffer.json')
        def wait_marker(pane, wanted='1', timeout=5):
            deadline = time.monotonic() + timeout
            while time.monotonic() < deadline:
                value = request(pane, 'snapshot')
                if value['marker'] == wanted:
                    return value
            raise TimeoutError(f'入力待機マーカー {wanted!r}')
        def control(pane, command):
            cli('send-text', '--pane-id', pane, '--no-paste', data=(command + '\r').encode('utf-8'))
            time.sleep(0.15)
            wait_marker(pane)
        base = "$global:PasteProbeExecuted += 1\n$global:PasteProbeValue = 'alpha'"
        fixtures = {
            'simple': (base, 'alpha'),
            'block': ('& {\n' + base + '\n}', 'alpha'),
            'blank': (base.replace('\n', '\n\n'), 'alpha'),
            'japanese': (base.replace('alpha', '日本語'), '日本語'),
            'here-string': ("$global:PasteProbeValue = @'\n一\n\n二\n'@\n$global:PasteProbeExecuted += 1", '一\n\n二'),
            'trailing': (base + '\n', 'alpha'),
        }
        routes = ['baseline', 'shared', 'right', 'right-reporting', 'key']
        for label, executable in [('ps5', PS5), ('ps7', pwsh)]:
            if label == 'ps5':
                pane = panes[0]
            else:
                pane = int(cli('spawn', '--window-id', listing[0]['window_id'], '--cwd', ROOT, '--',
                    *shell_command(executable, label)).strip())
                panes.append(pane)
            cli('activate-pane', '--pane-id', pane)
            summary['shells'][label] = read_json(out / f'{label}.ready.json')
            wait_marker(pane)
            selected = ({'block': fixtures['block']} if args.double_cr else
                        {name: fixtures[name] for name in ('simple', 'block')} if args.quick else fixtures)
            for shape, (source, expected_value) in selected.items():
                for ending in (['CRCRLF'] if args.double_cr else ['CRLF'] if args.quick else ['LF', 'CRLF']):
                    separator = {'LF': '\n', 'CRLF': '\r\n', 'CRCRLF': '\r\r\n'}[ending]
                    text = source.replace('\n', separator)
                    for route in routes:
                        request(pane, 'cancel')
                        time.sleep(0.1)
                        control(pane, "$global:PasteProbeExecuted = 0; $global:PasteProbeValue = ''")
                        ready = wait_marker(pane)
                        request(pane, 'paste', route=route, text=text)
                        # ConPTY と PSReadLine に全入力が届いてから専用ハンドラーで採取する。
                        time.sleep(0.18)
                        before = probe(pane)
                        screen_before = None
                        if shape == 'block' or args.quick:
                            screen_before = cli('get-text', '--pane-id', pane, '--start-line', -40)
                            (out / f'{label}-{shape}-{ending}-{route}.screen.txt').write_text(screen_before, encoding='utf-8')
                        request(pane, 'enter')
                        time.sleep(0.12)
                        wait_marker(pane)
                        after = probe(pane)
                        passed = (before['buffer'] == source and before['executed'] == 0
                                  and after['executed'] == 1 and after['value'] == expected_value
                                  and after['buffer'] == '')
                        record = {'shell': label, 'shape': shape, 'ending': ending, 'route': route,
                            'source': text, 'before': before, 'after': after, 'ready': ready,
                            'screen_before': screen_before,
                            'passed': passed, 'baseline': route == 'baseline'}
                        records.append(record)
                        print(json.dumps({'shell': label, 'shape': shape, 'ending': ending,
                            'route': route, 'passed': passed, 'before_executed': before['executed'],
                            'before_lines': before['buffer'].count('\n') + 1}, ensure_ascii=False), flush=True)
            request(pane, 'cancel')
            time.sleep(0.1)
            cli('send-text', '--pane-id', pane, '--no-paste', data=b'Start-Sleep -Seconds 2\r')
            time.sleep(0.15)
            running = wait_marker(pane, '', timeout=1)
            waiting = wait_marker(pane, '1')
            summary['markers'].append({'shell': label, 'running': running, 'waiting': waiting,
                                       'passed': running['marker'] == '' and waiting['marker'] == '1'})
            # 統合を読み直しても F11 の観測 handler と入力待機・Paste が残ることを確かめる。
            integration = (ROOT / 'shell/wezterm.ps1').as_posix().replace("'", "''")
            control(pane, ". '" + integration + "'")
            control(pane, "$global:PasteProbeExecuted = 0; $global:PasteProbeValue = ''")
            reloaded_ready = wait_marker(pane)
            reload_source = fixtures['block'][0]
            reload_route = 'right' if label == 'ps5' else 'key'
            request(pane, 'paste', route=reload_route, text=reload_source.replace('\n', '\r\n'))
            time.sleep(0.18)
            reload_before = probe(pane)
            request(pane, 'enter')
            time.sleep(0.12)
            wait_marker(pane)
            reload_after = probe(pane)
            reload_passed = (reloaded_ready['marker'] == '1' and reload_before['buffer'] == reload_source
                             and reload_before['executed'] == 0 and reload_after['executed'] == 1
                             and reload_after['value'] == 'alpha' and reload_after['buffer'] == '')
            summary['reloads'].append({'shell': label, 'route': reload_route, 'before': reload_before,
                                      'after': reload_after, 'ready': reloaded_ready, 'passed': reload_passed})
        summary['fixed_passed'] = sum(case['passed'] for case in records if not case['baseline'])
        summary['fixed_total'] = sum(not case['baseline'] for case in records)
        summary['baseline_preserved'] = sum(case['passed'] for case in records if case['baseline'])
        summary['baseline_total'] = sum(case['baseline'] for case in records)
        summary['passed'] = (summary['fixed_passed'] == summary['fixed_total']
                             and all(marker['passed'] for marker in summary['markers'])
                             and all(reload['passed'] for reload in summary['reloads']))
    except Exception as error:
        summary['error'] = str(error)
        summary['passed'] = False
        raise
    finally:
        if proc is not None:
            for pane in panes:
                try:
                    cli('kill-pane', '--pane-id', pane)
                except Exception:
                    pass
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.terminate()
                proc.wait(timeout=5)
        desktop.close()
        summary['clipboard_isolation'] = 'shared-test-code-only'
        summary['clipboard_restored'] = False
        write_json(out / 'summary.json', summary)
        print(json.dumps({key: value for key, value in summary.items()
            if key not in ('cases', 'sources', 'markers', 'reloads')}, ensure_ascii=False), flush=True)
    return 0 if summary['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
