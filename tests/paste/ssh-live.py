"""Windows SSH の実 ConPTY / PSReadLine 受信を無害な入力で検証する。

Linux の PTY から ssh を起動する。接続元クリップボードと Lua action の検証は
別途実 WezTerm GUI で行う。この検証だけをクライアント全体の試験と扱わない。
基本試験は利用者のプロファイルを読まず、履歴を保存せず、通常設定を変更しない。
親へ戻るオプションは子の通常プロファイルを読み、専用 probe で履歴保存を止める。
"""
from __future__ import annotations

import argparse
import base64
import fcntl
import hashlib
import json
import os
from pathlib import Path
import pty
import re
import select
import struct
import subprocess
import termios
import time
import uuid

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
OSC = re.compile(rb"\x1b\]1337;SetUserVar=([^=;]+)=([^\x07\x1b]*)(?:\x07|\x1b\\)")
KEYS = {
    "receive": b"\x1b[123;88;0;1;24;1_",
    "probe": b"\x1b[122;87;0;1;0;1_",
    "select": b"\x1b[121;86;0;1;0;1_",
    "enter": b"\x1b[13;28;13;1;0;1_",
    "cancel": b"\x1b[67;0;3;1;8;1_",
}


def encoded_command(script: str) -> str:
    return base64.b64encode(script.encode("utf-16le")).decode("ascii")


def ps_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def frame_terminator(nonce: str) -> bytes:
    return ("~WZE2:" + nonce + "~").encode("ascii")


def remote_powershell(host: str, script: str) -> str:
    result = subprocess.run(
        ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", host,
         "powershell.exe -NoLogo -NoProfile -NonInteractive -EncodedCommand " + encoded_command(script)],
        capture_output=True, timeout=40, check=True,
    )
    return result.stdout.decode("utf-8-sig", "replace").strip()


