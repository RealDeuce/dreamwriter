#!/usr/bin/env python3
"""Generate repository-style NASM slices from labelled disassembly text."""

from __future__ import annotations

import argparse
import re
from collections.abc import Iterable
from pathlib import Path
from typing import Any


ADDR_RE = re.compile(
    r"^(?P<addr>[0-9A-Fa-f]{4}:[0-9A-Fa-f]{4})\s+(?P<byte_line>(?:[0-9A-Fa-f]{2}\s*)+)\s+(?P<ins>.*)$"
)
LABEL_RE = re.compile(r"^\s*(?P<label>[A-Za-z_][A-Za-z0-9_.-]*)\s*:\s*$")
LABEL_ADDR_RE = re.compile(
    r"^(?P<prefix>[A-Za-z_][A-Za-z0-9_.-]*?)_C(?P<seg>[0-9A-Fa-f]{4})_(?P<off>[0-9A-Fa-f]{4})$"
)
HEXLIT_RE = re.compile(r"0x(?P<value>[0-9A-Fa-f]+)")
FENCE_RE = re.compile(r"^\s*```")
ASM_FENCE_START_RE = re.compile(r"^\s*```asm\b", re.IGNORECASE)


def is_control_flow_op(op: str) -> bool:
    """Match control-flow ops that target fixed offsets."""

    op = op.lower()
    return op == "call" or op == "jmp" or op.startswith("j") or op.startswith("loop")


def parse_seg_off(text: str) -> tuple[int, int]:
    seg_text, off_text = text.split(":", 1)
    return int(seg_text, 16), int(off_text, 16)


def parse_symbol_map(asm_dir: Path) -> dict[tuple[int, int], str]:
    """Map addresses to known asm labels by suffix `_CSSSS_OOOO`."""

    symbol_re = re.compile(
        r"^(?P<name>[A-Za-z_][A-Za-z0-9_.-]*?)_C(?P<seg>[0-9A-Fa-f]{4})_(?P<off>[0-9A-Fa-f]{4})\s*:"
    )
    symbols: dict[tuple[int, int], str] = {}
    for path in sorted(asm_dir.glob("*.asm")):
        for raw in path.read_text(encoding="ascii").splitlines():
            m = symbol_re.match(raw.strip())
            if not m:
                continue
            seg = int(m.group("seg"), 16)
            off = int(m.group("off"), 16)
            symbols[(seg, off)] = f"{m.group('name')}_C{m.group('seg')}_{m.group('off')}"
    return symbols


def range_contains(
    point_seg: int,
    point_off: int,
    start: tuple[int, int] | None,
    end: tuple[int, int] | None,
) -> bool:
    if start is None or end is None:
        return True
    return point_seg == start[0] == end[0] and start[1] <= point_off <= end[1]


