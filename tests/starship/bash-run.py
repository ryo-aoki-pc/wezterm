"""実体の Git Bash と Starship を対話モードで試し、生の OSC を保存する。"""
from __future__ import annotations

import base64
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "tests" / "starship"
BASH = r"C:\Program Files\Git\bin\bash.exe"
POSIX_ROOT = "/c/Users/r-aoki/.codex/worktrees/9955/wezterm"
OSC = re.compile(rb"\x1b\]([^\x07\x1b]*)(?:\x07|\x1b\\)")

INIT = {
    "s": 'eval "$(starship init bash)"',
    "w": '. "$WEZTERM_SHELL_INTEGRATION"',
    "z": 'eval "$(zoxide init bash)"',
}

STATE = '''__bash_test_state() {
    printf '\\n__STATE__ status=%s pipeline=%s duration=%s ps0=%q ps1=%q pc=' "${STARSHIP_CMD_STATUS-NA}" "${STARSHIP_PIPE_STATUS[*]-NA}" "${STARSHIP_DURATION-NA}" "${PS0-}" "${PS1-}"
    declare -p PROMPT_COMMAND
}
'''

COMMANDS = [
    "printf '__STEP__ initialized\\n'; __bash_test_state",
    "false",
    "__bash_test_state",
    "(exit 7)",
    "__bash_test_state",
    "false | true",
    "__bash_test_state",
    "set -o pipefail; false | true",
    "__bash_test_state",
    "set +o pipefail",
    "sleep 2.15",
    "__bash_test_state",
    "sleep 2.15; false",
    "__bash_test_state",
    "printf 'OUTPUT alpha\\nOUTPUT beta\\n'",
    "",
    "printf '__STEP__ reload_integration\\n'; . \"$WEZTERM_SHELL_INTEGRATION\"; . \"$WEZTERM_SHELL_INTEGRATION\"",
    "false",
    "__bash_test_state",
    "printf '__STEP__ reload_all\\n'; eval \"$(starship init bash)\"; . \"$WEZTERM_SHELL_INTEGRATION\"; eval \"$(zoxide init bash)\"",
    "false",
    "__bash_test_state",
    "HISTCONTROL=ignorespace",
    " sleep 2.15; false",
    "__bash_test_state",
    "HISTCONTROL=ignoredups; true",
    "sleep 2.15",
    "sleep 2.15",
    "__bash_test_state",
    "HISTCONTROL=; HISTIGNORE='sleep*'",
    "sleep 2.15; false",
    "__bash_test_state",
    "HISTIGNORE=; set +o history",
    "sleep 2.15; false",
    "__bash_test_state",
    "set -o history",
    "[[ ab =~ (a) ]]; printf '__REGEX_BEFORE__%s\\n' \"${BASH_REMATCH[1]}\"",
    "printf '__REGEX_AFTER__%s\\n' \"${BASH_REMATCH[1]}\"",
    "cd \"$__BASH_TEST_PATH\"",
    "__bash_test_state",
    "z .",
    "printf '__STEP__ done\\n'",
    "exit",
]

