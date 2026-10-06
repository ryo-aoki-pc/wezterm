"""終了コードと PIPESTATUS、配列フック、再読み込みの比較。"""
import importlib.util
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("bash_runner", HERE / "bash-run.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)

runner.COMMANDS = [
    "printf '__STEP__ first\\n'; __bash_test_state",
    "false | true",
    "__bash_test_state",
    "set -o pipefail; false | true",
    "__bash_test_state",
    "false",
    "__bash_test_state",
    "printf '__STEP__ source_twice\\n'; . \"$WEZTERM_SHELL_INTEGRATION\"; . \"$WEZTERM_SHELL_INTEGRATION\"",
    "false",
    "__bash_test_state",
    "printf '__STEP__ done\\n'",
    "exit",
]
runner.INIT["a"] = '''__bash_tail() { local st=$?; printf '__TAIL__%s\\n' "$st"; return "$st"; }; PROMPT_COMMAND=(starship_precmd __bash_tail)'''
runner.INIT["b"] = '''PROMPT_COMMAND=(starship_precmd __wezterm_prompt_command)'''
runner.INIT["m"] = '''PROMPT_COMMAND=(starship_precmd __wz_mouse_off)'''

cases = [
    ("pipeline-starship-only", "s", ""),
    ("pipeline-recommended", "sw", ""),
    ("pipeline-reverse", "ws", ""),
    ("array-after-real", "saw", ""),
    ("array-existing-wz-tail", "swbw", ""),
    ("array-existing-mouse-tail", "swmw", ""),
    ("official-present", "w", "__wezterm_set_user_var() { :; }"),
    ("user-ps0", "sw", "PS0='USER_PS0[$?] '; PS1='USER_PS1> '"),
]
summaries = [runner.run_case(name, order, extra, True) for name, order, extra in cases if len(sys.argv) == 1 or name in sys.argv[1:]]
(HERE / "bash-focused-summary.json").write_text(json.dumps(summaries, ensure_ascii=False, indent=2), encoding="utf-8")
