"""SSH 先の Bash + Starship を一時 rc と実 PTY で検査する。

python tests/starship/ssh-check.py kawasaki-pi --prepare-only
python tests/starship/ssh-check.py kawasaki-pi --reuse --keep-temp
python tests/starship/ssh-check.py kawasaki-pi --cleanup
python tests/starship/ssh-check.py kawasaki-pi --fix --prepare-only
python tests/starship/ssh-check.py kawasaki-pi --fix --reuse --keep-temp

準備した rc 一覧は ssh-results/prepared.json に保存し、実 WezTerm ペインでも
使える。既存プロファイルは変更しない。接続・一時配置は実行時だけ行う。
--fix は ssh-fix-results/ を使い、修正前の記録を上書きしない。
"""
from __future__ import annotations

import argparse
import base64
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import re
import shlex
import subprocess
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = HERE / "ssh-results"
MANIFEST = OUT / "prepared.json"
OSC = re.compile(rb"\x1b\]([^\x07\x1b]*)(?:\x07|\x1b\\)")


@dataclass(frozen=True)
class Case:
    name: str
    order: str
    term: str = "WezTerm"
    noediting: bool = False
    nounset: bool = False
    notifications: str = ""
    user_hooks: bool = False
    late_worktree: bool = False
    pc_builder: bool = False
    dispatcher_removed: bool = False


CASES = [
    Case("starship-only", "s"),
    Case("worktree-recommended", "sw"),
    Case("worktree-noediting", "sw", noediting=True),
    Case("worktree-nounset", "sw", nounset=True),
    Case("worktree-unset-term", "sw", term="unset"),
    Case("worktree-tmux-term", "sw", term="tmux"),
    Case("worktree-forwarded-term", "sw", term="forwarded"),
    Case("worktree-reverse", "ws"),
    Case("production-recommended", "sp"),
    Case("official-starship-only", "fs"),
    Case("official-worktree", "fsw"),
    Case("official-production", "fsp"),
]
BASE_CASES = CASES
FIX_CASES = [
    *[case for case in BASE_CASES if case.name != 'official-worktree'],
    Case('official-worktree', 'fswz', notifications='history'),
    Case('official-worktree-unset-term', 'fswz', term='unset', notifications='simple'),
    Case('official-worktree-forwarded-term', 'fswz', term='forwarded'),
    Case('official-worktree-noediting', 'fswz', noediting=True, notifications='simple'),
    Case('official-worktree-nounset', 'fswz', nounset=True, notifications='simple'),
    Case('official-worktree-userhooks', 'fusvwz', user_hooks=True, notifications='simple'),
    Case('official-worktree-legacy', 'fspwz'),
    Case('official-migrate-running', 'fspz', late_worktree=True, notifications='simple'),
    Case('official-pc-user-ps1', 'fswz', pc_builder=True),
    Case('official-dispatcher-removed', 'fswz', dispatcher_removed=True),
    Case('official-no-starship', 'fwz', notifications='simple'),
]

STATE = r'''__ssh_test_state() {
    printf '\n__SSH_STATE__ label=%s status=%s pipeline=%s duration=%s ps0=%q ps1=%q pc=' "$1" "${STARSHIP_CMD_STATUS-NA}" "${STARSHIP_PIPE_STATUS[*]-NA}" "${STARSHIP_DURATION-NA}" "${PS0-}" "${PS1-}"
    declare -p PROMPT_COMMAND
    printf '__SSH_HOOKS__ label=%s precmd=' "$1"; declare -p precmd_functions 2>/dev/null || :
    printf '__SSH_PREEXECS__ label=%s preexec=' "$1"; declare -p preexec_functions 2>/dev/null || :
}
'''

USER_A = r'''__ssh_user_precmd_a() { local __ssh_st=$?; printf '__USER_PRECMD__a status=%s\n' "$__ssh_st"; return "$__ssh_st"; }
__ssh_user_preexec_a() { local __ssh_st=$?; printf '__USER_PREEXEC__a status=%s command=%s\n' "$__ssh_st" "$1"; return "$__ssh_st"; }
precmd_functions+=(__ssh_user_precmd_a)
preexec_functions+=(__ssh_user_preexec_a)'''
USER_B = r'''__ssh_user_precmd_b() { local __ssh_st=$?; printf '__USER_PRECMD__b status=%s\n' "$__ssh_st"; return "$__ssh_st"; }
__ssh_user_preexec_b() { local __ssh_st=$?; printf '__USER_PREEXEC__b status=%s command=%s\n' "$__ssh_st" "$1"; return "$__ssh_st"; }
precmd_functions+=(__ssh_user_precmd_b)
preexec_functions+=(__ssh_user_preexec_b)'''


