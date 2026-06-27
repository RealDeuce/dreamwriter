#!/usr/bin/env python3
"""Decode a DreamWriter native word-processor file payload."""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path


HEADER_FIELDS = (
    ("left_margin", "[7438]", "horizontal units"),
    ("right_span", "[7436]", "horizontal units from left margin"),
    ("layout_threshold", "[742D]", "horizontal units from left margin"),
    ("paper_width_span", "[741B]", "horizontal units from left margin"),
    ("paper_length", "[7423]", "doubled line units"),
    ("top_margin", "[7425]", "doubled line units"),
    ("body_end", "[741F]", "doubled line units"),
)

FIXED_RECORDS = {
    0xE8: ("span/start endpoint", 6),
    0xE9: ("layout/control event", 5),
    0xEC: ("character pitch change", 4),
    0xED: ("line spacing change", 4),
    0xEE: ("range/spacing boundary", 6),
    0xEF: ("vertical/body continuation", 7),
}

PITCH_NAMES = {
    0x00: "PS",
    0x02: "10",
    0x04: "12",
    0x06: "BF",
}

E9_SUBTYPE_NAMES = {
    0x00: "clear transient marker state",
    0x02: "Page End / major page-boundary setup",
    0x04: "clear transient marker state",
    0x06: "formatter/layout boundary, synthesizes byte 0xDF",
    0x08: "toggle [742F] bit 0x10",
    0x0A: "clear transient marker state",
    0x0C: "page/body-limit range setup",
    0x0E: "clear transient marker state",
    0x10: "clear transient marker state",
    0x12: "clear transient marker state",
    0x14: "set [742F] bit 0x01",
    0x16: "clear [742F] bit 0x01",
    0x18: "clear transient marker state",
    0x1A: "signed spacing/indent accumulator",
    0x1C: "clear transient marker state",
    0x1E: "layout-state continuation",
}

EF_SUBTYPE_NAMES = {
    0x00: "saved [749D] checkpoint",
    0x02: "common tail / no subtype-specific mutation",
    0x04: "vertical-position/range boundary adjustment",
    0x06: "vertical body-end continuation boundary",
}

SINGLE_MARKERS = {
    0x0C: "line/document separator",
    0x1A: "EOF/padding marker outside normal native STORE",
    0xD1: "soft/syllable hyphen",
    0xD6: "scanner-recognized boundary byte",
    0xD7: "hyphen-class glyph/control byte",
    0xD8: "required hyphen",
    0xDB: "alternate separator",
    0xE4: "alignment fill",
    0xEA: "formatter run start delimiter",
    0xEB: "formatter run end delimiter",
}


@dataclass(frozen=True)
class NativeHeader:
    length: int
    words: tuple[int, ...]
    tabs: tuple[int, ...]
    body_offset: int
    warnings: tuple[str, ...]


def hex_bytes(data: bytes) -> str:
    return " ".join(f"{byte:02X}" for byte in data)


def hex_lines(data: bytes, base: int = 0) -> list[str]:
    lines = []
    for off in range(0, len(data), 16):
        chunk = data[off : off + 16]
        lines.append(f"0x{base + off:04X}: {hex_bytes(chunk)}")
    return lines


def word(data: bytes) -> int:
    return int.from_bytes(data, "little")


def parse_native_header(data: bytes) -> NativeHeader | None:
    if not data or data[0] != 0xFF:
        return None

    warnings: list[str] = []
    if len(data) < 2:
        return NativeHeader(0, (), (), len(data), ("truncated header length",))

    length = data[1]
    body_offset = 2 + length
    if length < 0x0E:
        warnings.append("header length is below the ROM serializer minimum 0x0E")
    if length > 0x2E:
        warnings.append("header length exceeds the ROM serializer maximum 0x2E")
    if (length - 0x0E) & 1:
        warnings.append("tab-stop tail length is odd")
    if body_offset > len(data):
        warnings.append("payload ends before the declared header length")

    header = data[2 : min(body_offset, len(data))]
    words = tuple(
        word(header[pos : pos + 2])
        for pos in range(0, min(0x0E, len(header) - 1), 2)
    )
    if len(words) != len(HEADER_FIELDS):
        warnings.append("fixed seven-word header is truncated")

    tab_bytes = header[0x0E:]
    tabs = tuple(
        word(tab_bytes[pos : pos + 2])
        for pos in range(0, len(tab_bytes) - 1, 2)
    )
    if len(tabs) > 16:
        warnings.append("more than 16 stored tab stops")
    for index, tab in enumerate(tabs):
        if tab & 0x8000:
            warnings.append(f"tab stop {index} has the runtime sentinel high bit set")

    return NativeHeader(length, words, tabs, min(body_offset, len(data)), tuple(warnings))


