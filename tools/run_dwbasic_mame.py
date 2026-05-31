#!/usr/bin/env python3
"""Drive DW-BASIC startup in MAME and decode the resulting LCD snapshots."""

from __future__ import annotations

import argparse
import hashlib
import re
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
ROM = REPO_ROOT / "t4_ir_2.1.ic303"
EXPECTED_SIGNPOSTS = {
    "initial two-button menu": "14bbb2fea6a6ad3635f84f027e2fe40a1bab4088b3a58b0be86f7822426376d4",
    "WP menu": "97096048743b7a1c3857a78d3f31541b900c6ae750282a8d803ae7c8b4e38a91",
    "OTHERS menu": "9c10a804b9c04503b0ff7579555f82de41b9b4fb09121b5a9f68d9a188d680d4",
}
KEYSYM_CHARS = {
    "!": "exclam",
    "#": "numbersign",
    "$": "dollar",
    "%": "percent",
    "&": "ampersand",
    "(": "parenleft",
    ")": "parenright",
    "*": "asterisk",
    "+": "plus",
    ":": "colon",
    "<": "less",
    ">": "greater",
    "?": "question",
}


def run(args: list[str], *, check: bool = True, **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(args, check=check, text=True, **kwargs)


def clean_run_state(nvram_image: Path, snap_dir: Path) -> None:
    if nvram_image.exists():
        nvram_image.unlink()
    snap_dir.mkdir(parents=True, exist_ok=True)
    for png in snap_dir.glob("*.png"):
        png.unlink()


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


def ensure_window(window_id: str, proc: subprocess.Popen | None = None) -> None:
    if proc is not None:
        ensure_process_alive(proc)
    result = run(["xdotool", "getwindowname", window_id], check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip()
        raise RuntimeError(f"MAME window {window_id} is no longer valid: {detail}")


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
    ensure_window(window_id, proc)
    if position == "top":
        x, y = current_monitor_origin()
        run(["xdotool", "windowmove", window_id, str(x), str(y)])
        return
    if "," in position:
        x, y = position.split(",", 1)
        run(["xdotool", "windowmove", window_id, x.strip(), y.strip()])
        return
    raise ValueError(f"unsupported window position {position!r}; use 'top' or 'x,y'")


def active_window() -> str | None:
    result = run(["xdotool", "getactivewindow"], check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        return None
    text = result.stdout.strip()
    return text or None


def activate(window_id: str) -> None:
    run(["xdotool", "windowactivate", "--sync", window_id])


def require_active_window(window_id: str) -> None:
    active = active_window()
    if active != window_id:
        raise RuntimeError(f"refusing to send input: active window is {active}, expected MAME window {window_id}")


def key(
    window_id: str,
    key_name: str,
    hold: float,
    *,
    focus: bool = True,
    proc: subprocess.Popen | None = None,
) -> None:
    ensure_window(window_id, proc)
    if focus:
        activate(window_id)
        require_active_window(window_id)
    else:
        raise RuntimeError("non-focused directed input is disabled because xdotool can leak into the active window")
    run(["xdotool", "keydown", "--clearmodifiers", "--window", window_id, key_name])
    try:
        time.sleep(hold)
    finally:
        run(["xdotool", "keyup", "--clearmodifiers", "--window", window_id, key_name], check=False)


def type_text(
    window_id: str,
    text: str,
    delay_ms: int,
    *,
    focus: bool = True,
    proc: subprocess.Popen | None = None,
) -> None:
    ensure_window(window_id, proc)
    if focus:
        activate(window_id)
        run(["xdotool", "keyup", "--window", window_id, "Shift_L"], check=False)
        run(["xdotool", "keyup", "--window", window_id, "Shift_R"], check=False)
        for char in text:
            require_active_window(window_id)
            key_name = KEYSYM_CHARS.get(char)
            if key_name is None:
                run(["xdotool", "type", "--clearmodifiers", "--window", window_id, "--delay", str(delay_ms), char])
            else:
                run(["xdotool", "keydown", "--clearmodifiers", "--window", window_id, key_name])
                time.sleep(max(0.005, delay_ms / 1000))
                run(["xdotool", "keyup", "--clearmodifiers", "--window", window_id, key_name], check=False)
                time.sleep(delay_ms / 1000)
        run(["xdotool", "keyup", "--window", window_id, "Shift_L"], check=False)
        run(["xdotool", "keyup", "--window", window_id, "Shift_R"], check=False)
        return
    raise RuntimeError("non-focused directed input is disabled because xdotool can leak into the active window")


def snapshot(
    window_id: str,
    snap_dir: Path,
    timeout: float,
    *,
    focus_input: bool = True,
    proc: subprocess.Popen | None = None,
) -> Path:
    before = {path.name for path in snap_dir.glob("*.png")}
    key(window_id, "F12", 0.05, focus=focus_input, proc=proc)
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
    window_id: str,
    proc: subprocess.Popen,
    snap_dir: Path,
    label: str,
    timeout: float,
    interval: float,
    snapshot_timeout: float,
    focus_input: bool,
) -> Path:
    expected = EXPECTED_SIGNPOSTS[label]
    deadline = time.monotonic() + timeout
    last_actual = ""
    last_path: Path | None = None
    while time.monotonic() < deadline:
        path = snapshot(
            window_id,
            snap_dir,
            snapshot_timeout,
            focus_input=focus_input,
            proc=proc,
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


def print_snapshot(path: Path) -> None:
    print(f"\n== {path.name} ==")
    print(decode_snapshot(path, allow_cursor=True, allow_inverse=True))


def screen_has_error(text: str) -> bool:
    lowered = text.lower()
    return "syntax error" in lowered or "needs more memory" in lowered or "undefined user function" in lowered


def screen_has_prompt(text: str) -> bool:
    lines = [line.strip().lower() for line in text.splitlines()]
    return "ok" in lines


def interactive_loop(
    window_id: str,
    proc: subprocess.Popen,
    snap_dir: Path,
    snapshot_timeout: float,
    key_hold: float,
    type_delay_ms: int,
    focus_input: bool,
) -> None:
    print(
        "interactive commands: plain text sends a BASIC line; "
        ":snap snapshots; :key NAME sends a key; :type TEXT types without Return; :quit exits",
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
        if command == ":snap":
            print_snapshot(snapshot(window_id, snap_dir, snapshot_timeout, focus_input=focus_input, proc=proc))
            continue
        if command.startswith(":key "):
            key(window_id, command[5:].strip(), key_hold, focus=focus_input, proc=proc)
            continue
        if command.startswith(":type "):
            type_text(window_id, command[6:], type_delay_ms, focus=focus_input, proc=proc)
            continue
        type_text(window_id, line, type_delay_ms, focus=focus_input, proc=proc)
        key(window_id, "Return", key_hold, focus=focus_input, proc=proc)


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
    parser.add_argument("--boot-wait", type=float, default=2.0)
    parser.add_argument("--boot-timeout", type=float, default=1.0)
    parser.add_argument("--menu-wait", type=float, default=0.2)
    parser.add_argument("--menu-timeout", type=float, default=1.0)
    parser.add_argument("--basic-wait", type=float, default=3.0)
    parser.add_argument("--signpost-interval", type=float, default=0.25)
    parser.add_argument("--key-hold", type=float, default=0.20)
    parser.add_argument("--window-timeout", type=float, default=10.0)
    parser.add_argument("--snapshot-timeout", type=float, default=5.0)
    parser.add_argument("--type-line", action="append", default=[], help="type a BASIC line/command after startup")
    parser.add_argument("--type-delay-ms", type=int, default=35)
    parser.add_argument("--after-type-wait", type=float, default=0.5)
    parser.add_argument("--no-stop-on-screen-error", action="store_true", help="continue --type-line batch after decoded errors")
    parser.add_argument("--no-clean", action="store_true", help="do not delete NVRAM/snapshots before launch")
    parser.add_argument("--no-signpost-check", action="store_true", help="do not verify menu snapshot hashes")
    parser.add_argument("--keep-running", action="store_true", help="leave MAME running after snapshots")
    parser.add_argument("--verbose", action="store_true", help="print launch line and intermediate snapshots")
    parser.add_argument("--interactive", action="store_true", help="enter a command loop after booting to BASIC")
    parser.add_argument("--window-position", default="top", help="move MAME after launch: 'top', 'x,y', or empty string")
    parser.add_argument(
        "--focus-input",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="activate the MAME window before sending keys; --no-focus-input is disabled for safety",
    )
    args = parser.parse_args(argv)

    if not args.card.exists():
        print(f"card image does not exist: {args.card}", file=sys.stderr)
        return 1
    if not args.mame.exists():
        print(f"MAME binary does not exist: {args.mame}", file=sys.stderr)
        return 1

    if not args.no_clean:
        clean_run_state(args.nvram_image, args.snap_dir)

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
        "-rs232",
        args.rs232,
        "-pcmcia",
        args.pcmcia,
        args.card_option,
        str(args.card),
    ]
    if args.verbose:
        print("launch:", " ".join(command))
    proc = subprocess.Popen(command, cwd=args.mame_dir)
    snapshots: list[Path] = []
    try:
        window_id = find_mame_window(proc.pid, args.window_timeout)
        move_window(window_id, args.window_position, proc)

        time.sleep(args.boot_wait)
        if args.no_signpost_check:
            snapshots.append(
                snapshot(
                    window_id,
                    args.snap_dir,
                    args.snapshot_timeout,
                    focus_input=args.focus_input,
                    proc=proc,
                )
            )
        else:
            snapshots.append(
                wait_for_signpost(
                    window_id,
                    proc,
                    args.snap_dir,
                    "initial two-button menu",
                    args.boot_timeout,
                    args.signpost_interval,
                    args.snapshot_timeout,
                    args.focus_input,
                )
            )

        key(window_id, "Page_Down", args.key_hold, focus=args.focus_input, proc=proc)
        time.sleep(args.menu_wait)
        if args.no_signpost_check:
            snapshots.append(
                snapshot(
                    window_id,
                    args.snap_dir,
                    args.snapshot_timeout,
                    focus_input=args.focus_input,
                    proc=proc,
                )
            )
        else:
            snapshots.append(
                wait_for_signpost(
                    window_id,
                    proc,
                    args.snap_dir,
                    "WP menu",
                    args.menu_timeout,
                    args.signpost_interval,
                    args.snapshot_timeout,
                    args.focus_input,
                )
            )

        key(window_id, "6", args.key_hold, focus=args.focus_input, proc=proc)
        time.sleep(args.menu_wait)
        if args.no_signpost_check:
            snapshots.append(
                snapshot(
                    window_id,
                    args.snap_dir,
                    args.snapshot_timeout,
                    focus_input=args.focus_input,
                    proc=proc,
                )
            )
        else:
            snapshots.append(
                wait_for_signpost(
                    window_id,
                    proc,
                    args.snap_dir,
                    "OTHERS menu",
                    args.menu_timeout,
                    args.signpost_interval,
                    args.snapshot_timeout,
                    args.focus_input,
                )
            )

        key(window_id, "4", args.key_hold, focus=args.focus_input, proc=proc)
        time.sleep(args.basic_wait)
        snapshots.append(
            snapshot(
                window_id,
                args.snap_dir,
                args.snapshot_timeout,
                focus_input=args.focus_input,
                proc=proc,
            )
        )

        for line in args.type_line:
            type_text(window_id, line, args.type_delay_ms, focus=args.focus_input, proc=proc)
            key(window_id, "Return", args.key_hold, focus=args.focus_input, proc=proc)
            time.sleep(args.after_type_wait)
            path = snapshot(
                window_id,
                args.snap_dir,
                args.snapshot_timeout,
                focus_input=args.focus_input,
                proc=proc,
            )
            snapshots.append(path)
            decoded = decode_snapshot(path, allow_cursor=True, allow_inverse=True)
            if args.verbose:
                print(f"\n== {path.name} after {line!r} ==")
                print(decoded)
            if not args.no_stop_on_screen_error and (screen_has_error(decoded) or not screen_has_prompt(decoded)):
                print(f"stopping after {line!r}: screen did not return to an OK prompt", file=sys.stderr)
                break

        output_paths = snapshots if args.verbose else snapshots[-1:]
        for index, path in enumerate(output_paths):
            print(f"\n== {path.name} ==")
            final_snapshot = path == snapshots[-1]
            print(decode_snapshot(path, allow_cursor=final_snapshot, allow_inverse=final_snapshot))
        if args.interactive:
            interactive_loop(
                window_id,
                proc,
                args.snap_dir,
                args.snapshot_timeout,
                args.key_hold,
                args.type_delay_ms,
                args.focus_input,
            )
    finally:
        if not args.keep_running:
            try:
                proc.terminate()
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=5)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