def rc_text(case: Case, *, fix=False) -> str:
    # rc は /tmp/wezterm-starship-test.XXXXXXXX/<case>/test.rc に保存する。
    prelude = [
        '__SSH_TMP=${BASH_SOURCE[0]%/*/*}',
        'export TERM=xterm-256color COLUMNS=120 LINES=40 LANG=C.UTF-8',
        'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"',
        'export STARSHIP_CONFIG="$__SSH_TMP/starship.toml"',
        f'export STARSHIP_CACHE="$__SSH_TMP/{case.name}/cache"',
        'export WEZTERM_NOTIFY_AFTER=2',
        '__SSH_WORKTREE="$__SSH_TMP/integration.sh"',
        '__SSH_PRODUCTION="$__SSH_TMP/production.sh"' if fix else '__SSH_PRODUCTION="$HOME/.config/wezterm/shell/wezterm.sh"',
        '__SSH_TEST_PATH="$__SSH_TMP/cwd space#%?日本語"',
        'export WEZTERM_SHELL_INTEGRATION="$__SSH_WORKTREE"',
        'HISTFILE=/dev/null; HISTCONTROL=; HISTIGNORE=',
        "PS1='BASE>'", STATE,
    ]
    if case.term == "unset":
        prelude.append('unset TERM_PROGRAM')
    elif case.term != "forwarded":
        prelude.append(f'export TERM_PROGRAM={shlex.quote(case.term)}')
    prelude.append('printf "__SSH_META__ bash=%s ostype=%s host=%s term=%s production=%s\\n" "$BASH_VERSION" "$OSTYPE" "$HOSTNAME" "${TERM_PROGRAM-unset}" "$__SSH_PRODUCTION"')
    for item in case.order:
        if case.nounset and item == 'w':
            prelude.append('set -u')
        prelude.append({
            "f": '. /etc/profile.d/wezterm.sh',
            "s": 'eval "$(starship init bash)"',
            "w": '. "$__SSH_WORKTREE"',
            "p": '. "$__SSH_PRODUCTION"',
            "z": 'eval "$(zoxide init bash)"',
            "u": USER_A,
            "v": USER_B,
        }[item])
    if case.nounset:
        prelude.append('set -u')
    return "\n".join(prelude) + "\n"


def commands(case: Case) -> list[tuple[str, int]]:
    result = [
        ('__ssh_test_state initial', 0),
        ('false', 1), ('__ssh_test_state false', 0),
        ('(exit 7)', 7), ('__ssh_test_state exit7', 0),
        ('false | true', 0), ('__ssh_test_state pipeline', 0),
        ('set -o pipefail; false | true', 1), ('__ssh_test_state pipefail', 0),
        ('set +o pipefail', 0),
        ("printf '__OUTPUT_BEGIN__\\nalpha\\nbeta\\n__OUTPUT_END__\\n'", 0),
        ('', 0),
    ]
    if case.late_worktree:
        result.insert(0, ('. "$__SSH_WORKTREE"', 0))
    if case.pc_builder:
        result.insert(1, ('''__ssh_rewrite_ps1() { local st=$?; PS1='USER_REBUILT> '; return "$st"; }; PROMPT_COMMAND=("${PROMPT_COMMAND[0]}" __ssh_rewrite_ps1 "${PROMPT_COMMAND[@]:1}"); . "$__SSH_WORKTREE"''', 0))
    if case.dispatcher_removed:
        result.insert(1, ('''PROMPT_COMMAND=(__wz_mouse_off __wezterm_prompt_command); STARSHIP_CMD_STATUS=91; __bp_last_ret_value=92; BP_PIPESTATUS=(93); if __wz_bash_preexec_active; then printf '__SSH_BP_BAD_ACTIVE__\\n'; else printf '__SSH_BP_INACTIVE__\\n'; fi''', 0))
    if "w" in case.order or "p" in case.order:
        source = '$__SSH_WORKTREE' if "w" in case.order or case.late_worktree else '$__SSH_PRODUCTION'
        result += [(f'. "{source}"; . "{source}"', 0),
                   ('false | true', 0), ('__ssh_test_state source_twice', 0)]
        if not case.dispatcher_removed and 's' in case.order:
            result += [('eval "$(starship init bash)"', 0),
                   ('false', 1), ('__ssh_test_state reinit_only', 0),
                   (f'. "{source}"', 0),
                   ('false', 1), ('__ssh_test_state reinitialize', 0)]
    if case.name == "worktree-recommended" or case.notifications == 'history':
        result += [
            ('sleep 2.15', 0), ('__ssh_test_state duration', 0),
            ('sleep 2.15; false', 1),
            ('HISTCONTROL=ignorespace', 0), (' sleep 2.15; false', 1),
            ('HISTCONTROL=ignoredups', 0), ('sleep 2.15', 0), ('sleep 2.15', 0),
            ("HISTCONTROL=; HISTIGNORE='sleep*'", 0), ('sleep 2.15; false', 1),
            ('HISTIGNORE=; set +o history', 0), ('sleep 2.15; false', 1),
            ('set -o history', 0),
            ("printf -v __ssh_long '%199s'; __ssh_long=${__ssh_long// /x}'😀x'; __wezterm_uservar SSH_TEST_LONG \"$__ssh_long\"", 0),
        ]
    elif case.notifications == 'simple':
        result += [('sleep 2.15; false', 1), ('(sleep 2.15; exit 7)', 7), ('', 7)]
    result += [("[[ ab =~ (a) ]]; printf '__REGEX_BEFORE__%s\\n' \"${BASH_REMATCH[1]}\"", 0),
               ("printf '__REGEX_AFTER__%s\\n' \"${BASH_REMATCH[1]}\"", 0),
               ('cd "$__SSH_TEST_PATH"', 0), ('__ssh_test_state cwd', 0),
               ('exit', 0)]
    return result