def describe_style(byte: int) -> str:
    bit = (byte - 0xF0) // 2
    action = "set/start" if byte % 2 == 0 else "clear/end"
    names = {
        0: "underline",
        1: "formatter structural state",
        2: "overtype/autostrike",
        3: "expanded text",
        4: "boldface",
        5: "superscript",
        6: "subscript",
        7: "encoded slot",
    }
    name = names.get(bit, "unnamed style bit")
    return f"style {action} bit {bit} ({name})"


def describe_pitch(value: int) -> str:
    name = PITCH_NAMES.get(value)
    return f"0x{value:02X}" if name is None else f"0x{value:02X} ({name})"


def describe_line_spacing(value: int) -> str:
    if value <= 0:
        return f"0x{value:02X}"
    whole = value // 2
    if value & 1:
        return f"0x{value:02X} ({whole} 1/2 lines)"
    return f"0x{value:02X} ({whole} line{'s' if whole != 1 else ''})"


def format_record(byte: int, payload: bytes) -> str:
    if byte == 0xE8:
        return f"E8 word_a=0x{word(payload[1:3]):04X} word_b=0x{word(payload[3:5]):04X}"
    if byte == 0xE9:
        subtype = payload[1]
        subtype_name = E9_SUBTYPE_NAMES.get(subtype, "unknown subtype")
        return (
            f"E9 subtype=0x{subtype:02X} ({subtype_name}) "
            f"word=0x{word(payload[2:4]):04X}"
        )
    if byte == 0xEC:
        return f"EC old={describe_pitch(payload[1])} new={describe_pitch(payload[2])}"
    if byte == 0xED:
        return (
            f"ED old={describe_line_spacing(payload[1])} "
            f"new={describe_line_spacing(payload[2])}"
        )
    if byte == 0xEE:
        return f"EE word_a=0x{word(payload[1:3]):04X} word_b=0x{word(payload[3:5]):04X}"
    if byte == 0xEF:
        subtype = payload[1]
        subtype_name = EF_SUBTYPE_NAMES.get(subtype, "unknown subtype")
        signed_byte = int.from_bytes(payload[4:5], "little", signed=True)
        return (
            f"EF subtype=0x{subtype:02X} ({subtype_name}) "
            f"line_pos=0x{word(payload[2:4]):04X} "
            f"signed={signed_byte} signext=0x{payload[5]:02X}"
        )
    raise AssertionError(byte)


def classify_byte(byte: int) -> str:
    if 0xC0 <= byte <= 0xCA:
        return "frame/line glyph byte"
    if byte in SINGLE_MARKERS:
        return SINGLE_MARKERS[byte]
    if 0xF0 <= byte <= 0xFF:
        return describe_style(byte)
    if 0x20 <= byte <= 0xDF:
        return "display/glyph byte"
    if byte < 0x20:
        return "low control byte"
    return "unstructured high byte"


def normalize_legacy_plain(data: bytes, expand_tabs: bool) -> bytes:
    out = bytearray()
    column = 0
    previous_newline = False

    def emit(byte: int) -> None:
        nonlocal column, previous_newline
        out.append(byte)
        previous_newline = False
        if byte == 0x0C:
            column = 0
        else:
            column += 1

    for byte in data:
        if byte in (0x0D, 0x0A):
            if not previous_newline:
                out.append(0x0C)
                column = 0
                previous_newline = True
            continue

        previous_newline = False
        if byte == 0x09:
            if expand_tabs:
                spaces = 8 - (column % 8)
                for _ in range(spaces):
                    emit(0x20)
            else:
                emit(byte)
            continue

        if 0x20 <= byte <= 0xDF:
            emit(byte)

    return bytes(out)


