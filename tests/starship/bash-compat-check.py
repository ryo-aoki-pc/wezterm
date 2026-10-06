"""Git Bash + Starship の修正を実体で検査し、過去の診断記録と別に保存する。

実行: python tests/starship/bash-compat-check.py [case-name ...]
各 rc / Starship cache / zoxide data は fix-results/bash の条件別ディレクトリ。
画面・Readline の折り返し・WezTerm のコピー動作は live テストで別に検査する。
"""
from __future__ import annotations

import base64
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = Path(os.environ.get("WEZTERM_STARSHIP_TEST_RESULTS", str(HERE / "fix-results" / "bash")))
BASH = Path(r"C:\Program Files\Git\bin\bash.exe")
OSC = re.compile(rb"\x1b\]([^\x07\x1b]*)(?:\x07|\x1b\\)")


def bash_path(path: Path) -> str:
    value = path.resolve().as_posix()
    return "/" + value[0].lower() + value[2:] if len(value) > 1 and value[1] == ":" else value


@dataclass(frozen=True)
class Case:
    name: str
    order: str
    extra: str = ""
    noediting: bool = True
    nounset: bool = False
    pipeline_visible: bool = False


INIT = {
    "s": 'eval "$(starship init bash)"',
    "w": '. "$WEZTERM_SHELL_INTEGRATION"',
    "z": 'eval "$(zoxide init bash)"',
    "a": '__bash_tail() { local st=$?; printf "__TAIL__%s\\n" "$st"; return "$st"; }; PROMPT_COMMAND=(starship_precmd __bash_tail)',
    "b": 'PROMPT_COMMAND=(starship_precmd __wezterm_prompt_command)',
    "m": 'PROMPT_COMMAND=(starship_precmd __wz_mouse_off)',
    "l": '__bash_tail() { local st=$?; printf "__TAIL__%s\\n" "$st"; return "$st"; }; PROMPT_COMMAND=(__wezterm_prompt_command __wz_mouse_off starship_precmd __bash_tail)',
    "x": '__bash_tail() { local st=$?; printf "__TAIL__%s\\n" "$st"; return "$st"; }; declare -ax PROMPT_COMMAND=(starship_precmd "__bash_tail # keep comment")',
}
CASES = [
    Case("control", "w", noediting=False),
    Case("recommended", "swz", noediting=False),
    Case("reverse", "wsz", noediting=False),
    Case("zoxide-before", "szw", noediting=False),
    Case("noediting", "swz"),
    Case("nounset", "swz", nounset=True),
    Case("array-before", "swz", '__bash_extra_a() { local st=$?; printf "__EXTRA_A__%s\\n" "$st"; return "$st"; }; __bash_extra_b() { local st=$?; printf "__EXTRA_B__%s\\n" "$st"; return "$st"; }; PROMPT_COMMAND=(__bash_extra_a __bash_extra_b)'),
    Case("pipeline-starship-only", "s"),
    Case("pipeline-recommended", "sw"),
    Case("pipeline-reverse", "ws"),
    Case("array-after-real", "saw"),
    Case("array-existing-wz-tail", "swbw"),
    Case("array-existing-mouse-tail", "swmw"),
    Case("official-present", "w", '__wezterm_set_user_var() { :; }'),
    Case("user-ps0", "sw", "PS0='USER_PS0[$?] '; PS1='USER_PS1> '"),
    Case("pipeline-visible-baseline", "s", pipeline_visible=True),
    Case("pipeline-visible-recommended", "sw", pipeline_visible=True),
    Case("pipeline-visible-reverse", "ws", pipeline_visible=True),
    Case("legacy-array", "slw"),
    Case("exported-array", "sxw"),
]

STATE = r'''__bash_test_state() {
    printf '\n__STATE__ label=%s status=%s pipeline=%s duration=%s ps0=%q ps1=%q pc=' "$1" "${STARSHIP_CMD_STATUS-NA}" "${STARSHIP_PIPE_STATUS[*]-NA}" "${STARSHIP_DURATION-NA}" "${PS0-}" "${PS1-}"
    declare -p PROMPT_COMMAND
}
'''