def ssh_args(args, *, pty=False) -> list[str]:
    return [args.ssh, '-tt' if pty else '-T', '-o', 'BatchMode=yes',
            '-o', 'StrictHostKeyChecking=yes', '-o', 'ConnectTimeout=8', args.host]


def read_manifest() -> dict:
    return json.loads(MANIFEST.read_text(encoding='utf-8')) if MANIFEST.exists() else {'hosts': {}}


def prepare(args) -> dict:
    script = [
        'set -eu', 'umask 077', '__ssh_tmp=$(mktemp -d /tmp/wezterm-starship-test.XXXXXXXX)',
        'case "$__ssh_tmp" in /tmp/wezterm-starship-test.*) ;; *) exit 90 ;; esac',
        'mkdir -p "$__ssh_tmp/cwd space#%?日本語"',
    ]
    files = {'integration.sh': (ROOT / 'shell' / 'wezterm.sh').read_bytes(),
             'starship.toml': (HERE / 'bash-pipeline.toml').read_bytes()}
    # 配置先の現在値を remote 内で複製する。配置前の記録とバックアップは
    # ローカルに保持し、prepare では別のペイロードとして再転送しない。
    production_origin = 'remote-current-copy' if args.fix else 'remote-current'
    for case in CASES:
        script.append(f'mkdir -p "$__ssh_tmp/{case.name}/cache"')
        files[f'{case.name}/test.rc'] = rc_text(case, fix=args.fix).encode('utf-8')
    for name, payload in files.items():
        encoded = base64.b64encode(payload).decode('ascii')
        script.append(f"printf '%s' '{encoded}' | base64 -d > \"$__ssh_tmp/{name}\"")
    if args.fix:
        script.append('if test -r "$HOME/.config/wezterm/shell/wezterm.sh"; then cp -- "$HOME/.config/wezterm/shell/wezterm.sh" "$__ssh_tmp/production.sh"; fi')
    script.append('__ssh_production="$__ssh_tmp/production.sh"' if args.fix else '__ssh_production="$HOME/.config/wezterm/shell/wezterm.sh"')
    script += [
        'printf "__SSH_PREPARED__%s\\n" "$__ssh_tmp"',
        'printf "__SSH_FORWARD_TERM__%s\\n" "${TERM_PROGRAM-unset}"',
        'if test -r "$__ssh_production"; then printf "__SSH_PRODUCTION__yes\\n"; __ssh_prod_hash=$(sha256sum "$__ssh_production"); printf "__SSH_PRODUCTION_SHA__%s\\n" "${__ssh_prod_hash%% *}"; else printf "__SSH_PRODUCTION__no\\n"; fi',
    ]
    run = subprocess.run(ssh_args(args) + ['sh -s'], input=('\n'.join(script) + '\n').encode('utf-8'),
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=45)
    (OUT / f'{args.host}-prepare.txt').write_text(run.stdout.decode('utf-8', 'replace') + '\nSTDERR:\n' + run.stderr.decode('utf-8', 'replace'), encoding='utf-8')
    if run.returncode:
        raise RuntimeError(f'SSH prepare failed ({run.returncode}): {run.stderr.decode("utf-8", "replace")}')
    marker = re.search(rb'__SSH_PREPARED__(/tmp/wezterm-starship-test\.[A-Za-z0-9]+)', run.stdout)
    if not marker:
        raise RuntimeError('Preparation did not return a verified temporary directory')
    temporary = marker[1].decode('ascii')
    term = re.search(rb'__SSH_FORWARD_TERM__([^\r\n]*)', run.stdout)
    production_hash = re.search(rb'__SSH_PRODUCTION_SHA__([0-9a-f]{64})', run.stdout)
    record = {'host': args.host, 'remote_tempdir': temporary, 'ssh': args.ssh, 'fix': args.fix,
              'source_sha256': hashlib.sha256(files['integration.sh']).hexdigest(),
              'forwarded_term_program': term[1].decode('utf-8') if term else 'unset',
              'production_exists': b'__SSH_PRODUCTION__yes' in run.stdout,
              'production_sha256': production_hash[1].decode('ascii') if production_hash else None,
              'production_origin': production_origin,
              'production_snapshot': f'{temporary}/production.sh' if args.fix else None,
              'cases': {case.name: {'rc': f'{temporary}/{case.name}/test.rc',
                                   'noediting': case.noediting, 'order': case.order, 'term': case.term}
                        for case in CASES}}
    manifest = read_manifest()
    manifest['hosts'][args.host] = record
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    return record