def print_header(header: NativeHeader | None) -> None:
    if header is None:
        print(
            "native_header: absent; first byte is not FF, "
            "so ROM treats this as legacy/plain input"
        )
        return

    print(f"native_header: length=0x{header.length:02X} body_offset=0x{header.body_offset:04X}")
    for index, value in enumerate(header.words):
        name, source, units = HEADER_FIELDS[index]
        print(f"  {name:<17} {source:<7} 0x{value:04X} ({value}) {units}")
    if header.tabs:
        print("  tab_stops: " + " ".join(f"0x{tab:04X}" for tab in header.tabs))
    else:
        print("  tab_stops: none")
    for warning in header.warnings:
        print(f"  warning: {warning}")


def print_body(data: bytes, start: int, limit: int | None) -> int:
    warnings = 0
    end = len(data) if limit is None else min(len(data), start + limit)
    pos = start
    while pos < end:
        byte = data[pos]
        if byte in FIXED_RECORDS:
            name, size = FIXED_RECORDS[byte]
            record = data[pos : pos + size]
            if len(record) < size:
                print(f"0x{pos:04X}: {hex_bytes(record):<20} truncated {name} record")
                warnings += 1
                break
            close = record[-1]
            suffix = ""
            if close != byte:
                suffix = f" warning: closing marker is 0x{close:02X}, expected 0x{byte:02X}"
                warnings += 1
            if byte == 0xEF:
                expected = 0xFF if record[4] & 0x80 else 0x00
                if record[5] != expected:
                    suffix += f" warning: sign extension expected 0x{expected:02X}"
                    warnings += 1
            print(f"0x{pos:04X}: {hex_bytes(record):<20} {format_record(byte, record)}; {name}{suffix}")
            pos += size
            continue

        print(f"0x{pos:04X}: {byte:02X}                   {classify_byte(byte)}")
        pos += 1
    return warnings


def print_legacy_preview(data: bytes, expand_tabs: bool) -> None:
    normalized = normalize_legacy_plain(data, expand_tabs)
    tab_note = "expanded to spaces" if expand_tabs else "preserved as 09"
    print(
        f"legacy_plain_normalized: size=0x{len(normalized):X} ({len(normalized)}), "
        f"tabs {tab_note}"
    )
    for line in hex_lines(normalized):
        print(f"  {line}")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("payload", type=Path, help="native WP payload bytes")
    parser.add_argument(
        "--body",
        action="store_true",
        help="also print a byte/record walk of the body stream",
    )
    parser.add_argument(
        "--body-limit",
        type=lambda text: int(text, 0),
        help="maximum number of body bytes to scan",
    )
    parser.add_argument(
        "--legacy-preview",
        action="store_true",
        help="for non-FF payloads, print the ROM-style legacy/plain normalized stream",
    )
    parser.add_argument(
        "--legacy-expand-tabs",
        action="store_true",
        help="expand tabs to eight-column stops in --legacy-preview",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="exit nonzero if native header or body-record validation warnings occur",
    )
    parser.add_argument(
        "--require-native",
        action="store_true",
        help="exit nonzero if the payload does not start with a native FF header",
    )
    args = parser.parse_args(argv)

    try:
        data = args.payload.read_bytes()
    except OSError as exc:
        print(f"{args.payload}: {exc}", file=sys.stderr)
        return 1

    print(f"payload_size: 0x{len(data):X} ({len(data)})")
    header = parse_native_header(data)
    print_header(header)
    warning_count = len(header.warnings) if header is not None else 0
    if header is None and args.require_native:
        print("validation_error: native FF header required", file=sys.stderr)
        warning_count += 1
    if header is None and args.legacy_preview:
        print_legacy_preview(data, args.legacy_expand_tabs)
    if args.body:
        body_offset = header.body_offset if header is not None else 0
        print("body:")
        warning_count += print_body(data, body_offset, args.body_limit)
    return 1 if args.strict and warning_count else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
