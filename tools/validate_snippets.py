#!/usr/bin/env python3
"""Validate annotated asm lines in markdown against ROM bytes."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

from rom2 import (
    expand_markdown_inputs,
    parse_addr_expr,
    phys_to_file,
    read_rom,
)


INSTR_RE = re.compile(
    r"^(?P<addr>[0-9A-Fa-f]{4}:[0-9A-Fa-f]{4})\s+"
    r"(?P<byte_line>([0-9A-Fa-f]{2})(?:\s+[0-9A-Fa-f]{2})*)\s+"
)
COMMENT_ONLY_RE = re.compile(r"^\s*;")
ELLIPSIS_RE = re.compile(r"^\s*\.\.\.\s*(?:;.*)?$")
LABEL_RE = re.compile(r"^\s*[A-Za-z0-9._-]+:\s*$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate annotated asm snippets against ROM bytes.")
    parser.add_argument(
        "scope",
        nargs="*",
        default=["docs/disassembly/*.md"],
        help="markdown files, globs, or directories to scan",
    )
    parser.add_argument("--rom", type=Path, default=Path("t4_ir_2.1.ic303"), help="ROM image to validate against")
    parser.add_argument(
        "--include-readme",
        action="store_true",
        help="include README.md files",
    )
    return parser.parse_args()


def normalize_path(path: Path, include_readme: bool) -> bool:
    if path.suffix.lower() != ".md":
        return False
    if not include_readme and path.name.lower() == "readme.md":
        return False
    return True


def parse_snippet_lines(lines: list[str]) -> list[tuple[str, int, int, bytes]]:
    in_asm = False
    found = []

    for line_no, raw in enumerate(lines, 1):
        line = raw.rstrip()
        if line.startswith("```"):
            if line.strip() == "```asm":
                in_asm = not in_asm
                continue
            if in_asm and line.strip() == "```":
                in_asm = False
            continue
        if not in_asm:
            continue

        if not line or ELLIPSIS_RE.match(line) or COMMENT_ONLY_RE.match(line) or LABEL_RE.match(line):
            continue

        m = INSTR_RE.match(line)
        if not m:
            continue

        addr_expr = m.group("addr")
        byte_line = m.group("byte_line")
        bytes_vals = bytes(int(token, 16) for token in byte_line.split())

        try:
            _, phys = parse_addr_expr(addr_expr)
        except ValueError:
            continue

        found.append((addr_expr, line_no, phys, bytes_vals))

    return found


def run_ndisasm(line_bytes: bytes, start_phys: int) -> tuple[bytes | None, str | None]:
    command = [
        "ndisasm",
        "-b",
        "16",
        "-o",
        f"0x{start_phys:05X}",
        "-",
    ]
    try:
        result = subprocess.run(command, check=True, input=line_bytes, capture_output=True)
    except FileNotFoundError:
        return None, "ndisasm not installed"
    except subprocess.CalledProcessError as exc:
        return b"", exc.stderr.decode("utf-8", errors="replace").strip() or "ndisasm failed"

    return line_bytes, result.stdout.decode("utf-8", errors="replace")


def main() -> int:
    args = parse_args()
    files = [p for p in expand_markdown_inputs(args.scope) if normalize_path(p, args.include_readme)]
    if not files:
        print("no markdown files matched", file=sys.stderr)
        return 1

    rom = read_rom(args.rom)
    total = 0
    bytes_fail = 0
    asm_fail = 0

    for path in files:
        for addr_expr, line_no, phys, expected in parse_snippet_lines(path.read_text(encoding="utf-8").splitlines()):
            total += 1
            file_off = phys_to_file(phys)
            if file_off + len(expected) > len(rom) or file_off < 0:
                bytes_fail += 1
                print(
                    f"{path}:{line_no}: {addr_expr} file {hex(file_off)} out of ROM range",
                    file=sys.stderr,
                )
                continue

            actual = rom[file_off : file_off + len(expected)]
            if actual != expected:
                bytes_fail += 1
                print(
                    f"{path}:{line_no}: {addr_expr} byte mismatch at file 0x{file_off:05X}",
                    file=sys.stderr,
                )
                print(
                    f"  expected: {expected.hex(' ')}",
                    f"actual:   {actual.hex(' ')}",
                    file=sys.stderr,
                )
                continue

            _, disasm_out = run_ndisasm(expected, phys)
            if _ is None:
                asm_fail += 1
                print(
                    f"{path}:{line_no}: {addr_expr} cannot disassemble as 8086 bytes",
                    file=sys.stderr,
                )
                print(f"  ndisasm: {disasm_out}", file=sys.stderr)

    if bytes_fail or asm_fail:
        print(
            f"snippet validation: FAIL (bytes={bytes_fail}, disasm={asm_fail}, total={total})",
            file=sys.stderr,
        )
        return 1

    print(f"snippet validation: PASS ({total} lines)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