def cleanup(args, record) -> None:
    temporary = record['remote_tempdir']
    if not re.fullmatch(r'/tmp/wezterm-starship-test\.[A-Za-z0-9]+', temporary):
        raise RuntimeError('Refusing cleanup outside the verified test temporary directory')
    run = subprocess.run(ssh_args(args) + ['rm -rf -- ' + shlex.quote(temporary)],
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)
    if run.returncode:
        raise RuntimeError('SSH cleanup failed: ' + run.stderr.decode('utf-8', 'replace'))
    record['cleaned_up'] = True
    manifest = read_manifest()
    manifest['hosts'][args.host] = record
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')


def add_missing_cases(args, record) -> dict:
    """実ペインで使用中の一時ファイルは変えず、新しい rc だけ追加する。"""
    missing = [case for case in CASES if case.name not in record['cases']]
    if not missing:
        return record
    temporary = record['remote_tempdir']
    if not re.fullmatch(r'/tmp/wezterm-starship-test\.[A-Za-z0-9]+', temporary):
        raise RuntimeError('Invalid remote test temporary directory')
    script = ['set -eu', 'umask 077', 'test -d ' + shlex.quote(temporary)]
    for case in missing:
        path = f'{temporary}/{case.name}'
        script.append('mkdir -p ' + shlex.quote(path + '/cache'))
        encoded = base64.b64encode(rc_text(case, fix=args.fix).encode('utf-8')).decode('ascii')
        script.append(f"printf '%s' '{encoded}' | base64 -d > {shlex.quote(path + '/test.rc')}")
    run = subprocess.run(ssh_args(args) + ['sh -s'], input=('\n'.join(script) + '\n').encode('utf-8'),
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)
    if run.returncode:
        raise RuntimeError('Adding test rc failed: ' + run.stderr.decode('utf-8', 'replace'))
    for case in missing:
        record['cases'][case.name] = {'rc': f'{temporary}/{case.name}/test.rc',
                                      'noediting': case.noediting, 'order': case.order, 'term': case.term}
    manifest = read_manifest()
    manifest['hosts'][args.host] = record
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    return record


