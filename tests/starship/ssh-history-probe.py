"""SSH テストが履歴を書き出さないための、設定行だけの読み取り確認。"""
from pathlib import Path
import json
import shlex
import subprocess

HERE = Path(__file__).resolve().parent
COMMAND = r'''
for f in "$HOME/.bash_profile" "$HOME/.bashrc" "$HOME/.config/bash/bashrc" /etc/bashrc; do
  test -r "$f" && awk '/HISTFILE|histappend|history -a|history -w|history -n|history -r|PROMPT_COMMAND/ { printf "%s:%d:%s\n", FILENAME, FNR, $0 }' "$f"
done
'''
run = subprocess.run(["ssh", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes", "-o", "ConnectTimeout=8", "kawasaki-pi", COMMAND], capture_output=True, timeout=20)
record = {"exit_code": run.returncode, "stdout": run.stdout.decode("utf-8", "replace"), "stderr": run.stderr.decode("utf-8", "replace")}
(HERE / "ssh-results" / "history-probe.json").write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")
print(record["stdout"])
print(record["stderr"])
check = r'''printf 'HISTFILE_AFTER_LOGIN=%s\n' "${HISTFILE-unset}"'''
run = subprocess.run(["ssh", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes", "-o", "ConnectTimeout=8", "kawasaki-pi", "HISTFILE=/dev/null bash -lic " + shlex.quote(check)], capture_output=True, timeout=20)
login = {"exit_code": run.returncode, "stdout": run.stdout.decode("utf-8", "replace"), "stderr": run.stderr.decode("utf-8", "replace")}
(HERE / "ssh-results" / "history-login.json").write_text(json.dumps(login, ensure_ascii=False, indent=2), encoding="utf-8")
print(login["stdout"])