class Session:
    def __init__(self, host: str, shell: str, remote_dir: str, drop: bool = False, remote_command: str | None = None):
        self.vars: dict[str, str] = {}
        self.events: list[tuple[str, str]] = []
        self.pending = b""
        self.output = b""
        self.query_pending = b""
        self.drop = drop
        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 200, 0, 0))
        bootstrap = "$env:WEZTERM_SSH_PASTE_TEST_PROBE = " + ps_literal(remote_dir + "/ssh-probe.ps1") + "; $env:WEZTERM_SSH_PASTE_TEST_INTEGRATION = " + ps_literal(remote_dir + "/integration.ps1") + "; . " + ps_literal(remote_dir + "/ssh-probe.ps1") + " -IntegrationPath " + ps_literal(remote_dir + "/integration.ps1") + " -Label " + ps_literal(shell + ("-drop" if drop else "-admin"))
        child = shell + ".exe -NoLogo -NoProfile -NoExit -EncodedCommand " + encoded_command(bootstrap)
        if drop:
            outer = '& "$env:LOCALAPPDATA\\setup-notes\\bin\\busybox.exe" drop -- ' + child
            child = "powershell.exe -NoLogo -NoProfile -EncodedCommand " + encoded_command(outer)
        if remote_command is not None:
            child = remote_command
        # Windows OpenSSH の PTY + Git Bash は -c の本文を自動では引用しない。
        # 外側の二重引用符を SSH のコマンド文字列自身へ含める。
        self.proc = subprocess.Popen(
            ["ssh", "-tt", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", host, '"' + child + '"'],
            stdin=slave, stdout=slave, stderr=slave, close_fds=True,
        )
        os.close(slave)
        self.fd = master
        self.records = []
        try:
            if remote_command is None:
                self.wait(lambda: self.vars.get("WEZTERM_PSREADLINE_SSH_PASTE", "").startswith("2:"), 20, "initial marker")
            else:
                self.wait(lambda: b"SSH_BASH_TEST> " in self.output, 20, "Bash initial prompt")
        except Exception:
            self.close()
            raise

    def close(self):
        self.proc.terminate()
        try:
            self.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait(timeout=5)
        os.close(self.fd)

    def send(self, value: bytes):
        view = memoryview(value)
        while view:
            written = os.write(self.fd, view[:8192])
            view = view[written:]
            # ConPTY と SSH の入力 queue を詰まらせないよう、送信中も出力を読む。
            self.pump(0)

    def key(self, name: str):
        self.send(KEYS[name])

    def pump(self, timeout: float = 0.1):
        readable, _, _ = select.select([self.fd], [], [], timeout)
        if not readable:
            return
        try:
            chunk = os.read(self.fd, 65536)
        except OSError as error:
            raise RuntimeError("SSH PTY closed") from error
        if not chunk:
            raise RuntimeError("SSH PTY EOF")
        self.output = (self.output + chunk)[-65536:]
        # 先に ConPTY の cursor position query を返す。分割受信も扱う。
        query = self.query_pending + chunk
        queries = query.count(b"\x1b[6n")
        self.query_pending = query[-3:]
        if queries:
            os.write(self.fd, b"\x1b[1;1R" * queries)
        self.pending += chunk
        consumed = 0
        for match in OSC.finditer(self.pending):
            name = match.group(1).decode("ascii")
            try:
                value = base64.b64decode(match.group(2), validate=True).decode("utf-8")
            except (ValueError, UnicodeError):
                continue
            self.vars[name] = value
            self.events.append((name, value))
            consumed = match.end()
        if consumed:
            self.pending = self.pending[consumed:]
        elif len(self.pending) > 65536 and b"\x1b]1337;SetUserVar=" not in self.pending:
            self.pending = self.pending[-128:]

    def wait(self, predicate, timeout: float = 10, label: str = "condition"):
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            if predicate():
                return
            self.pump(min(0.1, max(0, end - time.monotonic())))
        tail = re.sub(rb"\x1b\[[0-?]*[ -/]*[@-~]", b"", self.output[-1000:])
        raise TimeoutError(label + ": " + repr(tail.decode("utf-8", "replace")))

    def probe(self):
        before = len(self.events)
        self.key("probe")
        self.wait(lambda: any(name == "WEZTERM_SSH_PASTE_TEST" for name, _ in self.events[before:]), label="F11 probe")
        return json.loads(next(value for name, value in self.events[before:] if name == "WEZTERM_SSH_PASTE_TEST"))

    def begin_receive(self):
        epoch = self.vars["WEZTERM_PSREADLINE_SSH_PASTE"].split(":")[1]
        before = len(self.events)
        start = time.monotonic()
        self.key("receive")
        self.wait(lambda: any(name == "WEZTERM_PSREADLINE_SSH_READY" and re.fullmatch("2:" + epoch + ":[0-9a-f]{32}", value) for name, value in self.events[before:]), label="receiver prefix READY")
        ready = next(value for name, value in self.events[before:] if name == "WEZTERM_PSREADLINE_SSH_READY" and re.fullmatch("2:" + epoch + ":[0-9a-f]{32}", value))
        nonce = ready.split(":")[2]
        return {"epoch": epoch, "nonce": nonce, "before": before, "start": start}

    def has_result(self, transaction):
        return any(name == "WEZTERM_PSREADLINE_SSH_RESULT" and value.startswith("2:" + transaction["epoch"] + ":") for name, value in self.events[transaction["before"]:])

    def has_body_ready(self, transaction):
        expected = "2:" + transaction["epoch"] + ":" + transaction["nonce"] + ":body"
        return any(name == "WEZTERM_PSREADLINE_SSH_READY" and value == expected for name, value in self.events[transaction["before"]:])

    def prepare_body(self, transaction, prefix=None):
        if prefix is None:
            prefix = ("WZP2:" + transaction["nonce"] + ":").encode("ascii")
        self.send(prefix)
        self.wait(lambda: self.has_body_ready(transaction) or self.has_result(transaction), 10, "receiver body READY")
        return self.has_body_ready(transaction)

    def finish_receive(self, transaction, frame_length=0):
        self.wait(lambda: self.has_result(transaction), max(30, frame_length / 600), "receiver RESULT")
        result = next(value for name, value in self.events[transaction["before"]:] if name == "WEZTERM_PSREADLINE_SSH_RESULT" and value.startswith("2:" + transaction["epoch"] + ":"))
        self.last_receive_seconds = round(time.monotonic() - transaction["start"], 3)
        return result, self.probe()

    def receive(self, data: bytes, mutate=None, cancel=False, omit=False, cancel_before_body=False):
        transaction = self.begin_receive()
        nonce = transaction["nonce"]
        payload = base64.b64encode(data).decode("ascii")
        terminator = frame_terminator(nonce)
        frame = f"WZP2:{nonce}:{len(payload)}:{payload}".encode("ascii") + terminator
        if mutate:
            frame = mutate(frame, nonce)
        parts = frame.split(b":", 2)
        prefix = b":".join(parts[:2]) + b":"
        body = parts[2]
        # 誤った nonce や未開始 timeout の後には本文を一切送らない。
        if not omit and self.prepare_body(transaction, prefix):
            if cancel_before_body:
                self.key("cancel")
                self.send(terminator)
            elif cancel:
                middle = min(len(body) - 1, 12)
                self.send(body[:middle])
                self.key("cancel")
                self.send(body[middle:])
            elif body.endswith(b"\n" + terminator):
                # 生 LF は Windows の端末入力変換を通るため、U+000A のキー通知で
                # 受信データ末尾の LF を正確に再現する。
                self.send(body[:-len(terminator) - 1])
                self.send(b"\x1b[13;28;10;1;0;1_")
                self.send(terminator)
            else:
                self.send(body)
        return self.finish_receive(transaction, len(frame))

    def cancel_buffer(self):
        epoch = self.vars["WEZTERM_PSREADLINE_SSH_PASTE"]
        self.key("cancel")
        self.wait(lambda: self.vars.get("WEZTERM_PSREADLINE_SSH_PASTE", "") not in ("", epoch), label="cancel new epoch")


def normalized(text: str) -> str:
    return text.replace("\r", "").replace("\t", "    ")


def bash_return_case(host: str, shell: str, remote_dir: str):
    session = Session(host, shell, remote_dir, remote_command="bash --noprofile --rcfile " + ps_literal(remote_dir + "/ssh-bash.rc") + " -i")
    try:
        body = '. "$env:WEZTERM_SSH_PASTE_TEST_PROBE" -IntegrationPath "$env:WEZTERM_SSH_PASTE_TEST_INTEGRATION" -Label "' + shell + '-from-bash"'
        command = shell + ".exe -NoLogo -NoExit -Command " + ps_literal(body)
        session.send(command.encode() + b"\r")
        session.wait(lambda: session.vars.get("WEZTERM_PSREADLINE_SSH_PASTE", "").startswith("2:"), 30, "PowerShell from Bash marker")
        child = session.probe()
        cancelled, capture = session.receive(b"known cancelled input" * 10, cancel=True)
        body_cancelled, body_capture = session.receive(b"must never reach parent", cancel_before_body=True)
        result, _ = session.receive(b"exit")
        before = len(session.events)
        session.output = b""
        session.key("enter")
        session.wait(lambda: b"SSH_BASH_TEST> " in session.output and all(session.vars.get(name) == "" for name in ("WEZTERM_PSREADLINE_SSH_PASTE", "WEZTERM_PSREADLINE_SSH_READY", "WEZTERM_PSREADLINE_SSH_RESULT")), 30, "Bash returned and markers clear")
        session.send(b"\x18\x02")
        session.wait(lambda: any(name == "WEZTERM_SSH_BASH_PROBE" for name, _ in session.events[before:]), label="Bash buffer probe")
        buffer = next(value for name, value in session.events[before:] if name == "WEZTERM_SSH_BASH_PROBE")
        checks = {
            "powershell_administrator": child["administrator"] is True,
            "cancel_not_inserted": ":error:" in cancelled and capture["buffer"] == "" and capture["executed"] == 0,
            "before_body_cancelled_not_inserted": body_cancelled.endswith(":error:cancelled") and body_capture["buffer"] == "" and body_capture["executed"] == 0,
            "exit_inserted": result.endswith(":ok"),
            "bash_markers_cleared": all(session.vars.get(name) == "" for name in ("WEZTERM_PSREADLINE_SSH_PASTE", "WEZTERM_PSREADLINE_SSH_READY", "WEZTERM_PSREADLINE_SSH_RESULT")),
            "bash_buffer_empty": buffer == "",
        }
        row = {"name": "powershell-exit-bash-return", "passed": all(checks.values()), "checks": checks, "powershell_reads_normal_profile": True}
        print(json.dumps({"label": shell + "-from-bash", **row}, ensure_ascii=False), flush=True)
        return {"environment": {"label": shell + "-from-bash"}, "passed": row["passed"], "cases": [row]}
    finally:
        session.close()


def drop_return_case(session: Session, shell: str):
    parent = session.probe()
    body = '. "$env:WEZTERM_SSH_PASTE_TEST_PROBE" -IntegrationPath "$env:WEZTERM_SSH_PASTE_TEST_INTEGRATION" -Label "' + shell + '-return-child"'
    command = '& "$env:LOCALAPPDATA\\setup-notes\\bin\\busybox.exe" drop -- ' + shell + '.exe -NoLogo -NoExit -Command ' + ps_literal(body)
    result, _ = session.receive(command.encode())
    old_epoch = session.vars["WEZTERM_PSREADLINE_SSH_PASTE"]
    session.key("enter")
    session.wait(lambda: session.vars.get("WEZTERM_PSREADLINE_SSH_PASTE", "") not in ("", old_epoch), 30, "drop child marker")
    child = session.probe()
    cancelled, captured = session.receive(b"cancelled known child input" * 10, cancel=True)
    body_cancelled, body_capture = session.receive(b"must never reach administrator parent", cancel_before_body=True)
    child_exit, _ = session.receive(b"exit")
    old_events = len(session.events)
    old_epoch = session.vars["WEZTERM_PSREADLINE_SSH_PASTE"]
    session.key("enter")
    session.wait(lambda: session.vars.get("WEZTERM_PSREADLINE_SSH_PASTE", "") not in ("", old_epoch), 30, "parent return marker")
    returned = session.probe()
    checks = {
        "command_inserted": result.endswith(":ok"),
        "same_user": child["user"] == parent["user"] == returned["user"],
        "child_nonadministrator": child["administrator"] is False,
        "child_medium": any("S-1-16-8192" in line for line in child["groups"]),
        "child_admin_sid_deny_only": any("S-1-5-32-544" in line and re.search(r"deny|拒否", line, re.IGNORECASE) for line in child["groups"]),
        "cancelled_not_inserted": ":error:" in cancelled and captured["buffer"] == "" and captured["executed"] == 0,
        "before_body_cancelled_not_inserted": body_cancelled.endswith(":error:cancelled") and body_capture["buffer"] == "" and body_capture["executed"] == 0,
        "child_exit_inserted": child_exit.endswith(":ok"),
        "parent_administrator": returned["administrator"] is True,
        "parent_buffer_empty": returned["buffer"] == "",
        "parent_execution_count_unchanged": returned["executed"] == parent["executed"],
        "parent_label_restored": returned["label"] == parent["label"],
        "child_marker_cleared": any(name == "WEZTERM_PSREADLINE_SSH_PASTE" and value == "" for name, value in session.events[old_events:]),
    }
    row = {"name": "drop-child-exit-parent-return", "passed": all(checks.values()), "checks": checks, "child_reads_normal_profile": True}
    print(json.dumps({"label": parent["label"], **row}, ensure_ascii=False), flush=True)
    return row


def run_cases(session: Session, large: bool, large_size: int):
    records = session.records
    initial = session.probe()
    environment = {key: initial[key] for key in ("label", "powershell", "psreadline", "edit_mode", "user", "administrator", "groups")}

    def record(name, checks, **extra):
        row = {"name": name, "passed": all(checks.values()), "checks": checks, **extra}
        records.append(row)
        print(json.dumps({"label": environment["label"], **row}, ensure_ascii=False), flush=True)

    admin_groups = [line for line in initial["groups"] if "S-1-5-32-544" in line]
    privilege_checks = {"administrator_expected": initial["administrator"] is not session.drop}
    if session.drop:
        privilege_checks["medium_integrity"] = any("S-1-16-8192" in line for line in initial["groups"])
        privilege_checks["administrator_sid_deny_only"] = any(re.search(r"deny|拒否", line, re.IGNORECASE) for line in admin_groups)
    record("privilege", privilege_checks)

    values = {
        "lf": "& {\n  $global:SSHPasteProbeExecuted++\n  $global:SSHPasteProbeValue = 'LF'\n}",
        "crlf": "& {\r\n  $global:SSHPasteProbeExecuted++\r\n  $global:SSHPasteProbeValue = 'CRLF'\r\n}",
        "blank-japanese-emoji": "& {\n\n  $global:SSHPasteProbeExecuted++\n  $global:SSHPasteProbeValue = '日本語 😀 二行目'\n\n}",
        "here-string": "& {\n  $global:SSHPasteProbeExecuted++\n  $global:SSHPasteProbeValue = @'\n一行目\n\n二行目 😀\n'@\n}",
        "tab-trailing-newline": "& {\n\t$global:SSHPasteProbeExecuted++\n\t$global:SSHPasteProbeValue = '末尾'\n}\n",
        "large": "& {\n  $global:SSHPasteProbeExecuted++\n  # " + "x" * max(0, large_size - 44) + "\n}",
    }
    count = initial["executed"]
    for name, text in values.items():
        result, before = session.receive(text.encode("utf-8"))
        expected = normalized(text)
        checks = {"result_ok": result.endswith(":ok"), "buffer_equal": before["buffer"] == expected, "not_executed_before_enter": before["executed"] == count}
        old_events = len(session.events)
        old_epoch = session.vars["WEZTERM_PSREADLINE_SSH_PASTE"]
        session.key("enter")
        session.wait(lambda: session.vars.get("WEZTERM_PSREADLINE_SSH_PASTE", "") not in ("", old_epoch), 20, "execution new epoch")
        after = session.probe()
        count += 1
        checks["executed_once_after_enter"] = after["executed"] == count
        checks["markers_clear_before_execution"] = any(name == "WEZTERM_PSREADLINE_SSH_PASTE" and value == "" for name, value in session.events[old_events:])
        record(name, checks, characters=len(expected), receive_seconds=session.last_receive_seconds, sha256=hashlib.sha256(expected.encode()).hexdigest())

    # 選択範囲を Replace し、古い本文が残らないことを確かめる。
    session.receive(b"old selected text")
    before_select = len(session.events)
    session.key("select")
    session.wait(lambda: any(name == "WEZTERM_SSH_PASTE_TEST" for name, _ in session.events[before_select:]), label="selection probe")
    selected = json.loads(next(value for name, value in session.events[before_select:] if name == "WEZTERM_SSH_PASTE_TEST"))
    replacement = "日本語\n新しい本文\n"
    result, replaced = session.receive(replacement.encode())
    record("selection-replace", {"selected": selected["selection_length"] > 0, "result_ok": result.endswith(":ok"), "buffer_equal": replaced["buffer"] == replacement, "not_executed": replaced["executed"] == count}, actual_buffer=replaced["buffer"] if replaced["buffer"] != replacement else None)
    session.cancel_buffer()

    invalid = [
        ("wrong-nonce", b"known", lambda frame, nonce: frame.replace(nonce.encode(), b"0" * 32, 1)),
        ("wrong-length", b"known", lambda frame, nonce: frame.replace(b":8:", b":7:", 1)),
        ("invalid-base64", b"known", lambda frame, nonce: frame.replace(b":a25vd24=", b":a25vd24?", 1)),
        ("newline-before-terminator", b"known", lambda frame, nonce: frame[:-len(frame_terminator(nonce))] + b"\n" + frame_terminator(nonce)),
        ("invalid-utf8", b"\xff", None),
        ("nul", b"a\0b", None),
    ]
    if large:
        invalid.append(("oversized", b"x" * (65536 + 1), None))
    for name, data, mutate in invalid:
        result, capture = session.receive(data, mutate=mutate)
        record(name, {"result_error": ":error:" in result, "empty_buffer": capture["buffer"] == "", "not_executed": capture["executed"] == count}, result=result.rsplit(":", 1)[-1])
    result, capture = session.receive(b"cancelled known input" * 10, cancel=True)
    record("cancel-during-frame", {"result_error": ":error:" in result, "empty_buffer": capture["buffer"] == "", "not_executed": capture["executed"] == count}, result=result.rsplit(":", 1)[-1])
    result, capture = session.receive(b"", omit=True)
    record("receiver-no-frame-timeout", {"result_error": ":error:" in result, "empty_buffer": capture["buffer"] == "", "not_executed": capture["executed"] == count}, result=result.rsplit(":", 1)[-1])

    # 最初の READY は本文の送信許可ではない。前置不正・取消があっても
    # 正しい prefix の確認までは本文を送らず、確認後は終端まで排出する。
    for name, noise in (("terminator-before-prefix", b"~"), ("ordinary-character-before-prefix", b"x")):
        transaction = session.begin_receive()
        session.send(noise)
        session.pump(0.3)
        premature_result = session.has_result(transaction)
        premature_ready = session.has_body_ready(transaction)
        body_ready = session.prepare_body(transaction)
        if body_ready:
            session.send(b"8:a25vd24=" + frame_terminator(transaction["nonce"]))
        result, capture = session.finish_receive(transaction)
        record(name, {"no_early_result": not premature_result, "no_early_body_ready": not premature_ready, "body_ready_after_prefix": body_ready, "result_invalid": result.endswith(":error:invalid"), "empty_buffer": capture["buffer"] == "", "not_executed": capture["executed"] == count})

    transaction = session.begin_receive()
    session.key("cancel")
    body_ready = session.prepare_body(transaction)
    if body_ready:
        session.send(b"8:a25vd24=" + frame_terminator(transaction["nonce"]))
    result, capture = session.finish_receive(transaction)
    record("cancel-before-prefix-with-prefix", {"body_ready_after_prefix": body_ready, "result_cancelled": result.endswith(":error:cancelled"), "empty_buffer": capture["buffer"] == "", "not_executed": capture["executed"] == count})

    transaction = session.begin_receive()
    session.key("cancel")
    result, capture = session.finish_receive(transaction)
    record("cancel-before-prefix-timeout", {"result_cancelled": result.endswith(":error:cancelled"), "body_not_requested": not session.has_body_ready(transaction), "absolute_deadline": 4.5 <= session.last_receive_seconds < 8, "empty_buffer": capture["buffer"] == "", "not_executed": capture["executed"] == count}, receive_seconds=session.last_receive_seconds)

    transaction = session.begin_receive()
    session.send(b"WZP2:")
    result, capture = session.finish_receive(transaction)
    record("partial-prefix-timeout", {"result_timeout": result.endswith(":error:timeout"), "body_not_requested": not session.has_body_ready(transaction), "absolute_deadline": 4.5 <= session.last_receive_seconds < 8, "empty_buffer": capture["buffer"] == "", "not_executed": capture["executed"] == count}, receive_seconds=session.last_receive_seconds)

    transaction = session.begin_receive()
    while time.monotonic() - transaction["start"] < 4.6 and not session.has_result(transaction):
        session.send(b"x")
        session.pump(0.1)
    result, capture = session.finish_receive(transaction)
    record("continuous-prefix-noise-deadline", {"result_invalid": result.endswith(":error:invalid"), "body_not_requested": not session.has_body_ready(transaction), "absolute_deadline": 4.5 <= session.last_receive_seconds < 8, "empty_buffer": capture["buffer"] == "", "not_executed": capture["executed"] == count}, receive_seconds=session.last_receive_seconds)

    transaction = session.begin_receive()
    prefix = ("WZP2:" + transaction["nonce"] + ":").encode("ascii")
    session.send(prefix[:-1])
    session.pump(0.3)
    premature_ready = session.has_body_ready(transaction)
    premature_result = session.has_result(transaction)
    body_ready = session.prepare_body(transaction, prefix[-1:])
    # 完全 prefix 後の待機は取消後の尾部排出を守る。本文は送らずに
    # 5 秒を過ぎても復帰しないことを確かめ、最後に終端だけを送る。
    end = time.monotonic() + 5.5
    while time.monotonic() < end and not session.has_result(transaction):
        session.pump(0.1)
    premature_body_result = session.has_result(transaction)
    if body_ready and not premature_body_result:
        session.send(frame_terminator(transaction["nonce"]))
    result, capture = session.finish_receive(transaction)
    record("prefix-only-waits-for-terminator", {"no_partial_body_ready": not premature_ready, "no_partial_result": not premature_result, "body_ready_after_complete_prefix": body_ready, "no_body_deadline_return": not premature_body_result, "result_invalid": result.endswith(":error:invalid"), "empty_buffer": capture["buffer"] == "", "not_executed": capture["executed"] == count}, receive_seconds=session.last_receive_seconds)

    result, capture = session.receive(b"must never be sent", cancel_before_body=True)
    record("cancel-after-prefix-before-body", {"result_cancelled": result.endswith(":error:cancelled"), "empty_buffer": capture["buffer"] == "", "not_executed": capture["executed"] == count})

    # 本文 ACK 後の手入力 ~ や偽・途中の終端でも親の入力へ戻らない。
    # 遅れて届く既知の本文まで含め、正しい nonce の終端まで排出する。
    for name, make_noise in (
        ("bare-terminator-before-delayed-body", lambda nonce: b"~"),
        ("wrong-nonce-terminator-before-body", lambda nonce: frame_terminator("0" * 32)),
        ("broken-partial-terminator-before-body", lambda nonce: frame_terminator(nonce)[:10] + b"!"),
    ):
        transaction = session.begin_receive()
        body_ready = session.prepare_body(transaction)
        session.send(make_noise(transaction["nonce"]))
        session.pump(0.3)
        premature_result = session.has_result(transaction)
        if body_ready and not premature_result:
            session.send(b"8:a25vd24=" + frame_terminator(transaction["nonce"]))
        result, capture = session.finish_receive(transaction)
        record(name, {"body_ready": body_ready, "no_early_result": not premature_result, "result_invalid": result.endswith(":error:invalid"), "late_body_not_in_buffer": capture["buffer"] == "", "not_executed": capture["executed"] == count})

    transaction = session.begin_receive()
    body_ready = session.prepare_body(transaction)
    terminator = frame_terminator(transaction["nonce"])
    session.send(b"8:a25vd24=" + terminator[:-1])
    session.pump(0.3)
    premature_result = session.has_result(transaction)
    if body_ready and not premature_result:
        session.send(terminator[-1:])
    result, capture = session.finish_receive(transaction)
    record("fragmented-valid-terminator", {"body_ready": body_ready, "no_partial_result": not premature_result, "result_ok": result.endswith(":ok"), "buffer_equal": capture["buffer"] == "known", "not_executed": capture["executed"] == count})
    session.cancel_buffer()

    session.receive(b"existing known buffer")
    result, capture = session.receive(b"\xff")
    record("invalid-data-preserves-existing-buffer", {"result_error": ":error:" in result, "existing_buffer_unchanged": capture["buffer"] == "existing known buffer", "not_executed": capture["executed"] == count})
    session.cancel_buffer()

    # 旧版の Add-Type キャッシュが残っていても V2 を呼ぶことを確認する。
    reload_command = ". $global:SSHPasteProbeIntegration; . $global:SSHPasteProbeIntegration"
    result, capture = session.receive(reload_command.encode())
    old_epoch = session.vars["WEZTERM_PSREADLINE_SSH_PASTE"]
    session.key("enter")
    session.wait(lambda: session.vars.get("WEZTERM_PSREADLINE_SSH_PASTE", "") not in ("", old_epoch), label="reload new epoch")
    result, capture = session.receive("日本語 reload\n".encode())
    record("reload", {"result_ok": result.endswith(":ok"), "buffer_equal": capture["buffer"] == "日本語 reload\n", "not_executed": capture["executed"] == count, "v1_cache_present": capture["reader_v1_loaded"], "v2_reader_present": capture["reader_v2_loaded"]})
    session.cancel_buffer()
    return {"environment": environment, "passed": all(row["passed"] for row in records), "cases": records}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="surface")
    parser.add_argument("--shell", choices=("powershell", "pwsh", "both"), default="both")
    parser.add_argument("--include-drop", action="store_true", help="導入済み busybox drop の子シェルも検証")
    parser.add_argument("--large", action="store_true", help="64 KiB を超える不正入力も排出する")
    parser.add_argument("--large-size", type=int, default=8192, help="正常な大入力の文字数（既定 8192）")
    parser.add_argument("--keep-temp", action="store_true", help="専用 remote 一時ディレクトリを残す")
    parser.add_argument("--drop-return", action="store_true", help="親管理者シェルから通常プロファイルの drop 子へ入り復帰も確認")
    parser.add_argument("--bash-return", action="store_true", help="専用 Git Bash から通常プロファイルの PowerShell を開き親への復帰も確認")
    args = parser.parse_args()
    if args.include_drop or args.drop_return:
        busybox_hash = remote_powershell(args.host, '[Console]::Write((Get-FileHash -Algorithm SHA256 -LiteralPath "$env:LOCALAPPDATA\\setup-notes\\bin\\busybox.exe" -ErrorAction Stop).Hash.ToLowerInvariant())')
        if busybox_hash != "07bb1e5b095b00d68a695481f9240879f33c5724b40aa2308f999d54ed78f075":
            raise RuntimeError("busybox の SHA-256 が指定版と一致しないため降格試験を中止")
    stamp = time.strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:8]
    out = HERE / "results" / ("ssh-" + stamp)
    out.mkdir(parents=True)
    remote_dir = remote_powershell(args.host, '$d = Join-Path $env:TEMP ' + ps_literal("codex-ssh-paste-" + stamp) + '; New-Item -ItemType Directory -Path $d -ErrorAction Stop | Out-Null; [Console]::Write($d.Replace("\\", "/"))')
    sources = {"integration.ps1": ROOT / "shell" / "wezterm.ps1", "ssh-probe.ps1": HERE / "ssh-probe.ps1"}
    if args.bash_return:
        sources["integration.sh"] = ROOT / "shell" / "wezterm.sh"
    source_hashes = {}
    snapshots = {}
    for name, path in sources.items():
        data = path.read_bytes()
        snapshot = out / name
        snapshot.write_bytes(data)
        snapshots[name] = snapshot
        source_hashes[name] = hashlib.sha256(data).hexdigest()
    if args.bash_return:
        rc = "export TERM_PROGRAM=WezTerm HISTFILE=/dev/null\nPS1='SSH_BASH_TEST> '\nexport WEZTERM_SSH_PASTE_TEST_PROBE=" + ps_literal(remote_dir + "/ssh-probe.ps1") + "\nexport WEZTERM_SSH_PASTE_TEST_INTEGRATION=" + ps_literal(remote_dir + "/integration.ps1") + "\n. " + ps_literal(remote_dir + "/integration.sh") + "\n__ssh_bash_probe() { printf '\\033]1337;SetUserVar=WEZTERM_SSH_BASH_PROBE='; printf '%s' \"$READLINE_LINE\" | base64 | tr -d '\\n'; printf '\\007'; }\nbind -x '\"\\C-x\\C-b\":__ssh_bash_probe'\n"
        snapshot = out / "ssh-bash.rc"
        snapshot.write_text(rc, encoding="utf-8")
        snapshots["ssh-bash.rc"] = snapshot
        source_hashes["ssh-bash.rc"] = hashlib.sha256(snapshot.read_bytes()).hexdigest()
    results = []
    try:
        for name, source in snapshots.items():
            subprocess.run(["scp", "-q", str(source), args.host + ":" + remote_dir + "/" + name], check=True, timeout=40)
        for shell in (("powershell", "pwsh") if args.shell == "both" else (args.shell,)):
            for drop in ((False, True) if args.include_drop else (False,)):
                session = None
                try:
                    session = Session(args.host, shell, remote_dir, drop=drop)
                    result = run_cases(session, args.large, args.large_size)
                    if args.drop_return and not drop:
                        result["cases"].append(drop_return_case(session, shell))
                        result["passed"] = all(row["passed"] for row in result["cases"])
                    results.append(result)
                except Exception as error:
                    result = {"environment": {"label": shell + ("-drop" if drop else "-admin")}, "passed": False, "error": str(error), "cases": session.records if session else []}
                    results.append(result)
                    print(json.dumps(result, ensure_ascii=False), flush=True)
                finally:
                    if session:
                        session.close()
            if args.bash_return:
                try:
                    results.append(bash_return_case(args.host, shell, remote_dir))
                except Exception as error:
                    result = {"environment": {"label": shell + "-from-bash"}, "passed": False, "error": str(error)}
                    results.append(result)
                    print(json.dumps(result, ensure_ascii=False), flush=True)
    finally:
        if not args.keep_temp:
            remote_powershell(args.host, "Remove-Item -LiteralPath " + ps_literal(remote_dir) + " -Recurse -Force -ErrorAction Stop")
    summary = {"host": args.host, "transport": "Linux PTY -> ssh -> Windows ConPTY", "client_lua_verified": False, "clipboard": "not accessed", "source_sha256": source_hashes, "passed": bool(results) and all(result["passed"] for result in results), "results": results}
    (out / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"passed": summary["passed"], "summary": str(out / "summary.json")}), flush=True)
    raise SystemExit(0 if summary["passed"] else 1)


if __name__ == "__main__":
    main()
