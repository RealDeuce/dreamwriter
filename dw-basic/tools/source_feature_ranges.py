#!/usr/bin/env python3
"""Wrap generated NASM symbol ranges in feature-condition blocks.

This pass is intentionally small and literal. It lets converted source stay
mechanically close to the original file while build-profile omissions are
recorded as named symbol ranges applied after conversion.
"""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path


IDENT_RE = r"[A-Za-z_.$?][\w.$?]*"


@dataclass(frozen=True)
class FeatureRange:
    name: str
    feature: str
    start: str
    end: str


@dataclass(frozen=True)
class RetStubs:
    range_name: str
    labels: tuple[str, ...]


def symbol_line_re(symbol: str) -> re.Pattern[str]:
    escaped = re.escape(symbol)
    name_boundary = r"(?![\w.$?])"
    return re.compile(
        rf"^\s*(?:"
        rf"(?:R|R1|RINIT)\s+{escaped}{name_boundary}|"
        rf"{escaped}\s*:|"
        rf"{escaped}\s+equ{name_boundary}"
        rf")"
    )


def parse_range(text: str) -> FeatureRange:
    parts = text.split(":")
    if len(parts) != 4:
        raise argparse.ArgumentTypeError(
            "ranges must be NAME:FEATURE:START_SYMBOL:END_SYMBOL"
        )
    name, feature, start, end = parts
    for label, value in (
        ("NAME", name),
        ("FEATURE", feature),
        ("START_SYMBOL", start),
    ):
        if not re.fullmatch(IDENT_RE, value):
            raise argparse.ArgumentTypeError(f"{label} is not a NASM identifier: {value}")
    if end != "EOF" and not re.fullmatch(IDENT_RE, end):
        raise argparse.ArgumentTypeError(f"END_SYMBOL is not a NASM identifier or EOF: {end}")
    return FeatureRange(name=name, feature=feature, start=start, end=end)


def parse_ret_stubs(text: str) -> RetStubs:
    parts = text.split(":")
    if len(parts) != 2:
        raise argparse.ArgumentTypeError("ret stubs must be RANGE_NAME:LABEL[,LABEL...]")
    range_name, labels_text = parts
    labels = tuple(label.strip() for label in labels_text.split(",") if label.strip())
    if not re.fullmatch(IDENT_RE, range_name):
        raise argparse.ArgumentTypeError(f"RANGE_NAME is not a NASM identifier: {range_name}")
    if not labels:
        raise argparse.ArgumentTypeError("ret stubs need at least one label")
    for label in labels:
        if not re.fullmatch(IDENT_RE, label):
            raise argparse.ArgumentTypeError(f"stub label is not a NASM identifier: {label}")
    return RetStubs(range_name=range_name, labels=labels)


def find_symbol_line(lines: list[str], symbol: str) -> int:
    pattern = symbol_line_re(symbol)
    for index, line in enumerate(lines):
        stripped = line.strip()
        declaration = re.fullmatch(r"(?:global|extern)\s+(.+)", stripped)
        if declaration:
            names = [name.strip() for name in declaration.group(1).split(",")]
            if symbol in names:
                return index
        if pattern.search(line):
            return index
    raise SystemExit(f"symbol not found for feature range: {symbol}")


def apply_range(lines: list[str], feature_range: FeatureRange, ret_stubs: list[RetStubs]) -> list[str]:
    start_marker = f"; DW-BASIC feature range {feature_range.name}:"
    if any(start_marker in line for line in lines):
        return lines

    start = find_symbol_line(lines, feature_range.start)
    end = len(lines) if feature_range.end == "EOF" else find_symbol_line(lines, feature_range.end)
    if end <= start:
        raise SystemExit(
            f"invalid feature range {feature_range.name}: "
            f"{feature_range.end} is not after {feature_range.start}"
        )

    begin = (
        f"%if {feature_range.feature} ; DW-BASIC feature range "
        f"{feature_range.name}: {feature_range.start}..{feature_range.end}"
    )
    finish = f"%endif ; DW-BASIC feature range {feature_range.name}"
    stub_lines: list[str] = []
    for stubs in ret_stubs:
        if stubs.range_name == feature_range.name:
            stub_lines.append(f"%else ; DW-BASIC feature range {feature_range.name} stubs")
            stub_lines.extend(f"{label}:" for label in stubs.labels)
            stub_lines.append("\tRET")
    return lines[:start] + [begin] + lines[start:end] + stub_lines + [finish] + lines[end:]


def patch_file(path: Path, ranges: list[FeatureRange], ret_stubs: list[RetStubs]) -> None:
    text = path.read_text()
    trailing_newline = text.endswith("\n")
    lines = text.splitlines()
    for feature_range in ranges:
        lines = apply_range(lines, feature_range, ret_stubs)
    path.write_text("\n".join(lines) + ("\n" if trailing_newline else ""))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    parser.add_argument(
        "--range",
        dest="ranges",
        action="append",
        required=True,
        type=parse_range,
        help="NAME:FEATURE:START_SYMBOL:END_SYMBOL; end is exclusive",
    )
    parser.add_argument(
        "--else-ret-stubs",
        dest="ret_stubs",
        action="append",
        default=[],
        type=parse_ret_stubs,
        help="RANGE_NAME:LABEL[,LABEL...] to emit local RET labels when the range is disabled",
    )
    args = parser.parse_args()
    patch_file(args.path, args.ranges, args.ret_stubs)


if __name__ == "__main__":
    main()