def parse_rows(lines: list[str]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for raw in lines:
        m = ADDR_RE.match(raw)
        if m:
            seg, off = parse_seg_off(m.group("addr"))
            rows.append(
                {
                    "kind": "instr",
                    "raw": raw,
                    "seg": seg,
                    "off": off,
                    "ins": m.group("ins"),
                }
            )
            continue

        m = LABEL_RE.match(raw)
        if m:
            label = m.group("label")
            label_addr = None
            if m2 := LABEL_ADDR_RE.match(label):
                label_addr = (int(m2.group("seg"), 16), int(m2.group("off"), 16))
            rows.append(
                {
                    "kind": "label",
                    "raw": raw,
                    "label": label,
                    "addr": label_addr,
                }
            )
            continue

        rows.append({"kind": "other", "raw": raw})

    return rows


def extract_asm_lines(lines: list[str]) -> list[str]:
    """Extract only code inside Markdown ```asm fences, if present."""

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


def select_rows(
    rows: list[dict[str, Any]],
    start: tuple[int, int] | None,
    end: tuple[int, int] | None,
) -> Iterable[int]:
    if start is None or end is None:
        return range(len(rows))

    selected = {idx for idx, row in enumerate(rows) if row["kind"] == "instr" and range_contains(row["seg"], row["off"], start, end)}  # type: ignore
    if selected:
        queue = list(selected)
        while queue:
            idx = queue.pop()
            for near in (idx - 1, idx + 1):
                if near < 0 or near >= len(rows) or near in selected:
                    continue
                row = rows[near]
                if row["kind"] == "instr":
                    seg = row["seg"]  # type: ignore
                    off = row["off"]  # type: ignore
                    if not range_contains(seg, off, start, end):
                        continue
                selected.add(near)
                queue.append(near)
        return sorted(selected)

    # Fallback for label-rich but non-annotated input: slice between
    # function entry labels if no address row directly matches.
    in_range_labels = [
        (idx, row["addr"][1])  # type: ignore[index]
        for idx, row in enumerate(rows)
        if row["kind"] == "label"
        and row.get("addr") is not None
        and range_contains(row["addr"][0], row["addr"][1], start, end)  # type: ignore[index]
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
) -> tuple[dict[int, str], set[str], set[int], set[tuple[int, int]]]:
    local_labels: dict[int, str] = {}
    used_labels: set[str] = set()
    missing_target_offsets: set[int] = set()
    unresolved_known: set[tuple[int, int]] = set()

    pending_labels: list[str] = []

    for idx in selected_indices:
        row = rows[idx]
        if row["kind"] == "label":
            label = row["label"]
            if label is None:
                continue
            pending_labels.append(label)
            continue

        if row["kind"] != "instr":
            continue
        off = row["off"]  # type: ignore

        for label in pending_labels:
            if off not in local_labels:
                local_labels[off] = label
            used_labels.add(label)
        pending_labels.clear()

        if start is not None and end is not None and row["seg"] == start[0] == end[0]:
            seg = row["seg"]  # type: ignore
            if (seg, off) in known_symbols and (seg, off) not in local_labels:
                local_labels[off] = known_symbols[(seg, off)]
                used_labels.add(known_symbols[(seg, off)])

        # Add explicit branch targets so backward jumps get emitted even if their
        # labels are discovered late.
        if start is not None and end is not None and row["seg"] == start[0] == end[0]:
            body = row["ins"]
            if ";" in body:
                body = body.split(";", 1)[0]
            parts = body.strip().split(None, 1)
            if parts and is_control_flow_op(parts[0]):
                for match in HEXLIT_RE.finditer(body):
                    target_off = int(match.group("value"), 16)
                    target_key = (seg, target_off)
                    if target_off not in local_labels:
                        if start[1] <= target_off <= end[1] and target_key in known_symbols:
                            local_labels[target_off] = known_symbols[target_key]
                            used_labels.add(known_symbols[target_key])
                        elif start[1] <= target_off <= end[1]:
                            local_labels[target_off] = f"loc_{target_off:04X}"
                            missing_target_offsets.add(target_off)

    # For label-only input, seed labels from known symbol names when their entries
    # are within the requested range and no local alternative was provided.
    if start is not None and end is not None:
        seg = start[0]
        for off in range(start[1], end[1] + 1):
            key = (seg, off)
            if key in known_symbols and off not in local_labels:
                local_labels[off] = known_symbols[key]
                used_labels.add(known_symbols[key])

    return local_labels, used_labels, missing_target_offsets, unresolved_known


def rewrite_instruction(
    seg: int,
    off: int,
    ins: str,
    local_labels: dict[int, str],
    known_symbols: dict[tuple[int, int], str],
    start: tuple[int, int] | None,
    end: tuple[int, int] | None,
    missing_targets: set[int],
    unresolved_helpers: dict[tuple[int, int], str],
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
    if not is_control_flow_op(parts[0]):
        return ins

    def repl(match: re.Match[str]) -> str:
        target_off = int(match.group("value"), 16)
        target_key = (seg, target_off)

        if target_key in local_labels:
            return local_labels[target_key[1]]
        if target_key in known_symbols:
            name = known_symbols[target_key]
            if name not in defined_symbols:
                unresolved_helpers[target_key] = name
            return name

        if start is not None and end is not None and target_key[0] == start[0] == end[0] and start[1] <= target_off <= end[1]:
            if target_off not in local_labels:
                name = f"loc_{target_off:04X}"
                local_labels[target_off] = name
                missing_targets.add(target_off)
            return local_labels[target_off]

        return f"0x{target_off:04x}"

    body = HEXLIT_RE.sub(repl, body)
    if comment:
        return f"{body}{'    ' if body and body[-1].isalnum() else ' '}{comment}".rstrip()
    return body


def emit_rows(
    rows: list[dict[str, Any]],
    selected_indices: Iterable[int],
    local_labels: dict[int, str],
    used_labels: set[str],
    known_symbols: dict[tuple[int, int], str],
    start: tuple[int, int] | None,
    end: tuple[int, int] | None,
) -> tuple[list[str], dict[tuple[int, int], str]]:
    unresolved_helpers: dict[tuple[int, int], str] = {}
    missing_targets: set[int] = set()
    emitted_label_offsets: set[int] = set()
    emitted_labels: set[str] = set()
    segment = start[0] if start else None

    transformed: list[str] = []
    for idx in sorted(selected_indices):
        row = rows[idx]
        kind = row["kind"]

        if kind == "label":
            label = row["label"]  # type: ignore
            if label in emitted_labels:
                continue
            addr = row.get("addr")  # type: ignore
            if addr is not None and segment is not None and addr[0] == segment:
                off = addr[1]
                if off in local_labels and local_labels[off] == label:
                    if off not in emitted_label_offsets:
                        transformed.append(f"{label}:")
                        emitted_label_offsets.add(off)
                        emitted_labels.add(label)
                        used_labels.add(label)
                    continue
            transformed.append(f"{label}:")
            emitted_labels.add(label)
            continue

        if kind != "instr":
            raw = row["raw"]  # type: ignore
            transformed.append(raw)
            continue

        seg = row["seg"]  # type: ignore
        off = row["off"]  # type: ignore
        ins = row["ins"]  # type: ignore

        defined_symbols = used_labels | set(local_labels.values())

        if off in local_labels and off not in emitted_label_offsets:
            transformed.append(f"{local_labels[off]}:")
            emitted_label_offsets.add(off)
            used_labels.add(local_labels[off])

        rewritten = rewrite_instruction(
            seg=seg,
            off=off,
            ins=ins,
            local_labels=local_labels,
            known_symbols=known_symbols,
            start=start,
            end=end,
            missing_targets=missing_targets,
            unresolved_helpers=unresolved_helpers,
            defined_symbols=defined_symbols,
        )
        transformed.append(f"    {rewritten}")

    return transformed, unresolved_helpers


def transform(
    lines: list[str],
    start: tuple[int, int] | None,
    end: tuple[int, int] | None,
    known_symbols: dict[tuple[int, int], str],
) -> str:
    rows = parse_rows(extract_asm_lines(lines))
    selected_indices = list(select_rows(rows, start, end))

    local_labels, used_labels, _, _ = build_local_label_map(rows, selected_indices, start, end, known_symbols)
    emitted_lines, unresolved_helpers = emit_rows(
        rows=rows,
        selected_indices=selected_indices,
        local_labels=local_labels,
        used_labels=used_labels,
        known_symbols=known_symbols,
        start=start,
        end=end,
    )

    # Include unresolved helper symbols as local aliases when ranges cut helpers from other slices.
    helper_lines = []
    if unresolved_helpers:
        helper_lines.append("")
        helper_lines.append("; helper call targets covered by later slices")
        for (helper_seg, helper_off), helper_name in sorted(unresolved_helpers.items()):
            helper_lines.append(f"{helper_name:<31}equ 0x{helper_off:04X}")

    if start is None or end is None:
        return "\n".join(emitted_lines + helper_lines) + "\n"

    seg, s_off = start
    e_seg, e_off = end
    if e_seg == seg:
        range_desc = f"{seg:04X}:{s_off:04X}-{e_off:04X}"
    else:
        range_desc = f"{seg:04X}:{s_off:04X}-{e_seg:04X}:{e_off:04X}"

    header = [
        f"; Generated from disasm: {range_desc}",
        "; NOTE: branch target labels are local aliases for readability.",
        "",
        "BITS 16",
        f"org 0x{s_off:04X}",
        "",
    ]

    preamble_filter = {
        "org 0x{0:04X}".format(s_off),
        "BITS 16",
    }
    normalized = [
        line for line in emitted_lines if line.strip() not in preamble_filter and line.strip().lower() not in preamble_filter
    ]

    if not (not any(line and line.strip().lower().startswith("bits 16") for line in normalized)):
        pass

    return "\n".join(header + helper_lines + [""] + normalized) + "\n"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate NASM slice from labeled disasm text.")
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--start", help="SEG:OFF start address")
    parser.add_argument("--end", help="SEG:OFF end address")
    parser.add_argument(
        "--asm-dir",
        type=Path,
        default=Path("asm"),
        help="Directory with existing asm files for symbol lookup",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if bool(args.start) ^ bool(args.end):
        raise SystemExit("--start and --end must be used together")

    lines = args.input.read_text(encoding="ascii").splitlines()
    known_symbols = parse_symbol_map(args.asm_dir)
    start = parse_seg_off(args.start) if args.start else None
    end = parse_seg_off(args.end) if args.end else None

    output = transform(lines, start, end, known_symbols)
    args.output.write_text(output, encoding="ascii")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
