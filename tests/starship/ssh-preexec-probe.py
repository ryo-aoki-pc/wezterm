"""状態保存前フックの影響を最小 stub で診断する。実機 SSH の障害検証ではない。

Starship は実体を利用するが、公式 bash-preexec の __bp_install・DEBUG trap・
初回の PROMPT_COMMAND 再構成を模擬しない。公式統合の通常ログインを代替できない。
実機 kawasaki-pi の通常 / TERM_PROGRAM 強制ログインでは、パイプ状態は保持された。
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = HERE / "ssh-results"
OUT.mkdir(exist_ok=True)
parser = argparse.ArgumentParser()
parser.add_argument("--label", default="preexec-probe", help="診断記録のファイル名（拡張子なし）")
args = parser.parse_args()
if not re.fullmatch(r"[a-zA-Z0-9_-]+", args.label):
    parser.error("label は英数字・ハイフン・アンダースコアだけにしてください")
env = os.environ.copy()
source_hash = hashlib.sha256((ROOT / "shell" / "wezterm.sh").read_bytes()).hexdigest()
commands = """false | true
printf 'INTEGRATED_PIPE=%s\\n' "${STARSHIP_PIPE_STATUS[*]}"
set -o pipefail; false | true
printf 'INTEGRATED_FAIL_PIPE=%s STATUS=%s\\n' "${STARSHIP_PIPE_STATUS[*]}" "$STARSHIP_CMD_STATUS"
exit
"""
result = subprocess.run(
    [r"C:\Program Files\Git\bin\bash.exe", "--noprofile", "--rcfile", str(HERE / "ssh-preexec-probe.sh"), "--noediting", "-i"],
    input=commands.encode(), cwd=ROOT, env=env, capture_output=True, timeout=40,
)
raw = result.stdout + result.stderr
(OUT / (args.label + ".raw")).write_bytes(raw)
plain = re.sub(rb"\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)", b"", raw)
plain = re.sub(rb"\x1b\[[0-?]*[ -/]*[@-~]", b"", plain).decode("utf-8", "replace")
(OUT / (args.label + ".txt")).write_text(plain, encoding="utf-8")
fields = {}
for line in plain.splitlines():
    match = re.fullmatch(r"(BASELINE_PIPE|INTEGRATED_PIPE|INTEGRATED_FAIL_PIPE|PROMPT_COMMAND|PRECMD_FUNCTIONS)=(.*)", line)
    if match:
        fields[match[1]] = match[2]
fields["exit_code"] = result.returncode
fields["source_sha256"] = source_hash
fields["source_stable"] = source_hash == hashlib.sha256((ROOT / "shell" / "wezterm.sh").read_bytes()).hexdigest()
fields["pipeline_preserved"] = fields.get("INTEGRATED_PIPE") == fields.get("BASELINE_PIPE") == "1 0"
fields["probe_kind"] = "minimal_stub_hook_before_state_capture"
fields["not_reproduced"] = ["SSH communication", "official __bp_install", "official DEBUG trap", "initial PROMPT_COMMAND reconstruction"]
fields["interpretation"] = "pipeline_preserved は stub 条件だけの結果。実機公式統合の通常ログインでの障害を示さない。"
(OUT / (args.label + ".json")).write_text(json.dumps(fields, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(json.dumps(fields, indent=2, ensure_ascii=False))
