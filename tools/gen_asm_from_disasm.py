#!/usr/bin/env python3
"""Generate repository-style NASM slices from labelled disassembly text."""

from __future__ import annotations

import argparse
import re
from collections.abc import Iterable
from pathlib import Path
from typing import Any

from rom2 import (
    parse_file_base,
    parse_addr_part,
    read_rom,
    seg_off_to_phys,
    phys_to_file,
)


ADDR_RE = re.compile(
    r"^(?P<addr>[0-9A-Fa-f]{4}:[0-9A-Fa-f]{4})\s+(?P<body>.+?)\s*$"
)
LABEL_RE = re.compile(r"^\s*(?P<label>[A-Za-z_][A-Za-z0-9_.-]*|\.[A-Za-z_][A-Za-z0-9_.-]*)\s*:\s*$")
LABEL_ADDR_RE = re.compile(
    r"^(?P<prefix>[A-Za-z_][A-Za-z0-9_.-]*?)_(?P<seg>[0-9A-Fa-f]{4}|[Cc][0-9A-Fa-f]{4})_(?P<off>[0-9A-Fa-f]{4})(?P<suffix>[A-Za-z0-9_.-]*)$"
)
HEXLIT_RE = re.compile(r"(?<!:)\b0x(?P<value>[0-9A-Fa-f]+)\b(?!:)")
SEG_OFF_RE = re.compile(r"\b(?P<seg>[0-9A-Fa-f]{4}):(?P<off>[0-9A-Fa-f]{4})\b")
NAME_REF_RE = re.compile(r"\b(?P<name>[A-Za-z_][A-Za-z0-9_.-]*|\.[A-Za-z_][A-Za-z0-9_.-]*)\b")
BASIC_HEX_BYTE_RE = re.compile(r"^[0-9A-Fa-f]{2}$")
ELLIPSIS_REST_RE = re.compile(
    r"^(?P<bytes>(?:[0-9A-Fa-f]{2}(?:\s+[0-9A-Fa-f]{2})*)?)\s*\.{3}\s*(?P<tail>.*)$"
)
FENCE_RE = re.compile(r"^\s*```")
ASM_FENCE_START_RE = re.compile(r"^\s*```asm\b", re.IGNORECASE)


def is_control_flow_op(op: str) -> bool:
    """Match control-flow ops that target fixed offsets."""

    op = op.lower()
    return op == "call" or op == "jmp" or op.startswith("j") or op.startswith("loop")


def parse_symbol_map(asm_dir: Path) -> dict[tuple[int, int], str]:
    """Map `(seg, off)` to known asm labels from existing generated output."""

    symbol_re = re.compile(
        r"^(?P<name>[A-Za-z_][A-Za-z0-9_.-]*?)_(?P<seg>[0-9A-Fa-f]{4}|[Cc][0-9A-Fa-f]{4})_(?P<off>[0-9A-Fa-f]{4})(?P<suffix>[A-Za-z0-9_.-]*)\s*:"
    )
    symbols: dict[tuple[int, int], str] = {}
    for path in sorted(asm_dir.glob("*.asm")):
        for raw in path.read_text(encoding="ascii").splitlines():
            m = symbol_re.match(raw.strip())
            if not m:
                continue
            symbols[(normalize_seg_text(m.group("seg")), int(m.group("off"), 16))] = (
                f"{m.group('name')}_{m.group('seg')}_{m.group('off')}{m.group('suffix')}"
            )
    return symbols


def make_name_map(known_symbols: dict[tuple[int, int], str]) -> dict[str, tuple[int, int]]:
    return {name: (seg, off) for (seg, off), name in known_symbols.items()}


def range_contains(
    point_seg: int,
    point_off: int,
    start: tuple[int, int] | None,
    end: tuple[int, int] | None,
) -> bool:
    if start is None or end is None:
        return True
    return point_seg == start[0] == end[0] and start[1] <= point_off <= end[1]


