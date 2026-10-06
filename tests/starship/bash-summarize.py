"""代表ログ以外の詳細を小さな検証結果へまとめる。"""
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
names = [
    "control", "recommended", "reverse", "zoxide-before", "noediting", "nounset", "array-before",
    "pipeline-starship-only", "pipeline-recommended", "pipeline-reverse", "array-after-real",
    "array-existing-wz-tail", "array-existing-mouse-tail", "official-present", "user-ps0",
    "pipeline-visible-baseline", "pipeline-visible-recommended", "pipeline-visible-reverse",
]
cases = []
for name in names:
    data = json.loads((HERE / f"bash-{name}.json").read_text(encoding="utf-8"))
    result = {k: v for k, v in data.items() if k not in ("raw_records", "state", "programs")}
    result["states"] = [dict(re.findall(r"(status|pipeline|duration)=(.*?)(?= (?:status|pipeline|duration|ps0)=)", state)) for state in data["state"]]
    if data["state"]:
        result["first_prompt_command"] = data["state"][0].split("pc=", 1)[1]
    result["programs_sent"] = len([p for p in data["programs"] if p])
    result["programs_cleared"] = len([p for p in data["programs"] if not p])
    result["program_samples"] = [p for p in data["programs"] if p][:4]
    cases.append(result)
(HERE / "bash-results.json").write_text(json.dumps(cases, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"{len(cases)} conditions -> bash-results.json")