def commands(case: Case) -> list[tuple[str, int]]:
    # $?, PIPESTATUS を検査する state は次のコマンドで読む（プロンプトの後）。
    result = [
        ('__bash_test_state initial', 0),
        ('false', 1), ('__bash_test_state false', 0),
        ('(exit 7)', 7), ('__bash_test_state exit7', 0),
        ('false | true', 0), ('__bash_test_state pipeline', 0),
        ('set -o pipefail; false | true', 1), ('__bash_test_state pipefail', 0),
        ('set +o pipefail', 0),
        ("printf '__OUTPUT_BEGIN__\\nalpha\\nbeta\\n__OUTPUT_END__\\n'", 0),
        ('', 0),
    ]
    if "w" in case.order:
        result += [('. "$WEZTERM_SHELL_INTEGRATION"; . "$WEZTERM_SHELL_INTEGRATION"', 0),
                   ('false | true', 0), ('__bash_test_state source_twice', 0)]
    if case.name == 'legacy-array':
        result += [('for __test_reload in 1 2 3 4 5; do . "$WEZTERM_SHELL_INTEGRATION"; done', 0),
                   ('false | true', 0), ('__bash_test_state source_five', 0)]
    if "s" in case.order:
        reinit = INIT["s"]
        if "w" in case.order:
            reinit += '; ' + INIT["w"]
        if "z" in case.order:
            reinit += '; ' + INIT["z"]
        result += [(reinit, 0), ('false', 1), ('__bash_test_state reinitialize', 0)]
    if case.name == "recommended":
        result += [
            ('sleep 2.15', 0), ('__bash_test_state duration', 0),
            ('sleep 2.15; false', 1), ('__bash_test_state long_fail', 0),
            ('HISTCONTROL=ignorespace', 0), (' sleep 2.15; false', 1),
            ('HISTCONTROL=ignoredups', 0), ('sleep 2.15', 0), ('sleep 2.15', 0),
            ("HISTCONTROL=; HISTIGNORE='sleep*'", 0), ('sleep 2.15; false', 1),
            ('HISTIGNORE=; set +o history', 0), ('sleep 2.15; false', 1),
            ('set -o history', 0),
        ]
    result += [
        ("[[ ab =~ (a) ]]; printf '__REGEX_BEFORE__%s\\n' \"${BASH_REMATCH[1]}\"", 0),
        ("printf '__REGEX_AFTER__%s\\n' \"${BASH_REMATCH[1]}\"", 0),
        ('cd "$__BASH_TEST_PATH"', 0), ('__bash_test_state cwd', 0),
    ]
    if "z" in case.order:
        result += [('z .', 0)]
    return result + [('exit', 0)]


