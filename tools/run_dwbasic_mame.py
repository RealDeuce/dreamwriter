#!/usr/bin/env python3
"""Drive DW-BASIC startup in MAME and decode the resulting LCD snapshots."""

from __future__ import annotations

import argparse
import hashlib
import os
import re
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
DECODER = REPO_ROOT / "tools" / "decode_lcd_text.py"
DEFAULT_INPUT_BRIDGE = REPO_ROOT / "tools" / "dwbasic_input_bridge.lua"
DEFAULT_INPUT_SOCKET = Path("/tmp/dwbasic-input.sock")
ROM = REPO_ROOT / "t4_ir_2.1.ic303"
KEYBOARD_SCAN_RATE_HZ = 19660000 / 20480
KEYBOARD_FULL_SCAN_SECONDS = 10 / KEYBOARD_SCAN_RATE_HZ
EXPECTED_SIGNPOSTS = {
    "initial two-button menu": "14bbb2fea6a6ad3635f84f027e2fe40a1bab4088b3a58b0be86f7822426376d4",
    "WP menu": "97096048743b7a1c3857a78d3f31541b900c6ae750282a8d803ae7c8b4e38a91",
    "OTHERS menu": "9c10a804b9c04503b0ff7579555f82de41b9b4fb09121b5a9f68d9a188d680d4",
}


def run(args: list[str], *, check: bool = True, **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(args, check=check, text=True, **kwargs)


def clean_run_state(nvram_image: Path, snap_dir: Path) -> None:
    if nvram_image.exists():
        nvram_image.unlink()
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


def decode_snapshot(path: Path, *, allow_cursor: bool = False, allow_inverse: bool = False) -> str:
    command = [sys.executable, str(DECODER), str(path), "--rom", str(ROM)]
    if allow_cursor:
        command.append("--allow-cursor")
    if allow_inverse:
        command.append("--allow-inverse")
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
        path.unlink()
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


def parse_snap_command(command: str) -> tuple[str, float, int | None, int | None]:
    parts = command.split()
    if len(parts) == 1:
        return "changed", 0.0, None, None
    if len(parts) == 2 and parts[1].lower() == "all":
        return "all", 0.0, None, None
    if len(parts) == 3 and parts[1].lower() == "all":
        try:
            return "all", float(parts[2]), None, None
        except ValueError as exc:
            raise ValueError("snap delay must be numeric") from exc
    if len(parts) == 3 and parts[2].lower() == "all":
        try:
            return "all", float(parts[1]), None, None
        except ValueError as exc:
            raise ValueError("snap delay must be numeric") from exc
    if len(parts) == 2:
        try:
            return "changed", float(parts[1]), None, None
        except ValueError as exc:
            raise ValueError("usage: :snap [all [delay]|delay [all]|start-line end-line|delay start-line end-line]") from exc
    try:
        if len(parts) == 3:
            return "range", 0.0, int(parts[1]), int(parts[2])
        if len(parts) == 4:
            return "range", float(parts[1]), int(parts[2]), int(parts[3])
    except ValueError as exc:
        raise ValueError("snap delay/range must be numeric") from exc
    raise ValueError("usage: :snap [all [delay]|delay [all]|start-line end-line|delay start-line end-line]")


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
        ":snap [all [DELAY]|DELAY [all]|START END|DELAY START END] snapshots; :csnap caches a quiet full snapshot; :key NAME sends a matrix key; "
        ":type TEXT types without Return; :kbdstate dumps ROM keyboard state; :cpustate dumps V20 registers; :quit exits",
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
                mode, delay, start_line, end_line = parse_snap_command(command)
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
                if mode == "changed" and "non-text cell" not in cached_snapshot[1]:
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
        send_bridge_text(input_stream, line, add_return=True)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mame", type=Path, default=DEFAULT_MAME)
    parser.add_argument("--mame-dir", type=Path, default=DEFAULT_MAME_DIR)
    parser.add_argument("--machine", default="drwrt400")
    parser.add_argument("--bios", default="v2_1")
    parser.add_argument("--card", type=Path, default=DEFAULT_CARD)
    parser.add_argument("--card-option", default="-sram", help="MAME image option for the SRAM card")
    parser.add_argument("--pcmcia", default="melcard_1m")
    parser.add_argument("--rs232", default="pty")
    parser.add_argument("--snap-dir", type=Path, default=DEFAULT_SNAP_DIR)
    parser.add_argument("--nvram-image", type=Path, default=DEFAULT_NVRAM_IMAGE)
    parser.add_argument("--input-bridge", type=Path, default=DEFAULT_INPUT_BRIDGE)
    parser.add_argument("--input-socket", type=Path, default=DEFAULT_INPUT_SOCKET)
    parser.add_argument("--bridge-hold-frames", type=int, default=2)
    parser.add_argument("--bridge-gap-frames", type=int, default=1)
    parser.add_argument("--bridge-shift-lead-frames", type=int, default=1)
    parser.add_argument("--bridge-shift-trail-frames", type=int, default=1)
    parser.add_argument("--boot-wait", type=float, default=2.0)
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
    args = parser.parse_args(argv)

    if not args.card.exists():
        print(f"card image does not exist: {args.card}", file=sys.stderr)
        return 1
    if not args.mame.exists():
        print(f"MAME binary does not exist: {args.mame}", file=sys.stderr)
        return 1
    if not args.input_bridge.exists():
        print(f"input bridge script does not exist: {args.input_bridge}", file=sys.stderr)
        return 1

    if not args.no_clean:
        clean_run_state(args.nvram_image, args.snap_dir)
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
        "-rs232",
        args.rs232,
        "-pcmcia",
        args.pcmcia,
        args.card_option,
        str(args.card),
    ]
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
                "initial two-button menu",
                args.boot_timeout,
                args.signpost_interval,
                args.snapshot_timeout,
            )

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
