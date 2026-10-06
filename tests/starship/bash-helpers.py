"""Bash の base64、文字切り詰め、OSC 7 キャッシュを独立に検査する。"""
import base64
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "tests" / "starship"
BASH = r"C:\Program Files\Git\bin\bash.exe"
PRELUDE = "export PATH=/usr/bin:/bin:$PATH; export LANG=en_US.UTF-8; TERM_PROGRAM=WezTerm; PS1='x'; . ./shell/wezterm.sh; "
checks = []

def run_command(command):
    # Win32 argv の ANSI 変換を避け、UTF-8 の stdin で Bash に渡す。
    return subprocess.run([BASH, "--noprofile", "--norc", "-s"], input=command.encode("utf-8"), cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)

for payload in (b"", b"a", b"ab", b"abc", b"abcd", "日本語と emoji 😀".encode(), bytes(range(1, 256))):
    literal = "".join(f"\\x{b:02x}" for b in payload)
    command = PRELUDE + "__wezterm_b64 $'" + literal + "'; printf '%s' \"$__wz_b64\""
    result = run_command(command)
    expected = base64.b64encode(payload)
    checks.append({"test": "base64", "bytes": len(payload), "pass": result.stdout == expected, "stderr": result.stderr.decode("utf-8", "replace")})

for label, payload in (("BMP", "日本語" * 100), ("emoji", "日本語😀" * 70), ("emoji-boundary-199", "x" * 199 + "😀x"), ("emoji-boundary-198", "x" * 198 + "😀x")):
    command = PRELUDE + "s='" + payload + "'; printf '__CHAR_COUNT__%s\\n' \"${#s}\"; __wezterm_uservar test \"$s\""
    result = run_command(command)
    value = re.search(rb"SetUserVar=test=([^\x1b]*)", result.stdout)[1]
    raw = base64.b64decode(value)
    try:
        decoded = raw.decode("utf-8")
        valid_utf8 = True
    except UnicodeDecodeError:
        decoded = raw.decode("utf-8", "replace")
        valid_utf8 = False
    expected = payload[:200] if label == "BMP" else decoded
    checks.append({"test": "uservar truncation " + label, "pass": valid_utf8 and decoded == expected and payload.startswith(decoded), "input_bash_chars": re.search(rb"__CHAR_COUNT__(\d+)", result.stdout)[1].decode(), "output_unicode_chars": len(decoded), "output_bytes": len(raw), "valid_utf8": valid_utf8, "tail": decoded[-5:], "stderr": result.stderr.decode("utf-8", "replace")})

call_log = OUT / "bash-cygpath-calls.txt"
call_log.write_text("", encoding="utf-8")
command = PRELUDE + r'''cygpath() { printf '__CYGPATH_CALL__\n' >> ./tests/starship/bash-cygpath-calls.txt; printf '%s' "$2"; }; __wezterm_osc7; __wezterm_osc7; PWD='/virtual/a #?%\日本語'; __wezterm_osc7; __wezterm_osc7'''
result = run_command(command)
osc7 = re.findall(rb"\x1b\]7;([^\x1b]*)\x1b\\", result.stdout)
calls = call_log.read_text().count("__CYGPATH_CALL__")
checks.append({"test": "OSC7 encoding and cache (cygpath stub)", "pass": len(osc7) == 4 and osc7[0] == osc7[1] and osc7[2] == osc7[3] and calls == 2 and all(x in osc7[2] for x in (b"%20", b"%23", b"%3F", b"%25", b"%5C")), "cygpath_calls": calls, "osc7": [s.decode() for s in osc7]})
(OUT / "bash-helpers.json").write_text(json.dumps(checks, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(checks, ensure_ascii=True, indent=2))
assert all(item["pass"] for item in checks), "Bash helper regression"