def run_case(case: Case) -> dict:
    directory = OUT / case.name
    directory.mkdir(parents=True, exist_ok=True)
    for name in ("cache", "zoxide", "path #% 日本語"):
        (directory / name).mkdir(exist_ok=True)
    rc = directory / "test.rc"
    rc.write_text("\n".join([
        'export TERM=xterm-256color TERM_PROGRAM=WezTerm',
        'export PATH=/usr/bin:/bin:$PATH',
        'export COLUMNS=120 LINES=40 LANG=en_US.UTF-8',
        'export WEZTERM_NOTIFY_AFTER=2',
        f"export WEZTERM_SHELL_INTEGRATION='{bash_path(ROOT / 'shell' / 'wezterm.sh')}'",
        f"export STARSHIP_CONFIG='{(HERE / ('bash-pipeline.toml' if case.pipeline_visible else 'bash-starship.toml')).as_posix()}'",
        f"export STARSHIP_CACHE='{(directory / 'cache').as_posix()}'",
        f"export _ZO_DATA_DIR='{(directory / 'zoxide').as_posix()}'",
        f"__BASH_TEST_PATH='{bash_path(directory / 'path #% 日本語')}'",
        'HISTFILE=/dev/null; HISTCONTROL=; HISTIGNORE=',
        "PS1='BASE>'", STATE, case.extra,
        *(INIT[item] for item in case.order),
        'set -u' if case.nounset else ':',
    ]) + "\n", encoding="utf-8", newline="\n")
    script = commands(case)
    args = [str(BASH), '--noprofile', '--rcfile', str(rc)]
    if case.noediting:
        args.append('--noediting')
    args.append('-i')
    proc = subprocess.run(args, input=('\n'.join(item[0] for item in script) + '\n').encode('utf-8'),
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT, cwd=ROOT, timeout=150)
    raw = proc.stdout
    (directory / "session.raw").write_bytes(raw)
    output = raw.decode("utf-8", "replace")
    (directory / "session.txt").write_text(output.replace("\x1b", "<ESC>").replace("\x07", "<BEL>"), encoding="utf-8")
    records = []
    for match in OSC.finditer(raw):
        payload = match[1].decode("utf-8", "replace")
        if "SetUserVar=" in payload:
            key, encoded = payload.split("SetUserVar=", 1)[1].split("=", 1)
            records.append({"var": key, "value": base64.b64decode(encoded).decode("utf-8", "strict")})
        else:
            records.append(payload)
    states = {}
    for match in re.finditer(r"__STATE__ label=(\S+) status=(.*?) pipeline=(.*?) duration=(.*?) ps0=(.*?) ps1=(.*?) pc=([^\r\n]*)", output):
        states[match[1]] = dict(zip(("status", "pipeline", "duration", "ps0", "ps1", "prompt_command"), match.groups()[1:]))
    checks = []

    reverse = case.order.startswith('ws')

    def check(name: str, passed: bool, actual=None, expected=None, *, required: bool = True):
        item = {"test": name, "pass": bool(passed), "required": required}
        if actual is not None:
            item["actual"] = actual
        if expected is not None:
            item["expected"] = expected
        checks.append(item)

    check("exit status", proc.returncode == 0, proc.returncode, 0)
    errors = [line for line in output.splitlines() if any(term in line for term in
        ("unbound variable", "bad substitution", "configuration issue", "Permission denied", "Unable to", "command not found"))]
    check("shell errors", not errors, errors, [])
    check("BASH_REMATCH remains intact", "__REGEX_AFTER__a" in output)
    check("Starship PS0 expansion is not displayed literally", '${STARSHIP_START_TIME:' not in output)
    if 'w' in case.order:
        check("mouse reset runs once per prompt", raw.count(b'\x1b[?1000l') == len(script), raw.count(b'\x1b[?1000l'), len(script))
    active = 'w' in case.order and case.name != 'official-present'
    marks = {mark: records.count(f"133;{mark}") for mark in ('A', 'B', 'C')}
    d = [record for record in records if isinstance(record, str) and record.startswith('133;D;')]
    if active:
        # 初期プロンプト + exit 以外の各入力行の後（空 Enter も新プロンプト）。
        expected_d = ['133;D;0'] + [f'133;D;{status}' for command, status in script[:-1]]
        check("one OSC 133 C per nonempty command", marks['C'] == len([command for command, _ in script if command]), marks['C'], len([command for command, _ in script if command]))
        check("one OSC 133 D with correct status per prompt", d == expected_d, d, expected_d, required=not reverse)
        check("one OSC 133 A per prompt", marks['A'] == len(expected_d), marks['A'], len(expected_d), required=not reverse)
        check("one OSC 133 B per prompt", marks['B'] == len(expected_d), marks['B'], len(expected_d), required=not reverse)
        if reverse:
            # 統合→Starship は推奨外。統合を再sourceした以降の復旧は必須。
            reload_index = next(index for index, (command, _) in enumerate(script) if command.startswith('. "$WEZTERM_SHELL_INTEGRATION"'))
            cs = list(re.finditer(rb'\x1b\]133;C(?:\x07|\x1b\\)', raw))
            source_c_index = len([command for command, _ in script[:reload_index] if command])
            suffix_raw = raw[cs[source_c_index].end():] if len(cs) > source_c_index else b''
            suffix_records = [match[1].decode('utf-8', 'replace') for match in OSC.finditer(suffix_raw)]
            suffix_d = [record for record in suffix_records if record.startswith('133;D;')]
            expected_suffix_d = [f'133;D;{status}' for _, status in script[reload_index:-1]]
            check('reverse order recovers D/status after source', suffix_d == expected_suffix_d, suffix_d, expected_suffix_d)
            check('reverse order recovers A/B after source', suffix_records.count('133;A') == len(expected_suffix_d) and suffix_records.count('133;B') == len(expected_suffix_d), {mark: suffix_records.count('133;' + mark) for mark in ('A', 'B')}, len(expected_suffix_d))
        output_match = re.search(rb'__OUTPUT_BEGIN__\r?\nalpha\r?\nbeta\r?\n__OUTPUT_END__\r?\n', raw)
        if output_match:
            previous_c = raw.rfind(b'\x1b]133;C', 0, output_match.start())
            next_a = raw.find(b'\x1b]133;A', output_match.end())
            next_b = raw.find(b'\x1b]133;B', output_match.end())
            next_c = raw.find(b'\x1b]133;C', output_match.end())
            check("output bounded by C then A/B before next C", 0 <= previous_c < output_match.start() < output_match.end() < next_a < next_b < next_c, required=not reverse)
        else:
            check("output body", False)
        cwd = [item for item in records if isinstance(item, str) and item.startswith('7;')]
        check("cwd special characters encoded", any('path%20%23%25%20日本語' in value for value in cwd), sorted(set(cwd)))
        programs = [item['value'] for item in records if isinstance(item, dict) and item['var'] == 'WEZTERM_PROG']
        check("program emitted and cleared", 'false | true' in programs and '' in programs)
    else:
        check("no custom OSC133 without integration", not any(marks.values()) and not d, {**marks, "D": len(d)})
    if 's' in case.order:
        for label, status, pipeline in [('false', '1', '1'), ('exit7', '7', '7'),
                                        ('pipeline', '0', '1 0'), ('pipefail', '1', '1 0'),
                                        ('source_twice', '0', '1 0'), ('reinitialize', '1', '1')]:
            if label == 'source_twice' and 'w' not in case.order:
                continue
            state = states.get(label, {})
            check('Starship status / PIPESTATUS: ' + label, state.get('status') == status and state.get('pipeline') == pipeline,
                  {key: state.get(key) for key in ('status', 'pipeline')}, {'status': status, 'pipeline': pipeline}, required=not reverse or label in ('source_twice', 'reinitialize'))
        if 'w' in case.order:
            hook_states = {label: state['prompt_command'] for label, state in states.items() if not reverse or label in ('source_twice', 'reinitialize', 'cwd')}
            check('exactly one Starship prompt hook after source / reinitialization', all(value.count('starship_precmd') == 1 for value in hook_states.values()), hook_states)
            check('no empty array entries introduced by repeated source', all(not re.search(r'\[\d+\]=""', value) for value in hook_states.values()), hook_states)
        if case.name == 'legacy-array':
            state = states.get('source_five', {})
            check('legacy array PIPESTATUS after five sources', state.get('status') == '0' and state.get('pipeline') == '1 0', state)
            check('legacy array tail retained', '__TAIL__' in output)
        if case.pipeline_visible:
            plain = re.sub(rb'\x1b\[[0-?]*[ -/]*[@-~]', b'', OSC.sub(b'', raw)).decode('utf-8', 'replace')
            check('pipestatus displayed on successful pipeline', bool(re.search(r'PIPE=S=1 \|S=0\s+-> S=0 OK>', plain)), required=not reverse)
            check('pipestatus displayed with pipefail', bool(re.search(r'PIPE=S=1 \|S=0\s+-> S=1 ERR>', plain)), required=not reverse)
    if case.name == 'user-ps0':
        check('preexisting PS0 retained', 'USER_PS0[' in output)
    if case.name == 'array-before':
        check('preexisting prompt hooks retained', '__EXTRA_A__' in output and '__EXTRA_B__' in output)
    if case.name == 'array-after-real':
        check('preexisting array tail retained', '__TAIL__' in output)
    if case.name == 'exported-array':
        check('exported array comment and tail retained', '__TAIL__' in output and all('# keep comment' in state['prompt_command'] and 'declare -ax ' in state['prompt_command'] for state in states.values()))
    notifications = [item['value'] for item in records if isinstance(item, dict) and item['var'] == 'wezterm_cmd_done']
    if case.name == 'recommended':
        expected = [('0', 'sleep 2.15'), ('1', 'sleep 2.15; false'), ('1', ''),
                    ('0', 'sleep 2.15'), ('0', 'sleep 2.15'), ('1', ''), ('1', '')]
        parsed = [value.split('\t', 2) for value in notifications]
        actual = [(item[0], item[2]) for item in parsed if len(item) == 3]
        check('completion notification status / history handling', actual == expected, actual, expected)
        check('completion notification duration', len(parsed) == len(expected) and all(2 <= int(item[1]) <= 8 for item in parsed), parsed)
        duration = int(states.get('duration', {}).get('duration', '-1'))
        check('Starship command duration', 2000 <= duration <= 8000, duration)
    summary = {"name": case.name, "order": case.order, "noediting": case.noediting, "nounset": case.nounset,
               "checks": checks, "states": states, "markers": {**marks, "D": len(d)}, "notifications": notifications,
               "records": records, "pass": all(item['pass'] or not item['required'] for item in checks)}
    (directory / "result.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
    return summary


def helpers() -> list[dict]:
    checks = []
    prelude = "export PATH=/usr/bin:/bin:$PATH LANG=en_US.UTF-8; TERM_PROGRAM=WezTerm; PS1='x'; . ./shell/wezterm.sh; "

    def run(command: str):
        return subprocess.run([str(BASH), '--noprofile', '--norc', '-s'], input=(prelude + command).encode('utf-8'),
                              cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)

    for payload in (b'', b'a', b'ab', b'abc', b'abcd', '日本語と emoji 😀'.encode(), bytes(range(1, 256))):
        literal = ''.join(f'\\x{byte:02x}' for byte in payload)
        proc = run("__wezterm_b64 $'" + literal + "'; printf '%s' \"$__wz_b64\"")
        checks.append({'test': f'base64 {len(payload)} bytes', 'pass': proc.stdout == base64.b64encode(payload) and not proc.stderr})
    for label, payload in [('BMP', '日本語' * 100), ('emoji', '日本語😀' * 70),
                           ('emoji-boundary-199', 'x' * 199 + '😀x'), ('emoji-boundary-198', 'x' * 198 + '😀x'),
                           ('emoji-boundary-197', 'x' * 197 + '😀x'), ('ASCII', 'x' * 205)]:
        proc = run("s='" + payload + "'; __wezterm_uservar test \"$s\"")
        encoded = re.search(rb'SetUserVar=test=([^\x1b]*)', proc.stdout)
        raw = base64.b64decode(encoded[1]) if encoded else b''
        try:
            decoded = raw.decode('utf-8', 'strict')
            valid = True
        except UnicodeDecodeError:
            decoded = raw.decode('utf-8', 'replace')
            valid = False
        # Bash/MSYS の絵文字は UTF-16 の 2 単位。200 単位内で完全な文字だけを送る。
        expected = payload.encode('utf-16-le')[:400].decode('utf-16-le', 'ignore')
        checks.append({'test': 'uservar truncation ' + label, 'pass': valid and payload.startswith(decoded) and decoded == expected,
                       'valid_utf8': valid, 'unicode_chars': len(decoded), 'bytes': len(raw), 'tail': decoded[-6:], 'expected_tail': expected[-6:]})
    call_log = OUT / 'cygpath-calls.txt'
    call_log.write_text('', encoding='utf-8')
    command = f'''cygpath() {{ printf '__CALL__\\n' >> '{bash_path(call_log)}'; printf '%s' "$2"; }}; __wz_osc7; __wz_osc7; PWD='/virtual/a #?%\\日本語'; __wz_osc7; __wz_osc7'''
    proc = run(command)
    osc7 = re.findall(rb'\x1b\]7;([^\x1b]*)\x1b\\', proc.stdout)
    calls = call_log.read_text().count('__CALL__')
    checks.append({'test': 'OSC7 special characters / path cache', 'pass': len(osc7) == 4 and osc7[0] == osc7[1] and osc7[2] == osc7[3] and calls == 2 and all(value in osc7[2] for value in (b'%20', b'%23', b'%3F', b'%25', b'%5C')), 'cygpath_calls': calls, 'values': [item.decode('utf-8') for item in osc7]})
    (OUT / 'helpers.json').write_text(json.dumps(checks, ensure_ascii=False, indent=2), encoding='utf-8')
    return checks


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    chosen = [case for case in CASES if len(sys.argv) == 1 or case.name in sys.argv[1:]]
    if not chosen:
        raise SystemExit('Unknown case: ' + ', '.join(sys.argv[1:]))
    start_hash = hashlib.sha256((ROOT / 'shell' / 'wezterm.sh').read_bytes()).hexdigest()
    # 条件ごとに cache / rc が独立しているため同時に3シェルまで実行する。
    with ThreadPoolExecutor(max_workers=3) as pool:
        results = list(pool.map(run_case, chosen))
    helper_results = helpers()
    end_hash = hashlib.sha256((ROOT / 'shell' / 'wezterm.sh').read_bytes()).hexdigest()
    failures = [{'case': item['name'], **check} for item in results for check in item['checks'] if check['required'] and not check['pass']]
    failures += [{'case': 'helpers', **check} for check in helper_results if not check['pass']]
    if start_hash != end_hash:
        failures.append({'case': 'source', 'test': 'source unchanged while testing', 'pass': False})
    required_count = sum(check['required'] for item in results for check in item['checks']) + len(helper_results)
    required_passed = sum(check['required'] and check['pass'] for item in results for check in item['checks']) + sum(check['pass'] for check in helper_results)
    summary = {'source_sha256': end_hash, 'cases': len(results), 'checks': sum(len(item['checks']) for item in results) + len(helper_results),
               'required_checks': required_count, 'required_passed': required_passed,
               'pass': not failures, 'failures': failures,
               'known_limitations': [{'case': item['name'], **check} for item in results for check in item['checks'] if not check['required'] and not check['pass']],
               'results': results, 'helpers': helper_results}
    (OUT / 'summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({key: value for key, value in summary.items() if key not in ('results', 'helpers')}, ensure_ascii=True, indent=2))
    raise SystemExit(0 if not failures else 1)
