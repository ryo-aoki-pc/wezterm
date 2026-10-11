"""隔離 GUI で接続元 clipboard と共有貼り付け action の連携を検証する。

Linux は専用 Wayland/X11 上から実 SSH を使う。Windows の --local-ssh-receiver
は SSH 環境を模したローカル ConPTY のみを使い、実 SSH 検証とは区別する。
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import uuid

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
BUSYBOX_SHA256 = "07bb1e5b095b00d68a695481f9240879f33c5724b40aa2308f999d54ed78f075"


def encoded(script):
    return base64.b64encode(script.encode("utf-16le")).decode("ascii")


def literal(value):
    return "'" + value.replace("'", "''") + "'"


def write_json(path, value):
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False), encoding="utf-8")
    for attempt in range(100):
        try:
            temporary.replace(path)
            return
        except PermissionError:
            if attempt == 99:
                raise
            time.sleep(0.01)


def read_json(path, timeout=15):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            return json.loads(path.read_text(encoding="utf-8-sig"))
        except (FileNotFoundError, json.JSONDecodeError):
            time.sleep(0.03)
    raise TimeoutError("試験ファイル待機: " + path.name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="surface")
    parser.add_argument("--include-drop", action="store_true")
    parser.add_argument("--shell", choices=("powershell", "pwsh", "both"), default="both")
    parser.add_argument("--only-drop", action="store_true")
    parser.add_argument("--quick", action="store_true", help="複合 CRLF・空行・日本語・タブ・末尾改行の一入力で試す")
    parser.add_argument("--local-ssh-receiver", action="store_true")
    args = parser.parse_args()
    windows = os.name == "nt"
    if windows and not args.local_ssh_receiver:
        parser.error("Windows は --local-ssh-receiver を明示し、実 SSH と区別してください")
    if not windows and args.local_ssh_receiver:
        parser.error("Linux は実 SSH の検証に使います")
    if not windows and not (os.getenv("WAYLAND_DISPLAY") or os.getenv("DISPLAY")):
        parser.error("利用者の画面から隔離した Wayland/X11 で実行してください")
    stamp = time.strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:8]
    out = HERE / "results" / (("windows-gui-local-" if windows else "linux-gui-ssh-") + stamp)
    out.mkdir(parents=True)
    env = os.environ.copy()
    env["WEZTERM_SSH_PASTE_GUI_OUTPUT"] = str(out)
    wezterm = Path(r"C:\Program Files\WezTerm\wezterm.exe") if windows else Path(shutil.which("wezterm"))
    gui = wezterm.with_name("wezterm-gui.exe") if windows else wezterm
    startup, desktop = None, None
    flags = subprocess.CREATE_NO_WINDOW if windows else 0
    if windows:
        if args.include_drop or args.only_drop:
            busybox = Path(os.environ["LOCALAPPDATA"]) / "setup-notes/bin/busybox.exe"
            if hashlib.sha256(busybox.read_bytes()).hexdigest() != BUSYBOX_SHA256:
                raise RuntimeError("降格用 busybox の SHA-256 が固定版と異なります")
        spec = importlib.util.spec_from_file_location("local_paste_gui", HERE / "live-run.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        desktop = module.TestDesktop()
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = 0
        startup.lpDesktop = desktop.path

    def remote_ps(script):
        result = subprocess.run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", args.host,
            "powershell.exe -NoProfile -NonInteractive -EncodedCommand " + encoded(script)],
            capture_output=True, timeout=40, check=True)
        return result.stdout.decode("utf-8-sig", "replace").strip()

    if not windows and (args.include_drop or args.only_drop):
        remote_ps("if ((Get-FileHash -LiteralPath \"$env:LOCALAPPDATA\\setup-notes\\bin\\busybox.exe\" "
            "-Algorithm SHA256).Hash -ne " + literal(BUSYBOX_SHA256)
            + ") { throw '降格用 busybox の SHA-256 が固定版と異なります' }")

    remote_dir = str(ROOT).replace("\\", "/") if windows else remote_ps(
        "$d=Join-Path $env:TEMP " + literal("codex-ssh-paste-gui-" + stamp)
        + "; New-Item -ItemType Directory -Path $d -ErrorAction Stop | Out-Null; [Console]::Write($d.Replace('\\','/'))")

    def shell_command(shell, drop):
        label = shell + ("-drop" if drop else "-admin")
        integration = remote_dir + ("/shell/wezterm.ps1" if windows else "/integration.ps1")
        probe = remote_dir + ("/tests/paste/ssh-probe.ps1" if windows else "/ssh-probe.ps1")
        bootstrap = ("$env:SSH_CONNECTION='gui-local-test'; " if windows else "")
        bootstrap += ". " + literal(probe) + " -IntegrationPath " + literal(integration) + " -Label " + literal(label)
        bootstrap += r"""; $diag=[ordered]@{
ssh_connection_present=[bool]$env:SSH_CONNECTION
shell_integration_loaded=[bool](Test-Path Function:\__WezTermEnableSshPaste)
readline_wrapper_present=[bool](Test-Path Variable:global:__WezTermWrappedReadLine)
readline_wrapper_current=[object]::ReferenceEquals($function:PSConsoleHostReadLine,$global:__WezTermWrappedReadLine)
paste_key_present=[bool](@(Get-PSReadLineKeyHandler -Bound | Where-Object Function -eq 'WezTermSshPaste').Count)
}; $init=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($diag|ConvertTo-Json -Compress))); [Console]::Write("$([char]27)]1337;SetUserVar=WEZTERM_SSH_PASTE_TEST_INIT=$init$([char]27)\")"""
        program = shell + ".exe"
        if windows and shell == "powershell":
            program = os.environ["SystemRoot"] + "/System32/WindowsPowerShell/v1.0/powershell.exe"
        argv = [program, "-NoLogo", "-NoProfile", "-NoExit", "-EncodedCommand", encoded(bootstrap)]
        if windows:
            if drop:
                argv = [os.environ["LOCALAPPDATA"] + "/setup-notes/bin/busybox.exe", "drop", "--", *argv]
            return argv
        child = " ".join(argv)
        if drop:
            outer = '& "$env:LOCALAPPDATA\\setup-notes\\bin\\busybox.exe" drop -- ' + child
            child = "powershell.exe -NoLogo -NoProfile -EncodedCommand " + encoded(outer)
        return ["ssh", "-tt", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", args.host, '"' + child + '"']

    proc, panes, records = None, [], []
    virtual_input = None
    summary = {"client": "Windows" if windows else "Linux",
        "transport": "GUI -> local ConPTY (SSH environment simulated)" if windows else "GUI -> SSH -> Windows ConPTY",
        "real_ssh": not windows, "clipboard": "test text in isolated GUI", "cases": records,
        "startup": [],
        "sources": {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in (ROOT / "lua/paste.lua", ROOT / "lua/actions.lua", ROOT / "shell/wezterm.ps1", HERE / "ssh-gui-config.lua", HERE / "ssh-probe.ps1")}}
    try:
        if not windows:
            for source, name in ((ROOT / "shell/wezterm.ps1", "integration.ps1"), (HERE / "ssh-probe.ps1", "ssh-probe.ps1")):
                subprocess.run(["scp", "-q", str(source), args.host + ":" + remote_dir + "/" + name], timeout=40, check=True)
        log = (out / "gui.log").open("wb")
        proc = subprocess.Popen([str(gui), "--config-file", str(HERE / "ssh-gui-config.lua"),
            "start", "--always-new-process", "--no-auto-connect", "--class", "codex-ssh-paste-gui-test", "--cwd", str(ROOT), "--",
            *shell_command("powershell", False)], env=env, startupinfo=startup, creationflags=flags, stdout=log, stderr=log)
        log.close()
        socket_root = Path(os.environ["USERPROFILE"]) / ".local/share/wezterm" if windows else Path(env.get("XDG_RUNTIME_DIR", "/tmp")) / "wezterm"
        env["WEZTERM_UNIX_SOCKET"] = str(socket_root / ("gui-sock-" + str(proc.pid)))

        def cli(*arguments, data=None):
            result = subprocess.run([str(wezterm), "cli", "--no-auto-start", "--class", "codex-ssh-paste-gui-test", *map(str, arguments)],
                env=env, input=data, capture_output=True, timeout=20, startupinfo=startup, creationflags=flags)
            if result.returncode:
                raise RuntimeError(result.stderr.decode("utf-8", "replace"))
            return result.stdout.decode("utf-8", "replace")

        deadline = time.monotonic() + 20
        listing = None
        while time.monotonic() < deadline:
            try:
                listing = json.loads(cli("list", "--format", "json"))
                if listing:
                    break
            except RuntimeError:
                pass
            if proc.poll() is not None:
                raise RuntimeError("GUI 終了。gui.log を確認してください")
            time.sleep(0.1)
        if not listing:
            raise TimeoutError("GUI 起動")
        panes.append(listing[0]["pane_id"])
        if not windows and env.get("CODEX_TEST_MUTTER_DBUS"):
            # 隔離 headless Mutter は keyboard が無いので、試験 session にだけ追加する。
            if not env.get("XDG_RUNTIME_DIR", "").startswith("/tmp/codex-ssh-paste-"):
                raise RuntimeError("仮想入力は専用 runtime directory のみに限定します")
            from gi.repository import Gio, GLib
            bus = Gio.DBusConnection.new_for_address_sync(env["CODEX_TEST_MUTTER_DBUS"],
                Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT | Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION, None, None)
            rd = "org.gnome.Mutter.RemoteDesktop"
            def rd_call(path, method, value=None):
                return bus.call_sync(rd, path, rd + (".Session" if path != "/org/gnome/Mutter/RemoteDesktop" else ""),
                    method, value, None, Gio.DBusCallFlags.NONE, 10000, None).unpack()
            rd_path = rd_call("/org/gnome/Mutter/RemoteDesktop", "CreateSession")[0]
            rd_call(rd_path, "Start")
            virtual_input = (rd_call, rd_path)
            time.sleep(0.2)
        serial = 0

        def request(pane, operation, **extra):
            nonlocal serial
            serial += 1
            identifier = f"{serial:05d}-{operation}"
            write_json(out / "request.json", {"id": identifier, "token": str(time.time_ns()), "pane_id": pane, "operation": operation, **extra})
            result = read_json(out / (identifier + ".action.json"))
            if "error" in result:
                raise RuntimeError(result["error"])
            return (read_json(out / (identifier + ".probe.json")) if operation == "probe" else result)

        def wait_marker(pane, previous=None):
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline:
                value = request(pane, "snapshot")
                if value["marker"].startswith("1:") and value["marker"] != previous:
                    return value
            raise TimeoutError("SSH receiver 入力待機")

        def paste(pane, text, route):
            ready = wait_marker(pane)
            if virtual_input:
                rd_call(rd_path, "NotifyKeyboardKeycode", GLib.Variant("(ub)", (29, True)))
                rd_call(rd_path, "NotifyKeyboardKeycode", GLib.Variant("(ub)", (29, False)))
                time.sleep(0.1)
            request(pane, "paste", route=route, text=text)
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline:
                state = request(pane, "snapshot")
                if state["result"].startswith(ready["marker"] + ":"):
                    if not state["result"].endswith(":ok"):
                        raise RuntimeError("受信結果: " + state["result"].rsplit(":", 1)[-1])
                    return request(pane, "probe")
            raise TimeoutError("貼り付け RESULT")

        shapes = {
            "LF": "& {\n  $global:SSHPasteProbeExecuted++\n  $global:SSHPasteProbeValue='LF'\n}",
            "CRLF-blank-Japanese": "& {\r\n\r\n  $global:SSHPasteProbeExecuted++\r\n  $global:SSHPasteProbeValue='日本語 😀'\r\n}",
            "here-string": "& {\n  $global:SSHPasteProbeExecuted++\n  $global:SSHPasteProbeValue=@'\n一行目\n\n二行目 😀\n'@\n}",
            "tabs-trailing": "& {\n\t$global:SSHPasteProbeExecuted++\n}\n",
        }
        if args.quick:
            shapes = {"combined": "& {\r\n\r\n\t$global:SSHPasteProbeExecuted++\r\n\t$global:SSHPasteProbeValue='日本語 😀'\r\n}\r\n"}
        for shell in (("powershell", "pwsh") if args.shell == "both" else (args.shell,)):
            for drop in ((True,) if args.only_drop else (False, True) if args.include_drop else (False,)):
                if shell == "powershell" and not drop:
                    pane = panes[0]
                else:
                    pane = int(cli("spawn", "--window-id", listing[0]["window_id"], "--cwd", str(ROOT), "--", *shell_command(shell, drop)).strip())
                    panes.append(pane)
                cli("activate-pane", "--pane-id", pane)
                ready = wait_marker(pane)
                summary["startup"].append({"shell": shell, "drop": drop, "diagnostic": ready.get("init")})
                initial = request(pane, "probe")
                count = initial["executed"]
                for name, text in shapes.items():
                    for route in ("shared", "right", "key"):
                        before = paste(pane, text, route)
                        old_epoch = request(pane, "snapshot")["marker"]
                        request(pane, "enter")
                        wait_marker(pane, old_epoch)
                        after = request(pane, "probe")
                        count += 1
                        checks = {"buffer_equal": before["buffer"] == text.replace("\r", "").replace("\t", "    "),
                            "not_executed_before_enter": before["executed"] == count - 1,
                            "executed_once_after_enter": after["executed"] == count,
                            "administrator_expected": initial["administrator"] == (not drop)}
                        row = {"shell": shell, "drop": drop, "shape": name, "route": route,
                            "powershell": initial["powershell"], "psreadline": initial["psreadline"], "checks": checks, "passed": all(checks.values())}
                        records.append(row)
                        print(json.dumps(row, ensure_ascii=False), flush=True)
        summary["passed"] = bool(records) and all(row["passed"] for row in records)
    except Exception as error:
        summary.update(passed=False, error=str(error))
        if proc is not None and panes:
            try:
                (out / "failure.screen.txt").write_text(cli("get-text", "--pane-id", panes[-1], "--start-line", -60), encoding="utf-8")
                diagnostic = request(panes[-1], "probe")
                write_json(out / "failure.probe.json", diagnostic)
            except Exception:
                pass
        raise
    finally:
        if proc is not None:
            for pane in panes:
                try:
                    cli("kill-pane", "--pane-id", pane)
                except Exception:
                    pass
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.terminate()
                proc.wait(timeout=5)
        if desktop:
            desktop.close()
        if virtual_input:
            virtual_input[0](virtual_input[1], "Stop")
        if not windows:
            try:
                remote_ps("Remove-Item -LiteralPath " + literal(remote_dir) + " -Recurse -Force -ErrorAction Stop")
            except Exception as error:
                summary.update(passed=False, cleanup_error=str(error))
        write_json(out / "summary.json", summary)
        print(json.dumps({"passed": summary["passed"], "summary": str(out / "summary.json"), "real_ssh": not windows}), flush=True)
    return 0 if summary["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
