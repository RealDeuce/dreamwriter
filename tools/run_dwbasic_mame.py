#!/usr/bin/env python3
"""Drive DW-BASIC startup in MAME and decode the resulting LCD snapshots."""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import shutil
import socket
import subprocess
import sys
import time
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MAME_DIR = (REPO_ROOT / "../mame").resolve()
DEFAULT_MAME = DEFAULT_MAME_DIR / "drwrt400"
DEFAULT_CARD = Path("/tmp/dw-card-1m-dw-basic.bin")
DEFAULT_SNAP_DIR = DEFAULT_MAME_DIR / "snap" / "drwrt400"
DEFAULT_NVRAM_IMAGE = DEFAULT_MAME_DIR / "nvram" / "drwrt400_1" / "nvram"
DEFAULT_NVRAM_TEMPLATE = (REPO_ROOT / "../nvram-romcard").resolve()
DECODER = REPO_ROOT / "tools" / "decode_lcd_text.py"
DEFAULT_INPUT_BRIDGE = REPO_ROOT / "tools" / "dwbasic_input_bridge.lua"
DEFAULT_INPUT_SOCKET = Path("/tmp/dwbasic-input.sock")
ROM = REPO_ROOT / "v2.1" / "t4_ir_2.1.ic303"
KEYBOARD_SCAN_RATE_HZ = 19660000 / 20480
KEYBOARD_FULL_SCAN_SECONDS = 10 / KEYBOARD_SCAN_RATE_HZ
EXPECTED_SIGNPOSTS = {
    "initial two-button menu": "077277ed26c3894e785697a424da4683144d6841adcdd3b70fe0c734ee3a7f41",
    "WP menu": "f41b0f8db6b3139208077727f72e174ce53cb8d78601ed593ca25dc90c9d3e06",
    "OTHERS menu": "37ca08cd70933de74e9226085241fef3f771aae3202e61d96d6a119541a13eff",
    "prepared ROM CARD menu": "0d6c66e26029048aa8076ef51089bb9f62f6e3dd2ad6005b9281980bed4c38d4",
}