def parse_hex_bytes(token_text: str) -> list[int]:
    if not token_text:
        return []
    bytes_ = []
    for token in token_text.split():
        if len(token) != 2:
            raise ValueError(f"invalid byte token {token!r}")
        bytes_.append(int(token, 16))
    return bytes_


def split_leading_hex_bytes(rest: str) -> tuple[list[int], str]:
    tokens = rest.split()
    if not tokens:
        return [], ""

    byte_values: list[int] = []
    idx = 0
    while idx < len(tokens) and BASIC_HEX_BYTE_RE.fullmatch(tokens[idx]):
        byte_values.append(int(tokens[idx], 16))
        idx += 1

    if idx >= len(tokens):
        return byte_values, ""

    return byte_values, " ".join(tokens[idx:])


def parse_seg_off(text: str) -> tuple[int, int]:
    seg, off = text.split(":", 1)
    return int(seg, 16), int(off, 16)


def parse_bank_bases(values: list[str]) -> dict[int, int]:
    bases: dict[int, int] = {}
    for value in values:
        if "=" not in value:
            raise ValueError(f"invalid --bank-base {value!r}; expected SEG=file:OFFSET")
        seg_text, base_text = value.split("=", 1)
        seg = parse_addr_part(seg_text)
        if not 0 <= seg <= 0xFFFF:
            raise ValueError(f"bank segment out of range: {seg_text}")
        bases[seg] = parse_file_base(base_text)
    return bases


def normalize_seg_text(seg_text: str) -> int:
    if len(seg_text) == 5 and seg_text[0] in "cC":
        seg_text = seg_text[1:]
    return int(seg_text, 16)


def extract_asm_lines(lines: list[str]) -> list[str]:
    """Extract only rows inside Markdown asm fences."""

    in_asm_block = False
    saw_asm_block = False
    extracted: list[str] = []

    for raw in lines:
        if FENCE_RE.match(raw):
            if in_asm_block:
                in_asm_block = False
            elif ASM_FENCE_START_RE.match(raw):
                in_asm_block = True
                saw_asm_block = True
            continue
        if in_asm_block:
            extracted.append(raw)

    return extracted if saw_asm_block else lines