def run_case(name: str, order: str, extra: str = "", noediting: bool = False, nounset: bool = False, config_file: str = "bash-starship.toml"):
    OUT.mkdir(parents=True, exist_ok=True)
    for directory in ("bash-cache", "bash-zoxide", "bash-path #% 日本語"):
        (OUT / directory).mkdir(exist_ok=True)
    rc = OUT / f"bash-{name}.rc"
    rc_text = "\n".join([
        "export TERM=xterm-256color TERM_PROGRAM=WezTerm",
        "export COLUMNS=120 LINES=40",
        "export WEZTERM_NOTIFY_AFTER=2",
        f"export WEZTERM_SHELL_INTEGRATION='{POSIX_ROOT}/shell/wezterm.sh'",
        f"export STARSHIP_CACHE='{ROOT.as_posix()}/tests/starship/bash-cache'",
        f"export STARSHIP_CONFIG='{ROOT.as_posix()}/tests/starship/{config_file}'",
        f"export _ZO_DATA_DIR='{ROOT.as_posix()}/tests/starship/bash-zoxide'",
        f"__BASH_TEST_PATH='{POSIX_ROOT}/tests/starship/bash-path #% 日本語'",
        "HISTFILE=/dev/null; HISTCONTROL=; HISTIGNORE=",
        STATE,
        extra,
        *(INIT[c] for c in order),
        "set -u" if nounset else ":",
    ]) + "\n"
    rc.write_text(rc_text, encoding="utf-8", newline="\n")
    args = [BASH, "--noprofile", "--rcfile", str(rc)]
    if noediting:
        args.append("--noediting")
    args.append("-i")
    env = dict(os.environ)
    env["STARSHIP_CACHE"] = str(OUT / "bash-cache")
    env["_ZO_DATA_DIR"] = str(OUT / "bash-zoxide")
    result = subprocess.run(args, input=("\n".join(COMMANDS) + "\n").encode(), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env, cwd=ROOT, timeout=180)
    (OUT / f"bash-{name}.raw").write_bytes(result.stdout)
    text = result.stdout.decode("utf-8", "replace")
    (OUT / f"bash-{name}.txt").write_text(text.replace("\x1b", "<ESC>").replace("\x07", "<BEL>"), encoding="utf-8")
    records = []
    for match in OSC.finditer(result.stdout):
        record = match[1].decode("utf-8", "replace")
        if "SetUserVar=" in record:
            key, encoded = record.split("SetUserVar=", 1)[1].split("=", 1)
            record = {"var": key, "value": base64.b64decode(encoded).decode("utf-8", "replace")}
        records.append(record)
    summary = {"name": name, "order": order, "exit": result.returncode, "noediting": noediting, "nounset": nounset,
        "a": records.count("133;A"), "b": records.count("133;B"), "c": records.count("133;C"),
        "d": [r for r in records if isinstance(r, str) and r.startswith("133;D")],
        "notifications": [r["value"] for r in records if isinstance(r, dict) and r["var"] == "wezterm_cmd_done"],
        "programs": [r["value"] for r in records if isinstance(r, dict) and r["var"] == "WEZTERM_PROG"],
        "cwd": sorted(set(r for r in records if isinstance(r, str) and r.startswith("7;"))),
        "state": [line for line in text.splitlines() if "__STATE__" in line],
        "stderr_errors": [line for line in text.splitlines() if any(s in line for s in ("unbound variable", "bad substitution", "configuration issue", "Permission denied", "denied", "Unable to", "command not found"))],
        "raw_records": records,
    }
    (OUT / f"bash-{name}.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({k: v for k, v in summary.items() if k not in ("raw_records", "state", "programs", "d")}, ensure_ascii=False))
    return summary

if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "bash-path #% 日本語").mkdir(exist_ok=True)
    (OUT / "bash-zoxide").mkdir(exist_ok=True)
    cases = [
        ("control", "w", "", False, False),
        ("recommended", "swz", "", False, False),
        ("reverse", "wsz", "", False, False),
        ("zoxide-before", "szw", "", False, False),
        ("noediting", "swz", "", True, False),
        ("nounset", "swz", "", True, True),
        ("array-before", "swz", "__bash_extra_a() { printf '__EXTRA_A__%s\\n' \"$?\"; }; __bash_extra_b() { printf '__EXTRA_B__%s\\n' \"$?\"; }; PROMPT_COMMAND=(__bash_extra_a __bash_extra_b)", True, False),
    ]
    summaries = []
    for name, order, extra, noediting, nounset in cases:
        summaries.append(run_case(name, order, extra, noediting, nounset))
    (OUT / "bash-summary.json").write_text(json.dumps(summaries, ensure_ascii=False, indent=2), encoding="utf-8")