def run(args: list[str], *, check: bool = True, **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(args, check=check, text=True, **kwargs)


def clean_run_state(nvram_image: Path, snap_dir: Path, nvram_source: Path | None) -> None:
    if nvram_image.exists():
        nvram_image.unlink()
    if nvram_source is not None:
        nvram_image.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(nvram_source, nvram_image)
    snap_dir.mkdir(parents=True, exist_ok=True)
    for png in snap_dir.glob("*.png"):
        png.unlink()


def clean_socket(path: Path) -> None:
    if path.exists():
        path.unlink()


def find_mame_window(pid: int, timeout: float) -> str:
    deadline = time.monotonic() + timeout
    candidates = [
        ["xdotool", "search", "--sync", "--pid", str(pid)],
        ["xdotool", "search", "--sync", "--name", "DreamWriter"],
        ["xdotool", "search", "--sync", "--name", "drwrt400"],
        ["xdotool", "search", "--sync", "--class", "MAME"],
    ]
    last_error = ""
    while time.monotonic() < deadline:
        for command in candidates:
            result = run(command, check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            ids = [line.strip() for line in result.stdout.splitlines() if line.strip()]
            if ids:
                return ids[-1]
            last_error = result.stderr.strip()
        time.sleep(0.25)
    raise RuntimeError(f"unable to find MAME window for pid {pid}: {last_error}")


def ensure_process_alive(proc: subprocess.Popen) -> None:
    status = proc.poll()
    if status is not None:
        raise RuntimeError(f"MAME exited unexpectedly with status {status}")


def pointer_position() -> tuple[int, int] | None:
    result = run(["xdotool", "getmouselocation", "--shell"], check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        return None
    values: dict[str, int] = {}
    for line in result.stdout.splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        if key in {"X", "Y"} and value.strip().lstrip("-").isdigit():
            values[key] = int(value)
    if "X" not in values or "Y" not in values:
        return None
    return values["X"], values["Y"]


def monitor_origins() -> list[tuple[int, int, int, int]]:
    result = run(["xrandr", "--listmonitors"], check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        return []
    monitors: list[tuple[int, int, int, int]] = []
    pattern = re.compile(r"\s*\d+:\s+\S+\s+(\d+)/\d+x(\d+)/\d+\+(-?\d+)\+(-?\d+)")
    for line in result.stdout.splitlines():
        match = pattern.match(line)
        if match:
            width, height, x, y = (int(value) for value in match.groups())
            monitors.append((x, y, width, height))
    return monitors


def current_monitor_origin() -> tuple[int, int]:
    pointer = pointer_position()
    if pointer is None:
        return 0, 0
    px, py = pointer
    for x, y, width, height in monitor_origins():
        if x <= px < x + width and y <= py < y + height:
            return x, y
    return 0, 0


def move_window(window_id: str, position: str | None, proc: subprocess.Popen | None = None) -> None:
    if not position:
        return
    if proc is not None:
        ensure_process_alive(proc)
    if position == "top":
        x, y = current_monitor_origin()
        run(["xdotool", "windowmove", window_id, str(x), str(y)])
        return
    if "," in position:
        x, y = position.split(",", 1)
        run(["xdotool", "windowmove", window_id, x.strip(), y.strip()])
        return
    raise ValueError(f"unsupported window position {position!r}; use 'top' or 'x,y'")


def connect_input_bridge(path: Path, proc: subprocess.Popen, timeout: float) -> socket.socket:
    deadline = time.monotonic() + timeout
    last_error: OSError | None = None
    while time.monotonic() < deadline:
        ensure_process_alive(proc)
        stream = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            stream.connect(str(path))
            stream.settimeout(2.0)
            return stream
        except OSError as exc:
            last_error = exc
            stream.close()
            time.sleep(0.05)
    detail = f": {last_error}" if last_error else ""
    raise RuntimeError(f"unable to connect to DW-BASIC input bridge at {path}{detail}")


def bridge_request(stream: socket.socket, command: str) -> str:
    stream.sendall(f"{command}\n".encode("ascii"))
    response = b""
    while b"\n" not in response:
        chunk = stream.recv(4096)
        if not chunk:
            raise RuntimeError("input bridge closed the socket")
        response += chunk
    return response.split(b"\n", 1)[0].decode("utf-8", errors="replace")


def send_bridge_text(stream: socket.socket, text: str, *, add_return: bool) -> None:
    command = "TEXT" if add_return else "TYPE"
    payload = text.encode("utf-8").hex()
    line = bridge_request(stream, f"{command} {payload}")
    if not line.startswith("OK "):
        raise RuntimeError(f"input bridge rejected command: {line}")


def send_bridge_key(stream: socket.socket, key_name: str) -> None:
    line = bridge_request(stream, f"KEY {key_name}")
    if not line.startswith("OK "):
        raise RuntimeError(f"input bridge rejected key {key_name!r}: {line}")


def print_kbd_state(stream: socket.socket) -> None:
    line = bridge_request(stream, "KBDSTATE")
    if not line.startswith("OK KBD "):
        raise RuntimeError(f"input bridge rejected KBDSTATE: {line}")
    print(line[7:])


def print_cpu_state(stream: socket.socket) -> None:
    line = bridge_request(stream, "CPUSTATE")
    if not line.startswith("OK CPU "):
        raise RuntimeError(f"input bridge rejected CPUSTATE: {line}")
    print(line[7:])


def print_debug_state(stream: socket.socket) -> None:
    line = bridge_request(stream, "DBGSTATE")
    if not line.startswith("OK DBG "):
        raise RuntimeError(f"input bridge rejected DBGSTATE: {line}")
    print(line[7:])


def send_debug_command(stream: socket.socket, command: str) -> None:
    payload = command.encode("utf-8").hex()
    line = bridge_request(stream, f"DBGCMD {payload}")
    if not line.startswith("OK DBG"):
        raise RuntimeError(f"input bridge rejected DBGCMD: {line}")
    print(line[7:] if len(line) > 7 else "OK")


def send_debug_batch(stream: socket.socket, commands: list[str]) -> None:
    payload = "\n".join(commands).encode("utf-8").hex()
    line = bridge_request(stream, f"DBGBATCH {payload}")
    if not line.startswith("OK DBG"):
        raise RuntimeError(f"input bridge rejected DBGBATCH: {line}")
    print(line[7:])


def send_debug_simple(stream: socket.socket, command: str) -> None:
    line = bridge_request(stream, command)
    if not line.startswith("OK DBG"):
        raise RuntimeError(f"input bridge rejected {command}: {line}")
    print(line[7:])


def print_debug_log(stream: socket.socket, command: str) -> None:
    old_timeout = stream.gettimeout()
    stream.settimeout(15.0)
    try:
        line = bridge_request(stream, command)
        if not line.startswith("OK DBGLOG "):
            raise RuntimeError(f"input bridge rejected {command}: {line}")
        payload = line[10:]
        if payload:
            print(payload.replace("\x1e", "\n"))
    finally:
        stream.settimeout(old_timeout)


def print_basic_memory(stream: socket.socket, args: str) -> None:
    line = bridge_request(stream, f"MEM {args}")
    if not line.startswith("OK MEM "):
        raise RuntimeError(f"input bridge rejected MEM: {line}")
    print(line[7:])


def print_bus_memory(stream: socket.socket, args: str) -> None:
    line = bridge_request(stream, f"BUSMEM {args}")
    if not line.startswith("OK BUSMEM "):
        raise RuntimeError(f"input bridge rejected BUSMEM: {line}")
    print(line[10:])


def print_linear_memory(stream: socket.socket, args: str) -> None:
    line = bridge_request(stream, f"LINEARMEM {args}")
    if not line.startswith("OK LINEARMEM "):
        raise RuntimeError(f"input bridge rejected LINEARMEM: {line}")
    print(line[13:])


def print_loader_abi(stream: socket.socket) -> None:
    line = bridge_request(stream, "LOADERABI")
    if not line.startswith("OK LOADERABI "):
        raise RuntimeError(f"input bridge rejected LOADERABI: {line}")
    print(line[13:])


def parse_debug_address(text: str) -> int:
    value = text.strip()
    if not value:
        raise ValueError("empty debug address")
    if value.lower().startswith("0x"):
        return int(value, 16)
    if value.lower().endswith("h"):
        return int(value[:-1], 16)
    return int(value, 16)


def debug_trace_action(label: str, *, resume: bool = True) -> str:
    safe_label = re.sub(r"[^A-Za-z0-9_.-]", "_", label)
    suffix = ";go" if resume else ""
    return (
        f'logerror "{safe_label} CS=%04X IP=%04X DS=%04X ES=%04X SS=%04X '
        'SP=%04X AX=%04X BX=%04X CX=%04X DX=%04X SI=%04X DI=%04X FLAGS=%04X\\n",'
        f"ps,pc,ds0,ds1,ss,sp,aw,bw,cw,dw,ix,iy,psw{suffix}"
    )


def debug_registerpoint_commands(entries: list[str], *, resume: bool = True) -> list[str]:
    commands = []
    for entry in entries:
        parts = entry.split(":")
        if len(parts) == 2:
            label, address_text = parts
            address = parse_debug_address(address_text)
            condition = f"pc==0x{address:X}"
        elif len(parts) == 3:
            label, segment_text, address_text = parts
            segment = parse_debug_address(segment_text)
            address = parse_debug_address(address_text)
            condition = f"ps==0x{segment:X} && pc==0x{address:X}"
        else:
            raise ValueError(f"debug breakpoint entry must be LABEL:ADDR or LABEL:CS:ADDR: {entry!r}")
        commands.append(f"rpset {condition},{{{debug_trace_action(label, resume=resume)}}}")
    commands.append("rplist")
    return commands


def debug_breakpoint_commands(entries: list[str]) -> list[str]:
    commands = []
    for entry in entries:
        parts = entry.split(":")
        if len(parts) == 2:
            label, address_text = parts
            address = parse_debug_address(address_text)
            condition = "1"
        elif len(parts) == 3:
            label, segment_text, address_text = parts
            segment = parse_debug_address(segment_text)
            address = parse_debug_address(address_text)
            condition = f"ps==0x{segment:X}"
        else:
            raise ValueError(f"debug breakpoint entry must be LABEL:ADDR or LABEL:CS:ADDR: {entry!r}")
        commands.append(f"bpset 0x{address:X},{condition},{{{debug_trace_action(label, resume=False)}}}")
    commands.append("bplist")
    return commands


def debug_segment_watch_commands() -> list[str]:
    condition = (
        "temp4 < 96 && ps != 0DC98 && temp0 != 0DC98 && "
        "(ps < 0C000 || temp0 < 0C000) && "
        "(ps != temp0 || ds0 != temp1 || ds1 != temp2 || ss != temp3)"
    )
    action = (
        'logerror "SEGCHANGE CS:%04X->%04X IP=%04X DS:%04X->%04X '
        'ES:%04X->%04X SS:%04X->%04X SP=%04X AX=%04X BX=%04X CX=%04X '
        'DX=%04X SI=%04X DI=%04X FLAGS=%04X\\n",'
        "temp0,ps,pc,temp1,ds0,temp2,ds1,temp3,ss,sp,aw,bw,cw,dw,ix,iy,psw;"
        "temp4++;temp0=ps;temp1=ds0;temp2=ds1;temp3=ss;go"
    )
    return [
        "temp0=ps",
        "temp1=ds0",
        "temp2=ds1",
        "temp3=ss",
        "temp4=0",
        f"rpset {{{condition}}},{{{action}}}",
        "rplist",
    ]


def install_debug_setup(
    input_stream: socket.socket,
    fixed_points: list[str],
    stop_points: list[str],
    segment_watch: bool,
) -> None:
    commands: list[str] = []
    if fixed_points or stop_points or segment_watch:
        if stop_points:
            commands.append("bpclear")
        commands.append("rpclear")
    if fixed_points:
        commands.extend(debug_registerpoint_commands(fixed_points))
    if stop_points:
        commands.extend(debug_breakpoint_commands(stop_points))
    if segment_watch:
        commands.extend(debug_segment_watch_commands())
    if commands:
        commands.append("rplist")
        send_debug_batch(input_stream, commands)


def snapshot(
    input_stream: socket.socket,
    snap_dir: Path,
    timeout: float,
) -> Path:
    before = {path.name for path in snap_dir.glob("*.png")}
    line = bridge_request(input_stream, "SNAP")
    if line != "OK SNAP":
        raise RuntimeError(f"input bridge rejected SNAP: {line}")
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        after = sorted(snap_dir.glob("*.png"))
        created = [path for path in after if path.name not in before]
        if created:
            return created[-1]
        time.sleep(0.10)
    raise RuntimeError(f"MAME did not create a snapshot in {snap_dir}")


def decode_snapshot(
    path: Path,
    *,
    allow_cursor: bool = False,
    allow_inverse: bool = False,
    attrs: bool = False,
) -> str:
    command = [sys.executable, str(DECODER), str(path), "--rom", str(ROM)]
    if allow_cursor:
        command.append("--allow-cursor")
    if allow_inverse:
        command.append("--allow-inverse")
    if attrs:
        command.append("--attrs")
    result = run(
        command,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode:
        return result.stderr.rstrip()
    return result.stdout.rstrip("\n")


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def check_signpost(path: Path, label: str) -> None:
    expected = EXPECTED_SIGNPOSTS[label]
    actual = file_sha256(path)
    if actual != expected:
        raise RuntimeError(
            f"{label} signpost mismatch for {path}\n"
            f"expected {expected}\n"
            f"actual   {actual}"
        )


def wait_for_signpost(
    input_stream: socket.socket,
    snap_dir: Path,
    label: str,
    timeout: float,
    interval: float,
    snapshot_timeout: float,
) -> Path:
    expected = EXPECTED_SIGNPOSTS[label]
    deadline = time.monotonic() + timeout
    last_actual = ""
    last_path: Path | None = None
    while time.monotonic() < deadline:
        path = snapshot(
            input_stream,
            snap_dir,
            snapshot_timeout,
        )
        actual = file_sha256(path)
        if actual == expected:
            return path
        last_actual = actual
        last_path = path
        time.sleep(interval)
    raise RuntimeError(
        f"{label} signpost did not appear within {timeout:.1f}s\n"
        f"expected {expected}\n"
        f"last     {last_actual or '(no snapshot)'}"
        + (f"\nlast path {last_path}" if last_path else "")
    )


def decoded_lines(text: str) -> list[str]:
    return [line.rstrip() for line in text.splitlines()]


def slice_lines(text: str, start_line: int | None, end_line: int | None) -> str:
    lines = decoded_lines(text)
    if start_line is None and end_line is None:
        return "\n".join(lines)
    start = 1 if start_line is None else start_line
    end = len(lines) if end_line is None else end_line
    if start < 1 or end < start:
        raise ValueError("line range must be 1-based with start <= end")
    return "\n".join(lines[start - 1 : end])


def changed_lines(previous: str | None, current: str) -> str:
    current_lines = decoded_lines(current)
    if previous is None:
        return "\n".join(current_lines)

    previous_lines = decoded_lines(previous)
    unchanged = {
        index
        for index, line in enumerate(current_lines)
        if index < len(previous_lines) and line == previous_lines[index]
    }

    for offset in range(1, len(previous_lines)):
        match_count = min(len(current_lines), len(previous_lines) - offset)
        if match_count <= 0:
            continue
        if all(current_lines[index] == previous_lines[offset + index] for index in range(match_count)):
            unchanged.update(range(match_count))
            break

    return "\n".join(line for index, line in enumerate(current_lines) if index not in unchanged)


def parse_snap_command(command: str) -> tuple[str, float, int | None, int | None, bool]:
    parts = command.split()
    show_attrs = False
    if "attrs" in {part.lower() for part in parts[1:]}:
        show_attrs = True
        parts = [parts[0], *(part for part in parts[1:] if part.lower() != "attrs")]
    if len(parts) == 1:
        return "changed", 0.0, None, None, show_attrs
    if len(parts) == 2 and parts[1].lower() == "all":
        return "all", 0.0, None, None, show_attrs
    if len(parts) == 3 and parts[1].lower() == "all":
        try:
            return "all", float(parts[2]), None, None, show_attrs
        except ValueError as exc:
            raise ValueError("snap delay must be numeric") from exc
    if len(parts) == 3 and parts[2].lower() == "all":
        try:
            return "all", float(parts[1]), None, None, show_attrs
        except ValueError as exc:
            raise ValueError("snap delay must be numeric") from exc
    if len(parts) == 2:
        try:
            return "changed", float(parts[1]), None, None, show_attrs
        except ValueError as exc:
            raise ValueError("usage: :snap [attrs] [all [delay]|delay [all]|start-line end-line|delay start-line end-line]") from exc
    try:
        if len(parts) == 3:
            return "range", 0.0, int(parts[1]), int(parts[2]), show_attrs
        if len(parts) == 4:
            return "range", float(parts[1]), int(parts[2]), int(parts[3]), show_attrs
    except ValueError as exc:
        raise ValueError("snap delay/range must be numeric") from exc
    raise ValueError("usage: :snap [attrs] [all [delay]|delay [all]|start-line end-line|delay start-line end-line]")


def print_snapshot(path: Path, decoded: str | None = None, start_line: int | None = None, end_line: int | None = None) -> None:
    print(f"\n== {path.name} ==")
    if decoded is None:
        decoded = decode_snapshot(path, allow_cursor=True, allow_inverse=True)
    print(slice_lines(decoded, start_line, end_line))


def take_decoded_snapshot(
    input_stream: socket.socket,
    snap_dir: Path,
    snapshot_timeout: float,
) -> tuple[Path, str]:
    path = snapshot(input_stream, snap_dir, snapshot_timeout)
    decoded = decode_snapshot(path, allow_cursor=True, allow_inverse=True)
    return path, decoded


def interactive_loop(
    input_stream: socket.socket,
    snap_dir: Path,
    snapshot_timeout: float,
    cached_snapshot: tuple[Path, str] | None,
) -> None:
    print(
        "interactive commands: plain text sends a BASIC line; "
        ":snap [attrs] [all [DELAY]|DELAY [all]|START END|DELAY START END] snapshots; :csnap caches a quiet full snapshot; :key NAME sends a matrix key; "
        ":type TEXT types without Return; :kbdstate dumps ROM keyboard state; :cpustate dumps V20 registers; :mem OFFSET LEN dumps DS:offset through mapped CPU-bus memory; "
        ":busmem ADDR LEN dumps mapped CPU-bus memory; :segmem SEG OFF LEN dumps SEG:OFF through mapped CPU-bus memory; :loaderabi dumps the fixed loader ABI; "
        ":dbgstate/:dbglog [N]/:dbgerrlog [N]/:dbggo/:dbgstop/:dbgstep N/:dbgbp ADDR/:dbgbpclear [N]/:dbg CMD control MAME debugger when --debug is enabled; :quit exits",
        file=sys.stderr,
    )
    while True:
        try:
            line = input("dwbasic> ")
        except EOFError:
            break
        command = line.strip()
        if not command:
            continue
        if command in {":q", ":quit", ":exit"}:
            break
        if command == ":csnap":
            cached_snapshot = take_decoded_snapshot(
                input_stream,
                snap_dir,
                snapshot_timeout,
            )
            if "non-text cell" in cached_snapshot[1]:
                print(f"\n== {cached_snapshot[0].name} ==")
                print(cached_snapshot[1])
            continue
        if command.startswith(":snap"):
            try:
                mode, delay, start_line, end_line, show_attrs = parse_snap_command(command)
                previous_snapshot = cached_snapshot
                if delay < 0:
                    raise ValueError("snap delay must be >= 0")
                if delay:
                    time.sleep(delay)
                cached_snapshot = take_decoded_snapshot(
                    input_stream,
                    snap_dir,
                    snapshot_timeout,
                )
                print(f"\n== {cached_snapshot[0].name} ==")
                if show_attrs:
                    output = slice_lines(
                        decode_snapshot(cached_snapshot[0], allow_cursor=True, allow_inverse=True, attrs=True),
                        start_line,
                        end_line,
                    )
                elif mode == "changed" and "non-text cell" not in cached_snapshot[1]:
                    output = changed_lines(
                        previous_snapshot[1] if previous_snapshot is not None else None,
                        cached_snapshot[1],
                    )
                else:
                    output = slice_lines(cached_snapshot[1], start_line, end_line)
                if output:
                    print(output)
            except ValueError as exc:
                print(str(exc), file=sys.stderr)
            continue
        if command.startswith(":key "):
            send_bridge_key(input_stream, command[5:].strip())
            continue
        if command.startswith(":type "):
            send_bridge_text(input_stream, command[6:], add_return=False)
            continue
        if command == ":kbdstate":
            print_kbd_state(input_stream)
            continue
        if command == ":cpustate":
            print_cpu_state(input_stream)
            continue
        if command == ":dbgstate":
            print_debug_state(input_stream)
            continue
        if command == ":dbggo":
            send_debug_simple(input_stream, "DBGGO")
            continue
        if command == ":dbgstop":
            send_debug_simple(input_stream, "DBGSTOP")
            continue
        if command.startswith(":dbgstep"):
            count = command[8:].strip()
            send_debug_simple(input_stream, "DBGSTEP" + (f" {count}" if count else ""))
            continue
        if command.startswith(":dbgerrlog"):
            args = command[10:].strip()
            print_debug_log(input_stream, "DBGERRLOG" + (f" {args}" if args else ""))
            continue
        if command.startswith(":dbglog"):
            args = command[7:].strip()
            print_debug_log(input_stream, "DBGLOG" + (f" {args}" if args else ""))
            continue
        if command.startswith(":dbgbpclear"):
            args = command[11:].strip()
            send_debug_simple(input_stream, "DBGBPCLEAR" + (f" {args}" if args else ""))
            continue
        if command.startswith(":dbgbp "):
            send_debug_simple(input_stream, f"DBGBP {command[7:].strip()}")
            continue
        if command.startswith(":dbg "):
            send_debug_command(input_stream, command[5:])
            continue
        if command.startswith(":mem "):
            print_basic_memory(input_stream, command[5:].strip())
            continue
        if command.startswith(":busmem "):
            print_bus_memory(input_stream, command[8:].strip())
            continue
        if command.startswith(":physmem "):
            print_bus_memory(input_stream, command[9:].strip())
            continue
        if command.startswith(":linmem "):
            print_linear_memory(input_stream, command[8:].strip())
            continue
        if command.startswith(":segmem "):
            print_linear_memory(input_stream, command[8:].strip())
            continue
        if command == ":loaderabi":
            print_loader_abi(input_stream)
            continue
        send_bridge_text(input_stream, line, add_return=True)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mame", type=Path, default=DEFAULT_MAME)
    parser.add_argument("--mame-dir", type=Path, default=DEFAULT_MAME_DIR)
    parser.add_argument("--machine", default="drwrt400")
    parser.add_argument("--bios", default="v2_1")
    parser.add_argument("--card", type=Path, default=DEFAULT_CARD)
    parser.add_argument("--card-option", default="-sram", help="MAME image option for the SRAM card")
    parser.add_argument("--no-card", action="store_true", help="launch without a PCMCIA SRAM card")
    parser.add_argument("--pccard", "--pcmcia", dest="pccard", default="melcard_1m")
    parser.add_argument("--serial", "--rs232", dest="serial", default="pty")
    parser.add_argument("--snap-dir", type=Path, default=DEFAULT_SNAP_DIR)
    parser.add_argument("--nvram-image", type=Path, default=DEFAULT_NVRAM_IMAGE)
    parser.add_argument(
        "--nvram-source",
        type=Path,
        help="copy this prepared NVRAM image into --nvram-image before launch",
    )
    parser.add_argument(
        "--prepared-romcard",
        action="store_true",
        help="use ../nvram-romcard and press Enter from its ROM CARD-selected menu state",
    )
    parser.add_argument("--input-bridge", type=Path, default=DEFAULT_INPUT_BRIDGE)
    parser.add_argument("--input-socket", type=Path, default=DEFAULT_INPUT_SOCKET)
    parser.add_argument("--bridge-hold-frames", type=int, default=2)
    parser.add_argument("--bridge-gap-frames", type=int, default=1)
    parser.add_argument("--bridge-shift-lead-frames", type=int, default=1)
    parser.add_argument("--bridge-shift-trail-frames", type=int, default=1)
    parser.add_argument("--boot-wait", type=float, default=0.5)
    parser.add_argument("--boot-timeout", type=float, default=1.0)
    parser.add_argument("--menu-wait", type=float, default=0.2)
    parser.add_argument("--menu-timeout", type=float, default=1.0)
    parser.add_argument("--basic-wait", type=float, default=3.0)
    parser.add_argument("--signpost-interval", type=float, default=0.25)
    parser.add_argument("--window-timeout", type=float, default=10.0)
    parser.add_argument("--snapshot-timeout", type=float, default=5.0)
    parser.add_argument("--no-clean", action="store_true", help="do not delete NVRAM/snapshots before launch")
    parser.add_argument("--no-signpost-check", action="store_true", help="do not verify menu snapshot hashes")
    parser.add_argument("--natural", action="store_true", help="enable MAME natural keyboard mode")
    parser.add_argument("--steadykey", action="store_true", help="enable MAME steadykey support")
    parser.add_argument("--verbose", action="store_true", help="print launch line")
    parser.add_argument("--window-position", default="top", help="move MAME after launch: 'top', 'x,y', or empty string")
    parser.add_argument("--debug", action="store_true", help="enable MAME debugger API using the non-UI debugger module")
    parser.add_argument("--debug-bp", action="append", default=[], metavar="LABEL:ADDR", help="install a startup debugger registerpoint before ROM CARD navigation")
    parser.add_argument("--debug-stop-bp", action="append", default=[], metavar="LABEL:ADDR", help="install a startup debugger registerpoint that stops instead of resuming")
    parser.add_argument("--debug-segwatch", action="store_true", help="log CS/DS/ES/SS changes with CS:IP while startup runs")
    args = parser.parse_args(argv)

    if args.prepared_romcard and args.nvram_source is None:
        args.nvram_source = DEFAULT_NVRAM_TEMPLATE
    if args.prepared_romcard:
        args.boot_wait = max(args.boot_wait, 2.0)

    if not args.no_card and not args.card.exists():
        print(f"card image does not exist: {args.card}", file=sys.stderr)
        return 1
    if not args.mame.exists():
        print(f"MAME binary does not exist: {args.mame}", file=sys.stderr)
        return 1
    if not args.input_bridge.exists():
        print(f"input bridge script does not exist: {args.input_bridge}", file=sys.stderr)
        return 1
    if args.nvram_source is not None and not args.nvram_source.exists():
        print(f"NVRAM source image does not exist: {args.nvram_source}", file=sys.stderr)
        return 1

    if not args.no_clean:
        clean_run_state(args.nvram_image, args.snap_dir, args.nvram_source)
    clean_socket(args.input_socket)

    command = [
        str(args.mame),
        args.machine,
        "-window",
        "-skip_gameinfo",
        "-ui_active",
        "-bios",
        args.bios,
        "-nonvram_save",
        "-snapview",
        "internal",
        "-snapname",
        "%g/%i",
        "-autoboot_script",
        str(args.input_bridge),
        "-serial",
        args.serial,
    ]
    if not args.no_card:
        command.extend(
            [
                "-pccard",
                args.pccard,
                args.card_option,
                str(args.card),
            ]
        )
    if args.debug_bp or args.debug_stop_bp or args.debug_segwatch:
        args.debug = True
    if args.debug_bp or args.debug_stop_bp:
        try:
            debug_registerpoint_commands(args.debug_bp)
            debug_breakpoint_commands(args.debug_stop_bp)
        except ValueError as exc:
            print(str(exc), file=sys.stderr)
            return 1
    if args.debug:
        command.extend(["-debug", "-debugger", "none"])
    if args.natural:
        command.append("-natural")
    if args.steadykey:
        command.append("-steadykey")
    if args.verbose:
        print("launch:", " ".join(command))
    env = os.environ.copy()
    env["DWBASIC_INPUT_SOCKET"] = str(args.input_socket)
    env["DWBASIC_INPUT_HOLD_FRAMES"] = str(args.bridge_hold_frames)
    env["DWBASIC_INPUT_GAP_FRAMES"] = str(args.bridge_gap_frames)
    env["DWBASIC_INPUT_SHIFT_LEAD_FRAMES"] = str(args.bridge_shift_lead_frames)
    env["DWBASIC_INPUT_SHIFT_TRAIL_FRAMES"] = str(args.bridge_shift_trail_frames)
    proc = subprocess.Popen(command, cwd=args.mame_dir, env=env)
    try:
        window_id = find_mame_window(proc.pid, args.window_timeout)
        move_window(window_id, args.window_position, proc)
        input_stream = connect_input_bridge(args.input_socket, proc, args.window_timeout)

        time.sleep(args.boot_wait)
        if args.prepared_romcard:
            if args.no_signpost_check:
                snapshot(
                    input_stream,
                    args.snap_dir,
                    args.snapshot_timeout,
                )
            else:
                wait_for_signpost(
                    input_stream,
                    args.snap_dir,
                    "prepared ROM CARD menu",
                    args.boot_timeout,
                    args.signpost_interval,
                    args.snapshot_timeout,
                )
        elif args.no_signpost_check:
            snapshot(
                input_stream,
                args.snap_dir,
                args.snapshot_timeout,
            )
        else:
            wait_for_signpost(
                input_stream,
                args.snap_dir,
                "initial two-button menu",
                args.boot_timeout,
                args.signpost_interval,
                args.snapshot_timeout,
            )

        install_debug_setup(input_stream, args.debug_bp, args.debug_stop_bp, args.debug_segwatch)
        if args.prepared_romcard:
            send_bridge_key(input_stream, "Enter")
        else:
            send_bridge_key(input_stream, "Page_Down")
            time.sleep(args.menu_wait)
            if args.no_signpost_check:
                snapshot(
                    input_stream,
                    args.snap_dir,
                    args.snapshot_timeout,
                )
            else:
                wait_for_signpost(
                    input_stream,
                    args.snap_dir,
                    "WP menu",
                    args.menu_timeout,
                    args.signpost_interval,
                    args.snapshot_timeout,
                )

            send_bridge_key(input_stream, "6")
            time.sleep(args.menu_wait)
            if args.no_signpost_check:
                snapshot(
                    input_stream,
                    args.snap_dir,
                    args.snapshot_timeout,
                )
            else:
                wait_for_signpost(
                    input_stream,
                    args.snap_dir,
                    "OTHERS menu",
                    args.menu_timeout,
                    args.signpost_interval,
                    args.snapshot_timeout,
                )

            send_bridge_key(input_stream, "4")
        time.sleep(args.basic_wait)
        interactive_loop(
            input_stream,
            args.snap_dir,
            args.snapshot_timeout,
            None,
        )
    finally:
        try:
            proc.terminate()
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=5)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