def parse_rows(lines: list[str]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for raw in lines:
        m = ADDR_RE.match(raw)
        if m:
            seg_text, off_text = m.group("addr").split(":", 1)
            seg = int(seg_text, 16)
            off = int(off_text, 16)
            rest = m.group("body")

            # Ellipsis indicates bytes were intentionally omitted from the source
            # disassembly. Keep this row so we can synthesize bytes from ROM.
            if rest.startswith("..."):
                rows.append(
                    {
                        "kind": "gap",
                        "raw": raw,
                        "seg": seg,
                        "off": off,
                        "comment": rest[3:].strip(),
                    }
                )
                continue

            ellipsis_match = ELLIPSIS_REST_RE.match(rest)
            if ellipsis_match:
                byte_text = ellipsis_match.group("bytes").strip()
                comment = (ellipsis_match.group("tail") or "").strip()
                if byte_text and all(len(tok) == 2 for tok in byte_text.split()):
                    rows.append(
                        {
                            "kind": "gap",
                            "raw": raw,
                            "seg": seg,
                            "off": off,
                            "comment": comment,
                        }
                    )
                    continue

            byte_values, ins = split_leading_hex_bytes(rest)
            if not byte_values:
                rows.append({"kind": "other", "raw": raw})
                continue

            ins = ins.strip()
            if not ins or ins.startswith(";"):
                rows.append(
                    {
                        "kind": "data",
                        "raw": raw,
                        "seg": seg,
                        "off": off,
                        "bytes": byte_values,
                        "ins": ins,
                    }
                )
                continue

            rows.append(
                {
                    "kind": "asm",
                    "raw": raw,
                    "seg": seg,
                    "off": off,
                    "bytes": byte_values,
                    "ins": ins,
                }
            )
            continue

        m = LABEL_RE.match(raw)
        if m:
            label = m.group("label")
            label_addr = None
            if m2 := LABEL_ADDR_RE.match(label):
                label_addr = (normalize_seg_text(m2.group("seg")), int(m2.group("off"), 16))
            rows.append({"kind": "label", "raw": raw, "label": label, "addr": label_addr})
            continue

        rows.append({"kind": "other", "raw": raw})

    return rows


def select_rows(
    rows: list[dict[str, Any]],
    start: tuple[int, int] | None,
    end: tuple[int, int] | None,
) -> Iterable[int]:
    if start is None or end is None:
        return range(len(rows))

    selected = {
        idx
        for idx, row in enumerate(rows)
        if row["kind"] in {"asm", "data", "gap", "label"}
        and (row["kind"] == "label" or range_contains(row["seg"], row["off"], start, end))  # type: ignore
    }
    if selected:
        queue = list(selected)
        while queue:
            idx = queue.pop()
            for near in (idx - 1, idx + 1):
                if near < 0 or near >= len(rows) or near in selected:
                    continue
                row = rows[near]
                if row["kind"] in {"asm", "data", "gap"}:
                    seg = row["seg"]  # type: ignore
                    off = row["off"]  # type: ignore
                    if not range_contains(seg, off, start, end):
                        continue
                selected.add(near)
                queue.append(near)
        return sorted(selected)

    # Fallback for label-rich but non-instrumented input: slice between
    # function entry labels if no instruction row exactly matches.
    in_range_labels = [
        (idx, row["addr"][1])  # type: ignore
        for idx, row in enumerate(rows)
        if row["kind"] == "label"
        and row.get("addr") is not None
        and range_contains(row["addr"][0], row["addr"][1], start, end)  # type: ignore
    ]
    if in_range_labels:
        first_idx = in_range_labels[0][0]
        max_off = max(off for _, off in in_range_labels)
        next_idx = len(rows)
        for i, row in enumerate(rows[first_idx + 1 :], first_idx + 1):
            if row["kind"] != "label" or row.get("addr") is None:
                continue
            if row["addr"][1] > max_off:  # type: ignore
                next_idx = i
                break
        return range(first_idx, next_idx)

    raise SystemExit("No instruction rows selected for requested range.")


def build_local_label_map(
    rows: list[dict[str, Any]],
    selected_indices: Iterable[int],
    start: tuple[int, int] | None,
    end: tuple[int, int] | None,
    known_symbols: dict[tuple[int, int], str],
) -> tuple[dict[int, str], set[str], dict[int, list[str]]]:
    local_labels: dict[int, str] = {}
    used_labels: set[str] = set()
    labelled_offsets: dict[int, list[str]] = {}

    pending_labels: list[str] = []

    for idx in selected_indices:
        row = rows[idx]
        if row["kind"] == "label":
            label = row["label"]  # type: ignore
            pending_labels.append(label)
            continue

        if row["kind"] not in {"asm", "data", "gap"}:
            continue

        off = row["off"]  # type: ignore
        if pending_labels:
            labelled_offsets.setdefault(off, []).extend(pending_labels)
            for label in pending_labels:
                used_labels.add(label)
            pending_labels.clear()

        if start is not None and end is not None and row["seg"] == start[0] == end[0]:
            if (row["seg"], off) in known_symbols and (row["seg"], off) not in local_labels:
                local_labels[off] = known_symbols[(row["seg"], off)]

        if row["kind"] != "asm":
            continue

        body = row["ins"]  # type: ignore
        if ";" in body:
            body = body.split(";", 1)[0]
        parts = body.strip().split(None, 1)
        if not parts or not is_control_flow_op(parts[0]):
            continue

        for match in SEG_OFF_RE.finditer(body):
            target_seg = int(match.group("seg"), 16)
            target_off = int(match.group("off"), 16)
            target_key = (target_seg, target_off)
            if target_off in local_labels:
                continue

            if start is not None and end is not None and target_seg == start[0] == end[0]:
                if start[1] <= target_off <= end[1]:
                    local_labels[target_off] = f"loc_{target_off:04X}"

    return local_labels, used_labels, labelled_offsets


def rewrite_instruction(
    seg: int,
    off: int,
    ins: str,
    local_labels: dict[int, str],
    known_symbols: dict[tuple[int, int], str],
    known_names: dict[str, tuple[int, int]],
    start: tuple[int, int] | None,
    end: tuple[int, int] | None,
    unresolved_helpers: dict[str, tuple[int, int]],
    defined_symbols: set[str],
) -> str:
    if ";" in ins:
        body, comment = ins.split(";", 1)
        comment = ";" + comment
    else:
        body, comment = ins, ""

    parts = body.strip().split(None, 1)
    if not parts:
        return ins

    op = parts[0]
    if not is_control_flow_op(op):
        return ins

    if "[" in body:
        return ins

    def repl_seg_off(match: re.Match[str]) -> str:
        target_seg = int(match.group("seg"), 16)
        target_off = int(match.group("off"), 16)
        target_key = (target_seg, target_off)
        if target_key in known_symbols:
            name = known_symbols[target_key]
            if name not in defined_symbols:
                unresolved_helpers[name] = target_key
            return name

        if target_seg == seg and target_off in local_labels:
            return local_labels[target_off]

        if start is not None and end is not None and target_seg == seg and start[1] <= target_off <= end[1]:
            if target_off not in local_labels:
                local_labels[target_off] = f"loc_{target_off:04X}"
            return local_labels[target_off]

        if target_seg == seg:
            helper_name = local_labels.get(target_off)
            if helper_name is None:
                helper_name = f"loc_{target_off:04X}"
                local_labels[target_off] = helper_name
            if helper_name not in defined_symbols:
                unresolved_helpers[helper_name] = target_key
            return helper_name

        return f"0x{target_seg:04X}:0x{target_off:04X}"

    body = SEG_OFF_RE.sub(repl_seg_off, body)

    def repl_hex(match: re.Match[str]) -> str:
        target_key = (seg, int(match.group("value"), 16))
        if target_key in local_labels:
            return local_labels[target_key[1]]
        if target_key in known_symbols:
            name = known_symbols[target_key]
            if name not in defined_symbols:
                unresolved_helpers[name] = target_key
            return name
        if start is not None and end is not None and start[1] <= target_key[1] <= end[1]:
            if target_key[1] not in local_labels:
                local_labels[target_key[1]] = f"loc_{target_key[1]:04X}"
            return local_labels[target_key[1]]
        return f"0x{target_key[1]:04X}"

    body = HEXLIT_RE.sub(repl_hex, body)

    def canonicalize_token(match: re.Match[str]) -> str:
        token = match.group("name")
        token_without_dot = token[1:] if token.startswith(".") else token
        if token in defined_symbols or token_without_dot in defined_symbols:
            return token
        if (not token.startswith(".")) and f".{token}" in defined_symbols:
            return token

        target_key = known_names.get(token)
        if target_key is None:
            m = LABEL_ADDR_RE.match(token)
            if not m:
                return token
            target_key = (normalize_seg_text(m.group("seg")), int(m.group("off"), 16))
            token = known_symbols.get(target_key, token)
        if target_key[0] != seg:
            return f"0x{target_key[0]:04X}:0x{target_key[1]:04X}"
        if token not in defined_symbols:
            unresolved_helpers[token] = target_key
        return token

    def mark_named_target(match: re.Match[str]) -> str:
        return canonicalize_token(match)

    body = NAME_REF_RE.sub(mark_named_target, body)

    if comment:
        return f"{body}{'    ' if body and body[-1].isalnum() else ' '}{comment}".rstrip()
    return body


def format_bytes_as_db(blob: bytes) -> list[str]:
    out = []
    for i in range(0, len(blob), 8):
        chunk = blob[i : i + 8]
        out.append(f"    db {', '.join('0x%02x' % b for b in chunk)}")
    return out


def _byte_address(seg: int, off: int, bank_bases: dict[int, int], rom: bytes) -> int:
    if seg in bank_bases:
        file_off = bank_bases[seg] + off
    else:
        file_off = phys_to_file(seg_off_to_phys(seg, off))

    if file_off < 0 or file_off > len(rom):
        raise ValueError(f"ROM offset {file_off:#x} out of bounds for {seg:04X}:{off:04X}")
    return file_off


def emit_rows(
    rows: list[dict[str, Any]],
    selected_indices: Iterable[int],
    local_labels: dict[int, str],
    used_labels: set[str],
    known_symbols: dict[tuple[int, int], str],
    known_names: dict[str, tuple[int, int]],
    labelled_offsets: dict[int, list[str]],
    start: tuple[int, int] | None,
    end: tuple[int, int] | None,
    bank_bases: dict[int, int],
    rom: bytes,
) -> tuple[list[str], dict[str, tuple[int, int]]]:
    unresolved_helpers: dict[str, tuple[int, int]] = {}
    selected = sorted(selected_indices)

    row_by_offset: dict[int, dict[str, Any]] = {}
    for idx in selected:
        row = rows[idx]
        if row["kind"] in {"asm", "data", "gap"}:
            row_by_offset[int(row["off"])] = row  # type: ignore

    if start is None or end is None:
        raise SystemExit("--start and --end are required when emitting synthesized rows")

    seg, start_off = start
    end_off = end[1]

    boundaries: set[int] = {start_off, end_off + 1}
    for off in row_by_offset:
        row = row_by_offset[off]
        boundaries.add(off)
        if row["kind"] in {"asm", "data"} and row.get("bytes"):
            boundaries.add(off + len(row["bytes"]))  # type: ignore
    for off in local_labels:
        if start_off <= off <= end_off:
            boundaries.add(off)
    boundaries.update(off for off in labelled_offsets if start_off <= off <= end_off)

    offsets = sorted(filter(lambda x: start_off <= x <= end_off + 1, boundaries))
    emitted: list[str] = []
    emitted_offsets: set[int] = set()

    for prev_off, next_off in zip(offsets, offsets[1:]):
        if prev_off >= end_off + 1:
            break
        prev_off = max(prev_off, start_off)
        next_off = min(next_off, end_off + 1)
        if prev_off >= next_off:
            continue

        for label in labelled_offsets.get(prev_off, []):
            if label not in emitted_offsets:
                emitted.append(f"{label}:")
                emitted_offsets.add(label)
                used_labels.add(label)

        if prev_off in local_labels and local_labels[prev_off] not in used_labels:
            emitted.append(f"{local_labels[prev_off]}:")
            emitted_offsets.add(local_labels[prev_off])
            used_labels.add(local_labels[prev_off])

        row = row_by_offset.get(prev_off)
        if row is None or row["kind"] == "gap":
            blob = rom[
                _byte_address(seg, prev_off, bank_bases, rom) : _byte_address(
                    seg, next_off, bank_bases, rom
                )
            ]
            lines = format_bytes_as_db(blob)
            if row is not None and row.get("comment"):
                comment = row["comment"]  # type: ignore
                if lines:
                    lines[0] += f"    ; {comment}"
            emitted.extend(lines)
            continue

        row_end = prev_off + len(row.get("bytes", []))  # type: ignore
        if row["kind"] == "asm":
            raw_ins = row["ins"]  # type: ignore
            opcode = raw_ins.split(";", 1)[0].strip().split(None, 1)[0] if raw_ins.strip() else ""
            if opcode and is_control_flow_op(opcode):
                rewritten = rewrite_instruction(
                    seg=seg,
                    off=prev_off,
                    ins=raw_ins,
                    local_labels=local_labels,
                    known_symbols=known_symbols,
                    known_names=known_names,
                    start=start,
                    end=end,
                    unresolved_helpers=unresolved_helpers,
                    defined_symbols=used_labels,
                )
                emitted.append(f"    {rewritten}")
            else:
                lines = format_bytes_as_db(bytes(row["bytes"]))  # type: ignore
                if lines:
                    lines[0] += f"    ; {raw_ins}"
                emitted.extend(lines)
            if row_end < next_off:
                blob = rom[
                    _byte_address(seg, row_end, bank_bases, rom) : _byte_address(
                        seg, next_off, bank_bases, rom
                    )
                ]
                emitted.extend(format_bytes_as_db(blob))
            continue

        if row["kind"] == "data":
            blob = bytes(row["bytes"])  # type: ignore
            if row_end > next_off:
                blob = blob[: next_off - prev_off]
            lines = format_bytes_as_db(blob)
            if not lines:
                continue
            if row.get("ins"):
                lines[0] += f"    ; {row['ins']}"  # type: ignore
            emitted.extend(lines)
            if row_end < next_off:
                blob = rom[
                    _byte_address(seg, row_end, bank_bases, rom) : _byte_address(
                        seg, next_off, bank_bases, rom
                    )
                ]
                emitted.extend(format_bytes_as_db(blob))
            continue

    helper_lines = []
    if unresolved_helpers:
        helper_lines.append("")
        helper_lines.append("; helper call targets covered by other slices")
        for helper_name, (_helper_seg, helper_off) in sorted(unresolved_helpers.items()):
            helper_lines.append(f"{helper_name} equ 0x{helper_off:04X}")

    return emitted + helper_lines, unresolved_helpers


def transform(
    lines: list[str],
    start: tuple[int, int] | None,
    end: tuple[int, int] | None,
    known_symbols: dict[tuple[int, int], str],
    known_names: dict[str, tuple[int, int]],
    bank_bases: dict[int, int],
    rom: bytes,
) -> str:
    rows = parse_rows(extract_asm_lines(lines))
    selected_indices = list(select_rows(rows, start, end))

    local_labels, used_labels, labelled_offsets = build_local_label_map(
        rows,
        selected_indices,
        start,
        end,
        known_symbols,
    )

    emitted_lines, _ = emit_rows(
        rows=rows,
        selected_indices=selected_indices,
        local_labels=local_labels,
        used_labels=used_labels,
        known_symbols=known_symbols,
        known_names=known_names,
        labelled_offsets=labelled_offsets,
        start=start,
        end=end,
        bank_bases=bank_bases,
        rom=rom,
    )

    seg, s_off = start
    e_off = end[1]
    header = [
        f"; Generated from disasm: {seg:04X}:{s_off:04X}-{e_off:04X}",
        "; NOTE: branch target labels are local aliases for readability.",
        "",
        "BITS 16",
        f"org 0x{s_off:04X}",
        "",
    ]
    return "\n".join(header + emitted_lines) + "\n"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate NASM slice from labeled disasm text.")
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--start", help="SEG:OFF start address")
    parser.add_argument("--end", help="SEG:OFF end address")
    parser.add_argument(
        "--asm-dir",
        type=Path,
        default=Path("v2.1/asm"),
        help="Directory with existing asm files for symbol lookup",
    )
    parser.add_argument(
        "--rom",
        type=Path,
        default=Path("v2.1/t4_ir_2.1.ic303"),
        help="ROM image to read for omitted byte ranges",
    )
    parser.add_argument(
        "--bank-base",
        action="append",
        default=["3000=file:0x30000"],
        metavar="SEG=file:OFFSET",
        help="map a segment to ROM file base offset; repeatable",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if bool(args.start) ^ bool(args.end):
        raise SystemExit("--start and --end must be used together")

    lines = args.input.read_text(encoding="ascii").splitlines()
    known_symbols = parse_symbol_map(args.asm_dir)
    known_names = make_name_map(known_symbols)
    start = parse_seg_off(args.start) if args.start else None
    end = parse_seg_off(args.end) if args.end else None
    bank_bases = parse_bank_bases(args.bank_base)
    rom = read_rom(args.rom)

    output = transform(lines, start, end, known_symbols, known_names, bank_bases, rom)
    args.output.write_text(output, encoding="ascii")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
