"""公式統合へ委譲するガードを実 Bash で確認する限定モデル試験。

公式 shell script と本番 source は実体を読む。tmux は環境変数、ble.sh は
BLE_VERSION と登録先を記録する blehook stub だけを使い、各プログラムは起動しない。
"""
from pathlib import Path
import hashlib
import json
import os
import subprocess

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = HERE / "ssh-fix-results"
OUT.mkdir(exist_ok=True)
BASH = r"C:\Program Files\Git\bin\bash.exe"

CASES = {
    "tmux-environment": 'export TMUX=/tmp/wezterm-guard-model TERM_PROGRAM=WezTerm',
    "tmux-term-program": 'export TERM_PROGRAM=tmux',
    "tmux-both": 'export TMUX=/tmp/wezterm-guard-model TERM_PROGRAM=tmux',
    "semantic-skip": 'export TERM_PROGRAM=WezTerm WEZTERM_SHELL_SKIP_SEMANTIC_ZONES=1',
    "blehook-stub": 'export TERM_PROGRAM=WezTerm BLE_VERSION=guard-model; __guard_ble_hooks=(); blehook() { __guard_ble_hooks+=("$*"); }',
}
COMMON = r'''
export PATH="/usr/bin:/bin:$PATH" TERM=xterm-256color
unset TMUX BLE_VERSION TERM_PROGRAM WEZTERM_SHELL_SKIP_ALL WEZTERM_SHELL_SKIP_SEMANTIC_ZONES WEZTERM_SHELL_SKIP_CWD WEZTERM_SHELL_SKIP_USER_VARS
unset STARSHIP_SHELL bash_preexec_imported __bp_imported
PS1='GUARD> ' PS2='MORE> ' PS0=
'''
CHECK = r'''
. "$GUARD_OFFICIAL"
__guard_before_pre="${precmd_functions[*]-}"
__guard_before_exec="${preexec_functions[*]-}"
__guard_before_ble="${__guard_ble_hooks[*]-}"
__guard_before_defs=$(declare -f __wezterm_set_user_var __wezterm_osc7 __wezterm_semantic_precmd __wezterm_semantic_preexec)
printf '__STATE__\tprecmd_before\t%s\n' "$__guard_before_pre"
printf '__STATE__\tpreexec_before\t%s\n' "$__guard_before_exec"
printf '__STATE__\tble_before\t%s\n' "$__guard_before_ble"
__guard_record() {
    local name=$1; shift
    "$@"
    printf '__CHECK__\t%s\t%s\n' "$name" "$?"
}
for __guard_pass in 1 2; do
    . "$GUARD_SOURCE"
    __guard_record "source${__guard_pass}:precmd-preserved" test "$__guard_before_pre" = "${precmd_functions[*]-}"
    __guard_record "source${__guard_pass}:preexec-preserved" test "$__guard_before_exec" = "${preexec_functions[*]-}"
    __guard_record "source${__guard_pass}:blehook-preserved" test "$__guard_before_ble" = "${__guard_ble_hooks[*]-}"
    __guard_after_defs=$(declare -f __wezterm_set_user_var __wezterm_osc7 __wezterm_semantic_precmd __wezterm_semantic_preexec)
    __guard_record "source${__guard_pass}:official-definitions-preserved" test "$__guard_before_defs" = "$__guard_after_defs"
    __guard_record "source${__guard_pass}:completion-not-registered" test "${PROMPT_COMMAND[*]-}" = "${PROMPT_COMMAND[*]//__wezterm_prompt_command/}"
    __guard_record "source${__guard_pass}:notification-not-defined" test -z "$(declare -F __wezterm_notify_done)"
    __guard_record "source${__guard_pass}:PS0-not-added" test -z "${PS0-}"
    __guard_record "source${__guard_pass}:official-mode-not-enabled" test -z "${__wz_official_bash-}"
    __guard_record "source${__guard_pass}:loaded-marker-not-added" test -z "${__wezterm_integration_loaded-}"
done
printf '__STATE__\tprecmd_after\t%s\n' "${precmd_functions[*]-}"
printf '__STATE__\tpreexec_after\t%s\n' "${preexec_functions[*]-}"
printf '__STATE__\tble_after\t%s\n' "${__guard_ble_hooks[*]-}"
declare -p PROMPT_COMMAND
'''

source = ROOT / "shell" / "wezterm.sh"
official = HERE / "cache" / "official-wezterm.sh"
source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
env = os.environ.copy()
env["GUARD_SOURCE"] = source.as_posix()
env["GUARD_OFFICIAL"] = official.as_posix()
records = []
for name, setup in CASES.items():
    result = subprocess.run([BASH, "--noprofile", "--norc", "--noediting", "-ic", COMMON + setup + "\n" + CHECK], cwd=ROOT, env=env, capture_output=True, timeout=30)
    stdout = result.stdout.decode("utf-8", "replace")
    stderr = result.stderr.decode("utf-8", "replace")
    checks, state = [], {}
    for line in stdout.splitlines():
        if line.startswith("__CHECK__\t"):
            _, title, status = line.split("\t", 2)
            checks.append({"name": title, "passed": status == "0"})
        elif line.startswith("__STATE__\t"):
            _, title, value = line.split("\t", 2)
            state[title] = value
    records.append({"name": name, "exit_code": result.returncode, "checks": checks, "state": state, "stdout": stdout, "stderr": stderr})

checks = [check for record in records for check in record["checks"]]
output = {
    "scope": "公式 shell script + 現sourceを実Git Bashで読み込むガードの限定モデル。実tmux/ble.shプロセス・SSH通信・端末描画は実行しない。",
    "source_sha256": source_hash,
    "source_stable": source_hash == hashlib.sha256(source.read_bytes()).hexdigest(),
    "official_sha256": hashlib.sha256(official.read_bytes()).hexdigest(),
    "total": len(checks),
    "passed": sum(check["passed"] for check in checks),
    "failed": sum(not check["passed"] for check in checks),
    "cases": records,
}
(OUT / "guards.json").write_text(json.dumps(output, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(json.dumps({key: value for key, value in output.items() if key != "cases"}, indent=2, ensure_ascii=False))
raise SystemExit(0 if output["failed"] == 0 and len(checks) == 90 and all(record["exit_code"] == 0 for record in records) else 1)
