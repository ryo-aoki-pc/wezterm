"""既存 SSH ホストの Starship とシェル統合を読み取り専用で確認する。"""
from pathlib import Path
import json
import os
import subprocess

HERE = Path(__file__).resolve().parent
OUT = HERE / "ssh-results"
OUT.mkdir(exist_ok=True)
SCRIPT = r'''
printf '__ENVIRONMENT__\n'
uname -s
cat /etc/os-release | sed -n '/^PRETTY_NAME=/p'
printf 'BASH_VERSION=%s\n' "$BASH_VERSION"
printf 'STARSHIP_PATH=%s\n' "$(command -v starship)"
starship --version 2>/dev/null || :
printf 'STARSHIP_SHELL=%s\n' "${STARSHIP_SHELL-unset}"
printf 'WEZTERM_SHELL_SKIP_ALL=%s\n' "${WEZTERM_SHELL_SKIP_ALL-unset}"
printf 'WEZTERM_SHELL_INTEGRATION=%s\n' "${WEZTERM_SHELL_INTEGRATION-unset}"
printf 'OFFICIAL_INTEGRATION=%s\n' "${__wezterm_shell_integration-unset}"
printf 'OFFICIAL_FUNCTION='; command -v __wezterm_set_user_var || :
declare -p precmd_functions preexec_functions 2>/dev/null || :
printf 'TERM_PROGRAM=%s\n' "${TERM_PROGRAM-unset}"
declare -p PROMPT_COMMAND PS0 PS1 2>/dev/null
declare -F __wezterm_prompt_command __wezterm_mark_prompt __wz_starship_active starship_precmd || :
printf '__CONFIG_FILE_HASH__\n'
sha256sum "$HOME/.config/wezterm/shell/wezterm.sh"
printf '__PROFILE_REFERENCES__\n'
for f in "$HOME/.bash_profile" "$HOME/.profile" "$HOME/.bashrc" "$HOME/.config/bash/bashrc"; do
  test -f "$f" && awk '/starship|wezterm|zoxide|WEZTERM_SHELL|bashrc/ { printf "%s:%d:%s\n", FILENAME, FNR, $0 }' "$f"
done
printf '__OFFICIAL_INTEGRATION_HEADER__\n'
if test -f /etc/profile.d/wezterm.sh; then sed -n '1,170p' /etc/profile.d/wezterm.sh; fi
'''
results = []
for host in ("kawasaki-pi", "abiko-pi"):
    command = "TERM=xterm-256color TERM_PROGRAM=WezTerm bash -lic " + "'" + SCRIPT.replace("'", "'\\''") + "'"
    run = subprocess.run(["ssh", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes", "-o", "ConnectTimeout=8", host, command], capture_output=True, timeout=35)
    record = {"host": host, "exit_code": run.returncode, "stdout": run.stdout.decode("utf-8", "replace"), "stderr": run.stderr.decode("utf-8", "replace")}
    results.append(record)
    (OUT / f"{host}-probe.txt").write_text(record["stdout"] + "\nSTDERR:\n" + record["stderr"], encoding="utf-8")
    print(host, run.returncode)
    print(record["stdout"][:4500])
    print(record["stderr"])
(OUT / "probe.json").write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
forwarding = []
for host in ("kawasaki-pi", "abiko-pi"):
    for explicit in (False, True):
        options = ["-o", "SendEnv=TERM_PROGRAM"] if explicit else []
        run = subprocess.run(["ssh", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes", "-o", "ConnectTimeout=8", *options, host, r'''printf 'TERM_PROGRAM=%s\n' "${TERM_PROGRAM-unset}"'''], capture_output=True, env={**os.environ, "TERM_PROGRAM": "WezTerm"}, timeout=20)
        record = {"host": host, "explicit_SendEnv": explicit, "exit_code": run.returncode, "stdout": run.stdout.decode("utf-8", "replace"), "stderr": run.stderr.decode("utf-8", "replace")}
        forwarding.append(record)
        print(record)
(OUT / "forwarding.json").write_text(json.dumps(forwarding, ensure_ascii=False, indent=2), encoding="utf-8")
