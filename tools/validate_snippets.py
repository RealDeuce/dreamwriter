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
    r"(?P<byte_line>([0-9A-Fa-f]{2,})(?:\s+[0-9A-Fa-f]{2,})*)\s+(?P<rest>.*)$"
)
OPERAND_NUM_RE = re.compile(r"(0x[0-9a-fA-F]+|[0-9a-fA-F]{4}:[0-9a-fA-F]{4}|[0-9]+)")
CHAR_LITERAL_RE = re.compile(r"'(?:[^'\\]|\\.)'")
CONTROL_TRANSFER = {
    "call",
    "ja",
    "jae",
    "jb",
    "jbe",
    "jc",
    "jcxz",
    "jg",
    "jge",
    "jl",
    "jle",
    "jmp",
    "jnc",
    "jnz",
    "jz",
    "loop",
}
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


def parse_snippet_lines(lines: list[str]) -> list[tuple[str, int, int, bytes, str]]:
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
        rest = m.group("rest")
        if rest.lstrip().startswith("..."):
            continue
        byte_values = []
        for token in byte_line.split():
            if len(token) % 2 != 0:
                byte_values = []
                break
            byte_values.extend(int(token[i : i + 2], 16) for i in range(0, len(token), 2))
        if not byte_values:
            continue
        bytes_vals = bytes(byte_values)

        try:
            _, phys = parse_addr_expr(addr_expr)
        except ValueError:
            continue

        found.append((addr_expr, line_no, phys, bytes_vals, rest))

    return found


def run_ndisasm(line_bytes: bytes, start_phys: int) -> tuple[str | None, str | None]:
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
        return None, exc.stderr.decode("utf-8", errors="replace").strip() or "ndisasm failed"

    return result.stdout.decode("utf-8", errors="replace"), None


def normalize_annotated_text(text: str) -> str:
    # Strip inline comments and normalise spacing to keep annotation noise from
    # obscuring real decode drift.
    if ";" in text:
        text = text.split(";", 1)[0]
    text = text.replace("byte +", "")
    text = text.replace("byte -", "-")
    text = CHAR_LITERAL_RE.sub("0", text)
    return " ".join(text.strip().split()).lower()


def normalize_instruction_signature(text: str) -> list[str]:
    text = normalize_annotated_text(text)
    tokens = []
    for raw in text.replace(",", " , ").replace("[", " [ ").replace("]", " ] ").split():
        mapped = OPERAND_NUM_RE.sub("N", raw)
        if mapped == "N:N":
            mapped = "N"
        mapped = mapped.removeprefix("+")
        if mapped in {"short", "near", "far"}:
            continue
        tokens.append(mapped)
    if tokens and tokens[0] in CONTROL_TRANSFER and len(tokens) > 1:
        return [tokens[0], "N"]
    return tokens


def extract_ndisasm_records(output: str) -> list[tuple[int | None, bytes, str]]:
    # ndisasm output format: ADDRESS BYTES  INSTRUCTION
    records = []
    for line in output.splitlines():
        parts = line.strip().split(None, 2)
        if len(parts) < 3:
            records.append((None, b"", ""))
            continue
        try:
            addr = int(parts[0], 16)
            bytes_out = bytes.fromhex(parts[1])
        except ValueError:
            addr = None
            bytes_out = b""
        records.append((addr, bytes_out, normalize_annotated_text(parts[2])))
    return records


def contiguous_groups(records: list[tuple[str, int, int, bytes, str]]):
    group = []
    next_phys = None
    for record in records:
        _, _, phys, expected, _ = record
        if group and phys != next_phys:
            yield group
            group = []
        group.append(record)
        next_phys = phys + len(expected)
    if group:
        yield group


def validate_disasm_records(records: list[tuple[str, int, int, bytes, str]], path: Path) -> int:
    if not records:
        return 0

    start_phys = records[0][2]
    blob = b"".join(record[3] for record in records)
    disasm_out, disasm_err = run_ndisasm(blob, start_phys)
    if disasm_err is not None:
        for addr_expr, line_no, _, _, _ in records:
            print(
                f"{path}:{line_no}: {addr_expr} cannot disassemble as 8086 bytes",
                file=sys.stderr,
            )
            print(f"  ndisasm: {disasm_err}", file=sys.stderr)
        return len(records)

    actual_records = extract_ndisasm_records(disasm_out or "")
    if len(actual_records) != len(records):
        if len(records) > 1:
            mid = len(records) // 2
            return validate_disasm_records(records[:mid], path) + validate_disasm_records(records[mid:], path)
        addr_expr, line_no, _, _, _ = records[0]
        print(
            f"{path}:{line_no}: {addr_expr} batched disassembly boundary mismatch",
            file=sys.stderr,
        )
        print(
            f"  expected {len(records)} instruction rows, ndisasm emitted {len(actual_records)}",
            file=sys.stderr,
        )
        return len(records)

    boundary_mismatch = any(
        actual_phys != phys or actual_bytes != expected
        for (_, _, phys, expected, _), (actual_phys, actual_bytes, _) in zip(records, actual_records)
    )
    if boundary_mismatch and len(records) > 1:
        mid = len(records) // 2
        return validate_disasm_records(records[:mid], path) + validate_disasm_records(records[mid:], path)

    failures = 0
    for (addr_expr, line_no, phys, expected, rest), (actual_phys, actual_bytes, actual_text) in zip(records, actual_records):
        if actual_phys != phys or actual_bytes != expected:
            failures += 1
            actual_addr = "?" if actual_phys is None else f"0x{actual_phys:05X}"
            print(
                f"{path}:{line_no}: {addr_expr} instruction boundary mismatch",
                file=sys.stderr,
            )
            print(
                f"  expected addr/bytes: 0x{phys:05X} {expected.hex(' ')}",
                f"actual addr/bytes:   {actual_addr} {actual_bytes.hex(' ')}",
                file=sys.stderr,
            )
            continue
        expected_text = normalize_annotated_text(rest)
        if expected_text and actual_text and expected_text != actual_text:
            expected_sig = normalize_instruction_signature(expected_text)
            actual_sig = normalize_instruction_signature(actual_text)
            if expected_sig != actual_sig:
                failures += 1
                print(
                    f"{path}:{line_no}: {addr_expr} disassembly signature mismatch",
                    file=sys.stderr,
                )
                print(
                    f"  expected: {expected_text}",
                    f"disasm : {actual_text}",
                    file=sys.stderr,
                )
                print(
                    f"  expected_sig: {' '.join(expected_sig)}",
                    f"actual_sig:   {' '.join(actual_sig)}",
                    file=sys.stderr,
                )
    return failures


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
        disasm_candidates = []
        for addr_expr, line_no, phys, expected, rest in parse_snippet_lines(path.read_text(encoding="utf-8").splitlines()):
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

            disasm_candidates.append((addr_expr, line_no, phys, expected, rest))

        for group in contiguous_groups(disasm_candidates):
            asm_fail += validate_disasm_records(group, path)

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
