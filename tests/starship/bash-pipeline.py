"""Starship status.pipestatus の表示への影響を比較する。"""
import importlib.util
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("bash_runner", HERE / "bash-run.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
runner.COMMANDS = ["false | true", "__bash_test_state", "set -o pipefail; false | true", "__bash_test_state", "exit"]
for name, order in (("pipeline-visible-baseline", "s"), ("pipeline-visible-recommended", "sw"), ("pipeline-visible-reverse", "ws")):
    result = runner.run_case(name, order, "", True, config_file="bash-pipeline.toml")
    for state in result["state"]:
        print(state)