def refresh_source(args, record) -> dict:
    """確認済み /tmp 内のシェル統合だけを新しい作業ツリーへ更新する。"""
    temporary = record['remote_tempdir']
    if not re.fullmatch(r'/tmp/wezterm-starship-test\.[A-Za-z0-9]+', temporary):
        raise RuntimeError('Invalid remote test temporary directory')
    source = (ROOT / 'shell' / 'wezterm.sh').read_bytes()
    encoded = base64.b64encode(source).decode('ascii')
    script = 'test -d ' + shlex.quote(temporary) + f" && printf '%s' '{encoded}' | base64 -d > " + shlex.quote(temporary + '/integration.sh')
    run = subprocess.run(ssh_args(args) + ['sh -s'], input=(script + '\n').encode('utf-8'),
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)
    if run.returncode:
        raise RuntimeError('Source refresh failed: ' + run.stderr.decode('utf-8', 'replace'))
    record['source_sha256'] = hashlib.sha256(source).hexdigest()
    manifest = read_manifest()
    manifest['hosts'][args.host] = record
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    return record


def run_case(args, prepared: dict, case: Case) -> dict:
    directory = OUT / args.host / case.name
    directory.mkdir(parents=True, exist_ok=True)
    if 'p' in case.order and not prepared['production_exists']:
        return {'name': case.name, 'skipped': 'remote production integration does not exist', 'checks': []}
    remote = 'bash --noprofile --rcfile ' + shlex.quote(prepared['cases'][case.name]['rc'])
    remote += ' --noediting' if case.noediting else ''
    remote += ' -i'
    script = commands(case)
    run = subprocess.run(ssh_args(args, pty=True) + [remote],
                         input=('\n'.join(command for command, _ in script) + '\n').encode('utf-8'),
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
    raw = run.stdout
    (directory / 'session.raw').write_bytes(raw)
    output = raw.decode('utf-8', 'replace')
    (directory / 'session.txt').write_text(output.replace('\x1b', '<ESC>').replace('\x07', '<BEL>'), encoding='utf-8')
    records = []
    for match in OSC.finditer(raw):
        value = match[1].decode('utf-8', 'replace')
        if 'SetUserVar=' in value:
            key, encoded = value.split('SetUserVar=', 1)[1].split('=', 1)
            try:
                records.append({'var': key, 'value': base64.b64decode(encoded).decode('utf-8', 'strict')})
            except (ValueError, UnicodeError) as error:
                records.append({'var': key, 'decode_error': str(error)})
        else:
            records.append(value)
    meta = re.search(r'__SSH_META__ bash=(\S+) ostype=(\S+) host=(\S+) term=(\S+) production=(\S+)', output)
    metadata = dict(zip(('bash', 'ostype', 'host', 'term', 'production'), meta.groups())) if meta else {}
    states = {}
    for match in re.finditer(r'__SSH_STATE__ label=(\S+) status=(.*?) pipeline=(.*?) duration=(.*?) ps0=(.*?) ps1=(.*?) pc=([^\r\n]*)', output):
        if match[1] != '%s':
            states[match[1]] = dict(zip(('status', 'pipeline', 'duration', 'ps0', 'ps1', 'prompt_command'), match.groups()[1:]))
    hook_arrays = {}
    preexec_arrays = {}
    for marker, arrays in [('__SSH_HOOKS__', hook_arrays), ('__SSH_PREEXECS__', preexec_arrays)]:
        for match in re.finditer(marker + r' label=(\S+) (?:precmd|preexec)=([^\r\n]*)', output):
            if match[1] != '%s':
                arrays[match[1]] = match[2]
    checks = []
    comparison = args.fix and case.name in ('production-recommended', 'official-starship-only', 'official-production')

    def check(name, passed, actual=None, expected=None, required=True):
        if comparison and name not in ('SSH session exit status', 'shell errors', 'remote Bash metadata', 'BASH_REMATCH preserved', 'Starship PS0 expands'):
            required = False
        checks.append({'test': name, 'pass': bool(passed), 'actual': actual, 'expected': expected, 'required': required})

    check('SSH session exit status', run.returncode == 0, run.returncode, 0)
    errors = [line for line in output.splitlines() if any(word in line for word in
              ('unbound variable', 'bad substitution', 'configuration issue', 'Permission denied', 'command not found'))]
    check('shell errors', not errors, errors, [])
    check('remote Bash metadata', bool(metadata), metadata)
    check('BASH_REMATCH preserved', '__REGEX_AFTER__a' in output)
    check('Starship PS0 expands', '${STARSHIP_START_TIME:' not in output)
    integrated = 'w' in case.order or 'p' in case.order
    official = 'f' in case.order
    repaired_official = args.fix and official and ('w' in case.order or case.late_worktree)
    active = official or (integrated and metadata.get('term') == 'WezTerm')
    reverse = case.order.startswith('ws')
    marks = {mark: sum(isinstance(v, str) and re.match('133;' + mark + '(?:;|$)', v) is not None for v in records) for mark in ('A', 'B', 'C')}
    ds = [';'.join(value.split(';')[:3]) for value in records if isinstance(value, str) and value.startswith('133;D;')]
    if integrated:
        check('mouse reset once per prompt', raw.count(b'\x1b[?1000l') == len(script), raw.count(b'\x1b[?1000l'), len(script))
    if active:
        expected = ['133;D;0'] + ['133;D;' + str(status) for _, status in script[:-1]]
        expected_d = expected[1:] if official else expected
        valid_d = ds == expected_d or (repaired_official and ds == expected)
        check('OSC 133 D preserves exit status', valid_d, ds, expected_d, required=not reverse)
        for mark in ('A', 'B'):
            expected_mark = len(expected) - (mark == 'B' and case.late_worktree)
            check('OSC 133 ' + mark + ' once per prompt', marks[mark] == expected_mark, marks[mark], expected_mark, required=not reverse)
        expected_c = sum(bool(cmd) for cmd, _ in script) - int(case.late_worktree)
        check('OSC 133 C once per command', marks['C'] == expected_c, marks['C'], expected_c)
        if args.fix and not comparison:
            body = re.search(rb'__OUTPUT_BEGIN__\r?\nalpha\r?\nbeta\r?\n__OUTPUT_END__\r?\n', raw)
            if body:
                before_c = raw.rfind(b'\x1b]133;C', 0, body.start())
                after_a = raw.find(b'\x1b]133;A', body.end())
                after_b = raw.find(b'\x1b]133;B', body.end())
                after_c = raw.find(b'\x1b]133;C', body.end())
                check('command output is bounded by C then A/B before next C', 0 <= before_c < body.start() < body.end() < after_a < after_b < after_c, required=not reverse)
            else:
                check('command output body exists', False)
        if reverse:
            source_index = next(i for i, (cmd, _) in enumerate(script) if cmd.startswith('. "$__SSH_WORKTREE"'))
            cs = list(re.finditer(rb'\x1b\]133;C(?:\x07|\x1b\\)', raw))
            source_c_index = sum(bool(cmd) for cmd, _ in script[:source_index])
            suffix = raw[cs[source_c_index].end():] if len(cs) > source_c_index else b''
            suffix_records = [m[1].decode('utf-8', 'replace') for m in OSC.finditer(suffix)]
            expected_suffix = ['133;D;' + str(status) for _, status in script[source_index:-1]]
            check('reverse order recovers after source', [v for v in suffix_records if v.startswith('133;D;')] == expected_suffix and suffix_records.count('133;A') == len(expected_suffix) and suffix_records.count('133;B') == len(expected_suffix))
        cwd = [v for v in records if isinstance(v, str) and v.startswith('7;')]
        check('OSC 7 identifies remote host', bool(cwd) and all(v.startswith('7;file://' + metadata.get('host', '') + '/') for v in cwd), sorted(set(cwd)))
        check('remote cwd special characters encoded', any('cwd%20space%23%25%3F' in v and 'cwd space#%?日本語' in unquote(v) for v in cwd), sorted(set(cwd)))
        if official:
            programs = [v.get('value') for v in records if isinstance(v, dict) and v['var'] == 'WEZTERM_PROG']
            if case.dispatcher_removed:
                check('removed external dispatcher does not run official program callbacks', 'false | true' not in programs)
            else:
                check('official program user variables delegated', 'false | true' in programs and '' in programs)
        else:
            check('Linux does not overwrite local SSH program identity', not any(isinstance(v, dict) and v['var'] == 'WEZTERM_PROG' for v in records))
    else:
        check('OSC 133 absent without WezTerm integration', not any(marks.values()) and not ds, {**marks, 'D': len(ds)})
        check('OSC 7 absent without WezTerm integration', not any(isinstance(v, str) and v.startswith('7;') for v in records))
    labels = [('false', '1', '1'), ('exit7', '7', '7'), ('pipeline', '0', '1 0'), ('pipefail', '1', '1 0')]
    if integrated:
        labels += [('source_twice', '0', '1 0'), ('reinit_only', '1', '1'), ('reinitialize', '1', '1')]
    for label, status, pipeline in [] if case.dispatcher_removed or 's' not in case.order else labels:
        state = states.get(label, {})
        check('Starship exit / PIPESTATUS: ' + label, state.get('status') == status and state.get('pipeline') == pipeline,
              {k: state.get(k) for k in ('status', 'pipeline')}, {'status': status, 'pipeline': pipeline}, required=not reverse or label in ('source_twice', 'reinit_only', 'reinitialize'))
    if integrated and not official:
        pcs = {k: v['prompt_command'] for k, v in states.items() if not reverse or k in ('source_twice', 'reinit_only', 'reinitialize', 'cwd')}
        check('one Starship hook after repeated source / init', all(v.count('starship_precmd') == 1 for v in pcs.values()), pcs)
    if repaired_official and not case.dispatcher_removed:
        selected = {label: value for label, value in hook_arrays.items() if label != 'reinit_only'}
        if 's' in case.order:
            check('one Starship hook in official precmd arrays', bool(selected) and all(value.count('"starship_precmd"') == 1 for value in selected.values()), selected)
        else:
            check('ordinary Bash has no Starship callbacks', bool(selected) and all('starship_precmd' not in value for value in selected.values()), selected)
        duplicate = {}
        for label, value in selected.items():
            names = re.findall(r'"([A-Za-z_][A-Za-z0-9_]*)"', value)
            if len(names) != len(set(names)):
                duplicate[label] = names
        check('official precmd callbacks remain unique after reload / init', not duplicate, duplicate, {})
        duplicate_preexec = {}
        for label, value in preexec_arrays.items():
            if label == 'reinit_only':
                continue
            names = re.findall(r'"([A-Za-z_][A-Za-z0-9_]*)"', value)
            if len(names) != len(set(names)):
                duplicate_preexec[label] = names
        check('official preexec callbacks remain unique after reload / init', not duplicate_preexec, duplicate_preexec, {})
        if 's' in case.order:
            check('Starship direct reinit-only precmd hook uniqueness', hook_arrays.get('reinit_only', '').count('"starship_precmd"') == 1, hook_arrays.get('reinit_only'), required=False)
            check('Starship direct reinit-only preexec hook uniqueness', preexec_arrays.get('reinit_only', '').count('"starship_preexec_all"') == 1, preexec_arrays.get('reinit_only'), required=False)
        check('zoxide hook remains installed', any('__zoxide_hook' in state['prompt_command'] for state in states.values()) or any('__zoxide_hook' in value for value in hook_arrays.values()))
    if case.pc_builder:
        pcs = {label: value['prompt_command'] for label, value in states.items() if label != 'initial'}
        check('user PS1 builder retained before final integration callback', bool(pcs) and all('__ssh_rewrite_ps1' in value and value.find('__ssh_rewrite_ps1') < value.find('__wezterm_prompt_command') < value.find('__bp_interactive_mode') for value in pcs.values()), pcs)
        check('user reconstructed PS1 retained', all('USER_REBUILT' in state['ps1'] for label, state in states.items() if label != 'initial'))
    if case.dispatcher_removed:
        check('removed dispatcher is detected as inactive', '__SSH_BP_INACTIVE__\r' in output and '__SSH_BP_BAD_ACTIVE__\r' not in output)
        check('inactive Starship status remains stale while OSC D uses actual status', states.get('false', {}).get('status') == '91' and '133;D;91' not in ds and '133;D;92' not in ds, states.get('false', {}))
    if case.user_hooks:
        for kind in ('PRECMD', 'PREEXEC'):
            calls = re.findall('__USER_' + kind + r'__([ab]) status=(\d+)', output)
            order = ''.join(name for name, _ in calls)
            check('user ' + kind.lower() + ' relative order retained', bool(calls) and order == 'ab' * (len(calls) // 2), order)
            check('user ' + kind.lower() + ' callbacks preserve exit status', bool(calls) and len(calls) % 2 == 0 and all(calls[i][1] == calls[i + 1][1] for i in range(0, len(calls), 2)), calls)
    notifications = [v.get('value') for v in records if isinstance(v, dict) and v['var'] == 'wezterm_cmd_done']
    if official and not repaired_official:
        check('official integration leaves custom completion notification disabled', not notifications, notifications, [])
    if case.name == 'worktree-recommended' or case.notifications == 'history':
        parsed = [v.split('\t', 2) for v in notifications if v is not None]
        expected_notify = [('0', 'sleep 2.15'), ('1', 'sleep 2.15; false'), ('1', ''), ('0', 'sleep 2.15'), ('0', 'sleep 2.15'), ('1', ''), ('1', '')]
        actual = [(v[0], v[2]) for v in parsed if len(v) == 3]
        check('notification status / history suppression', actual == expected_notify, actual, expected_notify)
        check('notification duration', len(parsed) == 7 and all(2 <= int(v[1]) <= 12 for v in parsed), parsed)
        long = [v for v in records if isinstance(v, dict) and v['var'] == 'SSH_TEST_LONG']
        check('Linux Unicode boundary is valid UTF-8 / 200 characters', len(long) == 1 and long[0].get('value') == 'x' * 199 + '😀', long)
    elif case.notifications == 'simple':
        parsed = [value.split('\t', 2) for value in notifications if value is not None]
        expected_notify = [('1', 'sleep 2.15; false'), ('7', '(sleep 2.15; exit 7)')]
        actual = [(value[0], value[2]) for value in parsed if len(value) == 3]
        check('completion notification including subshell status', actual == expected_notify, actual, expected_notify)
        check('completion notification duration', len(parsed) == 2 and all(2 <= int(value[1]) <= 12 for value in parsed), parsed)
    result = {'name': case.name, 'metadata': metadata, 'checks': checks, 'states': states,
              'comparison': comparison, 'hook_arrays': hook_arrays, 'preexec_arrays': preexec_arrays,
              'markers': {**marks, 'D': len(ds)}, 'notifications': notifications, 'records': records,
              'pass': all(v['pass'] or not v['required'] for v in checks)}
    (directory / 'result.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    return result


def main():
    global OUT, MANIFEST, CASES
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('host')
    parser.add_argument('--ssh', default='ssh')
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--reuse', action='store_true')
    parser.add_argument('--keep-temp', action='store_true')
    parser.add_argument('--cleanup', action='store_true')
    parser.add_argument('--case', action='append', default=[])
    parser.add_argument('--fix', action='store_true', help='修正後の結果を ssh-fix-results/ に保存する')
    parser.add_argument('--refresh', action='store_true', help='--reuse 時に検証用統合だけを新しいソースへ更新する')
    args = parser.parse_args()
    if args.fix:
        OUT = HERE / 'ssh-fix-results'
        MANIFEST = OUT / 'prepared.json'
        CASES = FIX_CASES
    OUT.mkdir(exist_ok=True)
    if args.cleanup:
        cleanup(args, read_manifest()['hosts'][args.host])
        print(args.host + ': temporary test files removed')
        return
    chosen = [c for c in CASES if not args.case or c.name in args.case]
    if not chosen:
        raise SystemExit('No matching case')
    if args.refresh and not args.reuse:
        raise SystemExit('--refresh requires --reuse')
    if args.reuse:
        previous = read_manifest()['hosts'][args.host]
        if previous.get('cleaned_up'):
            raise SystemExit('The remote test directory has been removed; run without --reuse to prepare it again')
        prepared = add_missing_cases(args, previous)
        if args.refresh:
            prepared = refresh_source(args, prepared)
    else:
        prepared = prepare(args)
    if args.prepare_only:
        print(json.dumps(prepared, ensure_ascii=True, indent=2))
        return
    try:
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda c: run_case(args, prepared, c), chosen))
        failures = [{'case': r['name'], **c} for r in results for c in r['checks'] if c['required'] and not c['pass']]
        after_hash = hashlib.sha256((ROOT / 'shell' / 'wezterm.sh').read_bytes()).hexdigest()
        summary = {'host': args.host, 'source_sha256': prepared['source_sha256'], 'cases': len(results),
                   'source_sha256_after': after_hash,
                   'source_unchanged': after_hash == prepared['source_sha256'],
                   'checks': sum(len(r['checks']) for r in results),
                   'required_passed': sum(c['required'] and c['pass'] for r in results for c in r['checks']),
                   'required_checks': sum(c['required'] for r in results for c in r['checks']),
                   'pass': not failures, 'failures': failures, 'results': results,
                   'known_limitations': [{'case': r['name'], **c} for r in results for c in r['checks'] if not c['required'] and not c['pass']]}
        (OUT / f'{args.host}-summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
        print(json.dumps({k: v for k, v in summary.items() if k != 'results'}, ensure_ascii=True, indent=2))
    finally:
        if not args.keep_temp:
            cleanup(args, prepared)
    raise SystemExit(1 if failures else 0)


if __name__ == '__main__':
    main()
