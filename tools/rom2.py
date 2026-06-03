#!/usr/bin/env python3
"""Small helpers for the DreamWriter T400 ROM 2.1 image."""

from __future__ import annotations

import argparse
import glob as _glob
import hashlib
import re
import string
import subprocess
import sys
from pathlib import Path


ROM_PATH = Path("t4_ir_2.1.ic303")
REGION_MAP_PATH = Path("docs/rom-regions.tsv")
ROM_SIZE = 0x80000
ROM_LOAD_PHYS = 0x80000
RAM_SIZE = 0x40000
BANK_WINDOW_SIZE = 0x20000
MAIN_GLYPH_BASE = 0x580B6
BOLD_GLYPH_BASE = 0x586B6
SMALL_GLYPH_BASE = 0x58CB6
SMALL_BOLD_GLYPH_BASE = 0x592B6
NARROW_GLYPH_BASE = 0x598B6
NARROW_BOLD_GLYPH_BASE = 0x59EB6
NARROW_SMALL_GLYPH_BASE = 0x5A4B6
NARROW_SMALL_BOLD_GLYPH_BASE = 0x5AAB6
SPARSE_GLYPH_BASE = 0x5B0B6
SPARSE_BOLD_GLYPH_BASE = 0x5B6B6
SPARSE_SMALL_GLYPH_BASE = 0x5BCB6
SPARSE_SMALL_BOLD_GLYPH_BASE = 0x5C2B6
SHA256 = "bb6a437d4c25f90eb7a0b8bc3d41e1ca2c74196aabe60954a598c66405397757"

PRINTABLE = set(bytes(string.printable, "ascii")) - {0x0B, 0x0C}
TODO_XREF_RE = re.compile(r"TODO-xref", re.IGNORECASE)
ADDRESS_TOKEN_RE = re.compile(
    r"\b(?:file:[0-9A-Fa-fx$]+|phys:[0-9A-Fa-fx$]+|[0-9A-Fa-f]{3,4}:[0-9A-Fa-f]{4})\b",
    re.IGNORECASE,
)
SEG_OFF_LABEL_RE = re.compile(r"^([0-9A-Fa-f]{3,4}):([0-9A-Fa-f]{4})$")
NDISASM_LINE_RE = re.compile(r"^([0-9A-Fa-f]+)(\s+)([0-9A-Fa-f]+)(\s+)(.*)$")


def parse_int(value: str) -> int:
    value = value.strip().lower()
    if value.startswith("$"):
        return int(value[1:], 16)
    if any(char in value for char in "abcdef"):
        return int(value, 16)
    return int(value, 0)


def parse_addr_part(value: str) -> int:
    value = value.strip().lower()
    if value.startswith(("0x", "$")):
        return parse_int(value)
    return int(value, 16)


def file_to_phys(offset: int) -> int:
    if not 0 <= offset < ROM_SIZE:
        raise ValueError(f"file offset out of ROM range: 0x{offset:x}")
    return ROM_LOAD_PHYS + offset


def phys_to_file(phys: int) -> int:
    offset = phys - ROM_LOAD_PHYS
    if not 0 <= offset < ROM_SIZE:
        raise ValueError(f"physical address out of ROM range: 0x{phys:x}")
    return offset


def seg_off_to_phys(seg: int, off: int) -> int:
    phys = ((seg << 4) + off) & 0xFFFFF
    phys_to_file(phys)
    return phys


def phys_to_seg_off(phys: int, seg: int) -> int:
    phys_to_file(phys)
    base = (seg << 4) & 0xFFFFF
    off = (phys - base) & 0xFFFFF
    if off > 0xFFFF:
        end = (base + 0xFFFF) & 0xFFFFF
        if base <= end:
            window = f"0x{base:05X}..0x{end:05X}"
        else:
            window = f"0x{base:05X}..0xFFFFF, 0x00000..0x{end:05X}"
        raise ValueError(
            f"physical address 0x{phys:X} is outside segment {seg:04X} window {window}"
        )
    return off


def canonical_seg_off(phys: int) -> tuple[int, int]:
    phys_to_file(phys)
    seg = phys >> 4
    off = phys & 0xF
    return seg, off


def c000_off(phys: int) -> str:
    if 0xC0000 <= phys <= 0xCFFFF:
        return f"C000:{phys - 0xC0000:04X}"
    return ""


def describe_phys(phys: int, preferred_seg: int | None = None) -> str:
    offset = phys_to_file(phys)
    if preferred_seg is None:
        seg, off = canonical_seg_off(phys)
    else:
        seg = preferred_seg
        off = phys_to_seg_off(phys, seg)
    c000 = c000_off(phys)
    aliases = f"  {c000}" if c000 else ""
    return f"file 0x{offset:05X}  phys 0x{phys:05X}  {seg:04X}:{off:04X}{aliases}"


def expand_markdown_inputs(values: list[str], allow_dirs: bool = True) -> list[Path]:
    collected: list[Path] = []
    for value in values:
        expanded = (
            _glob.glob(value)
            if any(ch in value for ch in "*?[")
            else [value]
        )
        for item in expanded:
            path = Path(item)
            if path.is_dir():
                if allow_dirs:
                    collected.extend(path.glob("*.md"))
                continue
            if path.suffix.lower() == ".md" and path.exists():
                collected.append(path)

    seen: set[str] = set()
    unique: list[Path] = []
    for path in sorted(collected, key=lambda path: str(path)):
        key = str(path)
        if key in seen:
            continue
        seen.add(key)
        unique.append(path)
    return unique


def extract_address_tokens(text: str) -> list[str]:
    return ADDRESS_TOKEN_RE.findall(text)


def parse_addr_expr(value: str, default_seg: int | None = None) -> tuple[str, int]:
    if ":" in value and not value.lower().startswith(("file:", "phys:")):
        seg_text, off_text = value.split(":", 1)
        seg = parse_addr_part(seg_text)
        off = parse_addr_part(off_text)
        return f"{seg:04X}:{off:04X}", seg_off_to_phys(seg, off)
    if value.lower().startswith("file:"):
        raw = value.split(":", 1)[1]
        return f"file:{raw}", file_to_phys(parse_int(raw))
    if value.lower().startswith("phys:"):
        raw = value.split(":", 1)[1]
        return f"phys:{raw}", parse_int(raw)

    raw = parse_int(value)
    if default_seg is not None:
        if not 0 <= raw <= 0xFFFF:
            raise ValueError(
                f"segment offset out of range for {default_seg:04X}: 0x{raw:x}"
            )
        return f"{default_seg:04X}:{raw:04X}", seg_off_to_phys(default_seg, raw)
    if raw < ROM_SIZE:
        return f"file:0x{raw:X}", file_to_phys(raw)
    return f"phys:0x{raw:X}", raw


def parse_seg_off_label(label: str) -> tuple[int, int] | None:
    match = SEG_OFF_LABEL_RE.match(label)
    if not match:
        return None
    return int(match.group(1), 16), int(match.group(2), 16)


def parse_file_base(value: str) -> int:
    if value.lower().startswith("file:"):
        value = value.split(":", 1)[1]
    offset = parse_int(value)
    if not 0 <= offset < ROM_SIZE:
        raise ValueError(f"file offset out of ROM range: 0x{offset:x}")
    return offset


def format_ndisasm_output(output: str, segment: int | None = None) -> str:
    """Convert ndisasm output into the annotated style used in docs."""
    lines = []
    for line in output.splitlines(keepends=True):
        body = line[:-1] if line.endswith("\n") else line
        newline = "\n" if line.endswith("\n") else ""
        match = NDISASM_LINE_RE.match(body)
        if not match:
            lines.append(line)
            continue
        addr_text = match.group(1)
        try:
            offset = int(addr_text, 16)
        except ValueError:
            lines.append(line)
            continue
        if segment is not None and offset <= 0xFFFF:
            addr_text = f"{segment:04X}:{offset:04X}"

        byte_text = match.group(3)
        if len(byte_text) % 2 == 0:
            byte_text = " ".join(byte_text[i : i + 2] for i in range(0, len(byte_text), 2))
        lines.append(f"{addr_text}  {byte_text:<17} {match.group(5)}{newline}")
    return "".join(lines)


def format_addr_row(
    label: str, phys: int, fmt: str, preferred_seg: int | None = None
) -> str:
    if fmt == "tsv":
        offset = phys_to_file(phys)
        if preferred_seg is None:
            seg, off = canonical_seg_off(phys)
        else:
            seg = preferred_seg
            off = phys_to_seg_off(phys, seg)
        c000 = c000_off(phys)
        alias = c000.strip() if c000 else ""
        return f"{label}\t0x{offset:05X}\t0x{phys:05X}\t{seg:04X}:{off:04X}\t{alias}"
    if fmt == "compact":
        offset = phys_to_file(phys)
        if preferred_seg is None:
            seg, off = canonical_seg_off(phys)
        else:
            seg = preferred_seg
            off = phys_to_seg_off(phys, seg)
        return f"{label}: file 0x{offset:05X} phys 0x{phys:05X} {seg:04X}:{off:04X}"
    return describe_phys(phys, preferred_seg)


def bank_base(value: int, size: int) -> int:
    return ((((value & 0x0F) ^ 0x0F) << 17) % size)


def describe_bank(port: int, value: int, cpu: int | None) -> str:
    if not 0x10 <= port <= 0x17:
        raise ValueError("bank port must be in 0x10..0x17")
    window = port - 0x10
    window_start = window * BANK_WINDOW_SIZE
    window_end = window_start + BANK_WINDOW_SIZE - 1
    is_ram = bool(value & 0x18)
    size = RAM_SIZE if is_ram else ROM_SIZE
    bit3_ram = bool(value & 0x08) and not bool(value & 0x10)
    if bit3_ram:
        base = (window % (RAM_SIZE // BANK_WINDOW_SIZE)) * BANK_WINDOW_SIZE
    else:
        base = bank_base(value, size)
    source = "RAM" if is_ram else "ROM file"
    lines = [
        f"port 0x{port:02X} value 0x{value:02X}: CPU 0x{window_start:05X}..0x{window_end:05X}",
        f"  source: {source} base 0x{base:05X}",
    ]

    if cpu is not None:
        if not window_start <= cpu <= window_end:
            raise ValueError(
                f"CPU address 0x{cpu:x} is outside port 0x{port:02x} window "
                f"0x{window_start:x}..0x{window_end:x}"
            )
        mapped = base + (cpu - window_start)
        if is_ram:
            lines.append(f"  CPU 0x{cpu:05X} -> RAM offset 0x{mapped:05X}")
        else:
            lines.append(f"  CPU 0x{cpu:05X} -> file offset 0x{mapped:05X}")
    return "\n".join(lines)


def read_rom(path: Path) -> bytes:
    data = path.read_bytes()
    if len(data) != ROM_SIZE:
        raise SystemExit(f"{path}: expected 0x{ROM_SIZE:x} bytes, got 0x{len(data):x}")
    return data


def cmd_verify(args: argparse.Namespace) -> int:
    data = read_rom(args.rom)
    digest = hashlib.sha256(data).hexdigest()
    print(f"{args.rom}:")
    print(f"  size:   {len(data)} bytes")
    print(f"  sha256: {digest}")
    if digest != SHA256:
        print(f"  expected {SHA256}", file=sys.stderr)
        return 1
    return 0


def cmd_addr(args: argparse.Namespace) -> int:
    values = list(args.address)
    if args.stdin:
        values.extend(sys.stdin.read().split())

    if not values:
        print("no addresses supplied", file=sys.stderr)
        return 1

    try:
        preferred_seg = parse_addr_part(args.segment) if args.segment else None
    except ValueError as exc:
        print(f"--segment: {exc}", file=sys.stderr)
        return 1
    if preferred_seg is not None and not 0 <= preferred_seg <= 0xFFFF:
        print(f"--segment out of range: 0x{preferred_seg:x}", file=sys.stderr)
        return 1

    for value in values:
        try:
            label, phys = parse_addr_expr(value, preferred_seg)
            if preferred_seg is not None:
                phys_to_seg_off(phys, preferred_seg)
            print(format_addr_row(label, phys, args.format, preferred_seg))
        except ValueError as exc:
            print(f"{value}: {exc}", file=sys.stderr)
            return 1
    return 0


def cmd_bank(args: argparse.Namespace) -> int:
    try:
        port = parse_int(args.port)
        value = parse_int(args.value)
        cpu = parse_int(args.cpu) if args.cpu else None
        print(describe_bank(port, value, cpu))
    except ValueError as exc:
        print(exc, file=sys.stderr)
        return 1
    return 0


def iter_ascii_strings(data: bytes, minimum: int, start: int, end: int):
    run_start = None
    for offset in range(start, end):
        byte = data[offset]
        if byte in PRINTABLE and byte not in {0x0A, 0x0D, 0x09}:
            if run_start is None:
                run_start = offset
            continue
        if run_start is not None and offset - run_start >= minimum:
            yield run_start, data[run_start:offset].decode("ascii", errors="replace")
        run_start = None
    if run_start is not None and end - run_start >= minimum:
        yield run_start, data[run_start:end].decode("ascii", errors="replace")


def cmd_strings(args: argparse.Namespace) -> int:
    data = read_rom(args.rom)
    start = parse_int(args.start)
    end = parse_int(args.end) if args.end else len(data)
    if not 0 <= start <= end <= len(data):
        print("invalid start/end range", file=sys.stderr)
        return 1

    for offset, text in iter_ascii_strings(data, args.minimum, start, end):
        phys = file_to_phys(offset)
        display = text.replace("\\", "\\\\")
        print(f"file 0x{offset:05X}  phys 0x{phys:05X}  {c000_off(phys):10s}  {display}")
    return 0


def glyph_rows(data: bytes, offset: int, height: int) -> list[int]:
    end = offset + height
    if not 0 <= offset < end <= len(data):
        raise ValueError(f"glyph offset out of ROM range: 0x{offset:x}")
    return list(data[offset:end])


def render_glyph(rows: list[int], columns: int) -> list[str]:
    rendered = []
    for row in rows:
        bits = []
        for bit in range(columns):
            mask = 0x80 >> bit
            bits.append("#" if row & mask else ".")
        rendered.append("".join(bits))
    return rendered


def render_bitmap(
    data: bytes,
    offset: int,
    row_bytes: int,
    height: int,
    columns: int,
    invert: bool,
) -> list[str]:
    end = offset + row_bytes * height
    if not 0 <= offset < end <= len(data):
        raise ValueError(f"bitmap offset out of ROM range: 0x{offset:x}")

    rendered = []
    for row_index in range(height):
        row = data[offset + row_index * row_bytes : offset + (row_index + 1) * row_bytes]
        bits = []
        for bit_index in range(columns):
            byte = row[bit_index // 8]
            mask = 0x80 >> (bit_index % 8)
            set_bit = bool(byte & mask)
            if invert:
                set_bit = not set_bit
            bits.append("#" if set_bit else ".")
        rendered.append("".join(bits))
    return rendered


def cmd_glyphs(args: argparse.Namespace) -> int:
    data = read_rom(args.rom)
    if args.bold:
        base = BOLD_GLYPH_BASE
    elif args.small:
        base = SMALL_GLYPH_BASE
    elif args.small_bold:
        base = SMALL_BOLD_GLYPH_BASE
    elif args.narrow:
        base = NARROW_GLYPH_BASE
    elif args.narrow_bold:
        base = NARROW_BOLD_GLYPH_BASE
    elif args.narrow_small:
        base = NARROW_SMALL_GLYPH_BASE
    elif args.narrow_small_bold:
        base = NARROW_SMALL_BOLD_GLYPH_BASE
    elif args.sparse:
        base = SPARSE_GLYPH_BASE
    elif args.sparse_bold:
        base = SPARSE_BOLD_GLYPH_BASE
    elif args.sparse_small:
        base = SPARSE_SMALL_GLYPH_BASE
    elif args.sparse_small_bold:
        base = SPARSE_SMALL_BOLD_GLYPH_BASE
    else:
        base = parse_int(args.base)
    first_code = parse_int(args.first_code)
    width_table = parse_int(args.width_table) if args.width_table else None
    codes: list[int] = []
    if args.text is not None:
        codes.extend(ord(char) for char in args.text)
    if args.code:
        codes.extend(parse_int(code) for code in args.code)
    if not codes:
        codes = [first_code + index for index in range(args.count)]

    for code in codes:
        glyph_index = code - first_code
        if glyph_index < 0:
            print(f"code 0x{code:02X}: before first code 0x{first_code:02X}", file=sys.stderr)
            return 1
        offset = base + glyph_index * args.height
        try:
            rows = glyph_rows(data, offset, args.height)
        except ValueError as exc:
            print(exc, file=sys.stderr)
            return 1
        width_text = ""
        if width_table is not None:
            width_offset = width_table + glyph_index
            if 0 <= width_offset < len(data):
                width_text = f" width={data[width_offset]}"
        label = chr(code) if 0x20 <= code <= 0x7E else "."
        print(f"code 0x{code:02X} '{label}' index={glyph_index} file=0x{offset:05X}{width_text}")
        for line in render_glyph(rows, args.columns):
            print(f"  {line}")
    return 0


def cmd_bitmap(args: argparse.Namespace) -> int:
    data = read_rom(args.rom)
    base = parse_int(args.base)
    row_bytes = args.row_bytes
    height = args.height
    columns = args.columns or row_bytes * 8
    if row_bytes <= 0 or height <= 0 or not 0 < columns <= row_bytes * 8:
        print("invalid bitmap dimensions", file=sys.stderr)
        return 1
    stride = parse_int(args.stride) if args.stride else row_bytes * height

    for index in range(args.count):
        offset = base + index * stride
        try:
            lines = render_bitmap(data, offset, row_bytes, height, columns, args.invert)
        except ValueError as exc:
            print(exc, file=sys.stderr)
            return 1
        print(
            f"bitmap {index} file=0x{offset:05X} "
            f"{columns}x{height} row_bytes={row_bytes} stride=0x{stride:X}"
        )
        for line in lines:
            print(f"  {line}")
    return 0


def iter_bitmap_records(
    data: bytes,
    start: int,
    end: int,
    min_height: int,
    max_height: int,
    min_width: int,
    max_width: int,
    require_position: bool,
):
    for offset in range(start, max(start, end - 9)):
        if data[offset] != 0xFF or data[offset + 1] != 0x42:
            continue

        height = int.from_bytes(data[offset + 2 : offset + 4], "little")
        width = int.from_bytes(data[offset + 4 : offset + 6], "little")
        source_off = int.from_bytes(data[offset + 6 : offset + 8], "little")
        source_seg = int.from_bytes(data[offset + 8 : offset + 10], "little")
        if not (min_height <= height <= max_height and min_width <= width <= max_width):
            continue

        row_bytes = (width + 7) // 8
        if row_bytes <= 0:
            continue

        try:
            source_file = phys_to_file(seg_off_to_phys(source_seg, source_off))
        except ValueError:
            continue

        byte_count = row_bytes * height
        if source_file + byte_count > len(data):
            continue

        position = None
        if offset >= start + 6 and data[offset - 6] == 0xFF and data[offset - 5] == 0x40:
            x = int.from_bytes(data[offset - 4 : offset - 2], "little")
            y = int.from_bytes(data[offset - 2 : offset], "little")
            position = (x, y)
        elif require_position:
            continue

        yield {
            "record": offset,
            "height": height,
            "width": width,
            "row_bytes": row_bytes,
            "source_seg": source_seg,
            "source_off": source_off,
            "source_file": source_file,
            "byte_count": byte_count,
            "position": position,
        }


def cmd_bitmap_records(args: argparse.Namespace) -> int:
    data = read_rom(args.rom)
    start = parse_int(args.start)
    end = parse_int(args.end) if args.end else len(data)
    if not 0 <= start < end <= len(data):
        print("invalid start/end range", file=sys.stderr)
        return 1

    records = list(
        iter_bitmap_records(
            data,
            start,
            end,
            args.min_height,
            args.max_height,
            args.min_width,
            args.max_width,
            args.require_position,
        )
    )
    if args.limit:
        records = records[: args.limit]

    if args.format == "markdown":
        print("| Record | Position | Source | Size | Bytes | Bitmap command |")
        print("| ---: | --- | --- | --- | ---: | --- |")
        for record in records:
            position = ""
            if record["position"] is not None:
                x, y = record["position"]
                position = f"`{x},{y}`"
            command = (
                f"`tools/rom2.py bitmap --base 0x{record['source_file']:05x} "
                f"--row-bytes {record['row_bytes']} --height {record['height']} "
                f"--columns {record['width']}`"
            )
            print(
                f"| `0x{record['record']:05X}` | {position} | "
                f"`{record['source_seg']:04X}:{record['source_off']:04X}` / "
                f"`0x{record['source_file']:05X}` | "
                f"`{record['width']}x{record['height']}` | "
                f"`0x{record['byte_count']:X}` | {command} |"
            )
    else:
        for record in records:
            position = ""
            if record["position"] is not None:
                x, y = record["position"]
                position = f" pos={x},{y}"
            print(
                f"record=0x{record['record']:05X}{position} "
                f"source={record['source_seg']:04X}:{record['source_off']:04X} "
                f"file=0x{record['source_file']:05X} "
                f"size={record['width']}x{record['height']} "
                f"row_bytes={record['row_bytes']} bytes=0x{record['byte_count']:X}"
            )
            if args.commands:
                print(
                    f"  tools/rom2.py bitmap --base 0x{record['source_file']:05x} "
                    f"--row-bytes {record['row_bytes']} --height {record['height']} "
                    f"--columns {record['width']}"
                )
    return 0


def cmd_position_ops(args: argparse.Namespace) -> int:
    data = read_rom(args.rom)
    start = parse_int(args.start)
    end = parse_int(args.end) if args.end else len(data)
    if not 0 <= start < end <= len(data):
        print("invalid start/end range", file=sys.stderr)
        return 1

    count = 0
    for offset in range(start, end - 8):
        if data[offset] != 0xFF or data[offset + 1] != 0x40:
            continue

        next_offset = data.find(b"\xFF", offset + 6, min(end, offset + 6 + args.max_gap + 1))
        if next_offset == -1 or next_offset + 1 >= end:
            continue

        opcode = data[next_offset + 1]
        if not args.min_opcode <= opcode <= args.max_opcode:
            continue

        x = int.from_bytes(data[offset + 2 : offset + 4], "little")
        y = int.from_bytes(data[offset + 4 : offset + 6], "little")
        between = data[offset + 6 : next_offset]
        text = ""
        if between:
            text = between.decode("ascii", errors="replace")
            text = "".join(char if 0x20 <= ord(char) < 0x7F else "." for char in text)

        print(
            f"pos=0x{offset:05X} {x},{y} next=0x{next_offset:05X} "
            f"op=FF {opcode:02X} gap={len(between)}",
            end="",
        )
        if text:
            print(f" text={text!r}")
        else:
            print()

        count += 1
        if args.limit and count >= args.limit:
            break
    return 0


def cmd_disasm(args: argparse.Namespace) -> int:
    data = read_rom(args.rom)
    starts = list(args.start)
    if args.stdin:
        starts.extend(sys.stdin.read().split())

    if not starts:
        print("no start addresses supplied", file=sys.stderr)
        return 1

    if args.count <= 0:
        print("count must be greater than zero", file=sys.stderr)
        return 1

    default_seg = parse_addr_part(args.segment) if args.segment else None
    try:
        bank_base = parse_file_base(args.bank_base) if args.bank_base else None
    except ValueError as exc:
        print(exc, file=sys.stderr)
        return 1

    for start_expr in starts:
        preferred: tuple[int, int] | None
        if bank_base is None:
            try:
                label, phys = parse_addr_expr(start_expr, default_seg)
            except ValueError as exc:
                print(f"{start_expr}: {exc}", file=sys.stderr)
                return 1

            preferred = parse_seg_off_label(label)
            if preferred is None and default_seg is not None:
                try:
                    preferred = (default_seg, phys_to_seg_off(phys, default_seg))
                except ValueError as exc:
                    print(f"{start_expr}: {exc}", file=sys.stderr)
                    return 1
            start = phys_to_file(phys)
        else:
            preferred = None
            if ":" in start_expr and not start_expr.lower().startswith(("file:", "phys:")):
                seg_text, off_text = start_expr.split(":", 1)
                seg = parse_addr_part(seg_text)
                off = parse_addr_part(off_text)
                preferred = (seg, off)
                label = f"{seg:04X}:{off:04X}"
                start = bank_base + off
            elif start_expr.lower().startswith("phys:"):
                print(f"{start_expr}: --bank-base does not support phys: starts", file=sys.stderr)
                return 1
            elif start_expr.lower().startswith("file:"):
                try:
                    start = parse_file_base(start_expr)
                except ValueError as exc:
                    print(f"{start_expr}: {exc}", file=sys.stderr)
                    return 1
                off = start - bank_base
                label = f"file:0x{start:X}"
                if default_seg is not None and 0 <= off <= 0xFFFF:
                    preferred = (default_seg, off)
            else:
                if default_seg is None:
                    print(
                        f"{start_expr}: --bank-base requires segment:offset input or --segment",
                        file=sys.stderr,
                    )
                    return 1
                off = parse_int(start_expr)
                if not 0 <= off <= 0xFFFF:
                    print(
                        f"{start_expr}: segment offset out of range for {default_seg:04X}: 0x{off:x}",
                        file=sys.stderr,
                    )
                    return 1
                preferred = (default_seg, off)
                label = f"{default_seg:04X}:{off:04X}"
                start = bank_base + off
            if not 0 <= start < len(data):
                print(f"{label}: banked range starts outside ROM image", file=sys.stderr)
                return 1
            phys = file_to_phys(start)

        if args.origin == "phys" or (args.origin == "auto" and preferred is None):
            origin = phys
            origin_label = "phys"
        else:
            if preferred is None:
                print(
                    f"{start_expr}: --origin offset requires segment:offset input or --segment",
                    file=sys.stderr,
                )
                return 1
            origin = preferred[1]
            origin_label = f"{preferred[0]:04X} offset"

        start = phys_to_file(phys)
        end = min(start + args.count, len(data))
        if start >= end:
            print(f"{label}: invalid range in ROM image", file=sys.stderr)
            return 1

        command = ["ndisasm", "-b", "16", "-o", f"0x{origin:05X}", "-"]
        try:
            result = subprocess.run(
                command,
                check=True,
                input=data[start:end],
                capture_output=True,
            )
        except FileNotFoundError:
            print("ndisasm is required for disasm", file=sys.stderr)
            return 1
        except subprocess.CalledProcessError as exc:
            print(exc.stderr.decode("utf-8", errors="replace"), file=sys.stderr)
            return 1

        preferred_text = ""
        if preferred is not None and label.lower().startswith(("file:", "phys:")):
            preferred_text = f"  {preferred[0]:04X}:{preferred[1]:04X}"
        disassembly = result.stdout.decode("utf-8", errors="replace")
        display_segment = preferred[0] if preferred is not None and origin == preferred[1] else None
        disassembly = format_ndisasm_output(disassembly, display_segment)

        print(
            f"; {label}{preferred_text}  file 0x{start:05X} phys 0x{phys:05X} "
            f"origin={origin_label} 0x{origin:05X} len=0x{end-start:X}"
        )
        print(disassembly, end="")
        if args.count_output:
            print()
            print()
        else:
            print()
    return 0


def cmd_xref_scan(args: argparse.Namespace) -> int:
    files = expand_markdown_inputs(args.scope)
    if not files:
        print("no markdown files matched", file=sys.stderr)
        return 1

    if not args.include_readme:
        files = [path for path in files if path.name.lower() != "readme.md"]

    todo_rows: list[tuple[str, int, str]] = []
    unresolved: list[tuple[str, int, str]] = []

    for path in files:
        for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if not TODO_XREF_RE.search(line):
                continue
            tokens = extract_address_tokens(line)
            if not tokens:
                unresolved.append((str(path), line_no, line.strip()))
                continue
            for token in tokens:
                try:
                    canonical, phys = parse_addr_expr(token)
                except ValueError:
                    unresolved.append((str(path), line_no, f"{line.strip()} [unparseable token={token}]" ))
                    continue
                todo_rows.append((str(path), line_no, f"{canonical} -> 0x{phys:05X}" ))

    if args.format == "markdown":
        print("| File | Line | TODO-xref |")
        print("| --- | ---: | --- |")
        for path, line_no, row in todo_rows:
            print(f"| {path} | {line_no} | `{row}` |")
        for path, line_no, row in unresolved:
            print(f"| {path} | {line_no} | unresolved | `{row}` |", file=sys.stderr)
        if unresolved:
            print(f"unresolved: {len(unresolved)}", file=sys.stderr)
    else:
        for path, line_no, row in todo_rows:
            print(f"{path}:{line_no}: {row}")
        if unresolved:
            for path, line_no, row in unresolved:
                print(f"{path}:{line_no}: TODO-xref unresolved: {row}", file=sys.stderr)
            print(f"unresolved: {len(unresolved)}", file=sys.stderr)
    if unresolved:
        return 1
    return 0


def cmd_queue_audit(args: argparse.Namespace) -> int:
    queue_path = Path(args.queue)
    queue_lines = queue_path.read_text(encoding="utf-8").splitlines()

    queue_rows: list[tuple[str, str, str]] = []
    in_queue_section = False
    for line in queue_lines:
        if line.strip().startswith("## Root Expansion Queue"):
            in_queue_section = True
            continue
        if not in_queue_section:
            continue
        if not line.startswith("|"):
            if queue_rows:
                break
            continue
        if line.startswith("| Root |") or line.startswith("| ---"):
            continue

        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) >= 1:
            root_cell = cells[0].strip("`")
            source = cells[1].strip("`") if len(cells) > 1 else ""
            next_slice = cells[2].strip("`") if len(cells) > 2 else ""
            if root_cell:
                queue_rows.append((root_cell, source, next_slice))

    if not queue_rows:
        if args.format == "markdown":
            print("| Root | Source | Next Slice | Status |")
            print("| --- | --- | --- | --- |")
        if not args.open_only:
            print("summary: open=0 seen=0 named=0 invalid=0")
        return 0

    scope_files = expand_markdown_inputs(args.scope_docs)
    discovered: set[int] = set()
    for path in scope_files:
        if path.resolve() == queue_path.resolve():
            continue
        for token in extract_address_tokens(path.read_text(encoding="utf-8")):
            try:
                _, phys = parse_addr_expr(token)
            except ValueError:
                continue
            discovered.add(phys)

    entries: list[tuple[str, str, str, str]] = []
    for root_cell, source, next_slice in queue_rows:
        tokens = extract_address_tokens(root_cell)
        if not tokens:
            entries.append((root_cell, source, "named", next_slice))
            continue
        for token in tokens:
            try:
                canonical, phys = parse_addr_expr(token)
            except ValueError:
                entries.append((token, "invalid", token, next_slice))
                continue
            status = "open" if phys not in discovered else "seen"
            if args.open_only and status == "seen":
                continue
            entries.append((canonical, status, source, next_slice))

    if args.format == "markdown":
        print("| Root | Source | Next Slice | Status |")
        print("| --- | --- | --- | --- |")
        for root, source, status, next_slice in entries:
            print(f"| `{root}` | `{source}` | `{next_slice}` | `{status}` |")
    else:
        for root, source, status, next_slice in entries:
            print(f"{root:20}  status={status:5}  source={source}  next={next_slice}")

    if not args.open_only:
        open_count = len([_ for _ in entries if _[1] == "open"])
        seen_count = len([_ for _ in entries if _[1] == "seen"])
        named_count = len([_ for _ in entries if _[1] == "named"])
        invalid_count = len([_ for _ in entries if _[1] == "invalid"])
        print(f"summary: open={open_count} seen={seen_count} named={named_count} invalid={invalid_count}")
    return 0


XREF_RE = re.compile(
    r"^(?P<addr>[0-9A-Fa-f]+)\s+\S+\s+"
    r"(?P<op>call|jmp|jz|jnz|jc|jnc|ja|jae|jb|jbe|jg|jge|jl|jle|jo|jno|js|jns|loop|loopz|loopnz)\b"
    r"(?:\s+(?:short\s+|near\s+|far\s+)?(?P<target>[^;\s]+))?"
)

IO_LINE_RE = re.compile(r"^(?P<addr>[0-9A-Fa-f]+)\s+\S+\s+(?P<instr>.*)$")
DIRECT_IO_RE = re.compile(
    r"\b(?:in\s+(?:al|ax),0x(?P<inport>[0-9a-f]+)|out\s+0x(?P<outport>[0-9a-f]+),(?:al|ax))\b",
    re.IGNORECASE,
)


def parse_type_filter(value: str) -> set[str]:
    return {item.strip() for item in value.split(",") if item.strip()}


def read_regions(path: Path) -> list[dict[str, str | int]]:
    regions: list[dict[str, str | int]] = []
    previous_end = 0
    for lineno, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        columns = raw_line.split("\t")
        if columns[:7] == ["start", "end", "type", "confidence", "segment", "label", "notes"]:
            continue
        if len(columns) != 7:
            raise ValueError(f"{path}:{lineno}: expected 7 tab-separated columns")
        start_text, end_text, kind, confidence, segment, label, notes = columns
        start = parse_int(start_text)
        end = parse_int(end_text)
        if not 0 <= start < end <= ROM_SIZE:
            raise ValueError(f"{path}:{lineno}: invalid region range 0x{start:x}..0x{end:x}")
        if start < previous_end:
            raise ValueError(
                f"{path}:{lineno}: region overlaps or is out of order after 0x{previous_end:x}"
            )
        previous_end = end
        regions.append(
            {
                "start": start,
                "end": end,
                "type": kind,
                "confidence": confidence,
                "segment": segment,
                "label": label,
                "notes": notes,
            }
        )
    return regions


def format_region(region: dict[str, str | int]) -> str:
    start = int(region["start"])
    end = int(region["end"])
    cpu_start = region_origin(region)
    cpu_end = cpu_start + (end - start)
    return (
        f"0x{start:05X}..0x{end:05X} cpu=0x{cpu_start:05X}..0x{cpu_end:05X} "
        f"type={region['type']} confidence={region['confidence']} "
        f"segment={region['segment']} label={region['label']} {region['notes']}"
    )


def cmd_regions(args: argparse.Namespace) -> int:
    try:
        regions = read_regions(args.regions)
    except ValueError as exc:
        print(exc, file=sys.stderr)
        return 1

    type_filter = parse_type_filter(args.types) if args.types else None
    rows = [
        region
        for region in regions
        if type_filter is None or str(region["type"]) in type_filter
    ]

    if args.format == "markdown":
        print("| File range | CPU range | Type | Confidence | Segment | Label | Notes |")
        print("| --- | --- | --- | --- | --- | --- | --- |")
        for region in rows:
            start = int(region["start"])
            end = int(region["end"])
            cpu_start = region_origin(region)
            cpu_end = cpu_start + (end - start)
            print(
                f"| `0x{start:05X}..0x{end:05X}` | "
                f"`0x{cpu_start:05X}..0x{cpu_end:05X}` | "
                f"`{region['type']}` | `{region['confidence']}` | "
                f"`{region['segment']}` | `{region['label']}` | {region['notes']} |"
            )
    else:
        for region in rows:
            print(format_region(region))
    return 0


def region_origin(region: dict[str, str | int]) -> int:
    start = int(region["start"])
    segment = str(region["segment"])
    if not segment:
        return file_to_phys(start)
    seg_base = parse_addr_part(segment) << 4
    try:
        base_file = phys_to_file(seg_base)
    except ValueError:
        base_file = seg_base if 0 <= seg_base < ROM_SIZE else start
    return seg_base + (start - base_file)


def disassemble_region(data: bytes, region: dict[str, str | int]) -> tuple[int, str]:
    start = int(region["start"])
    end = int(region["end"])
    origin = region_origin(region)
    command = [
        "ndisasm",
        "-b",
        "16",
        "-o",
        f"0x{origin:x}",
        "-",
    ]
    result = subprocess.run(
        command,
        check=True,
        input=data[start:end],
        capture_output=True,
    )
    return origin, result.stdout.decode("utf-8", errors="replace")


def cmd_io_scan(args: argparse.Namespace) -> int:
    data = read_rom(args.rom)
    try:
        regions = read_regions(args.regions)
    except ValueError as exc:
        print(exc, file=sys.stderr)
        return 1

    type_filter = parse_type_filter(args.types)
    rows: list[dict[str, str | int | None]] = []
    counts: dict[str, int] = {}
    try:
        for region in regions:
            if str(region["type"]) not in type_filter:
                continue
            start = int(region["start"])
            origin, disassembly = disassemble_region(data, region)
            for line in disassembly.splitlines():
                match = IO_LINE_RE.match(line)
                if not match:
                    continue
                instr = match.group("instr").strip()
                mnemonic = instr.split(None, 1)[0] if instr else ""
                if mnemonic not in {"in", "out", "insb", "insw", "outsb", "outsw"}:
                    continue
                address = int(match.group("addr"), 16)
                file_offset = start + (address - origin)
                if not start <= file_offset < int(region["end"]):
                    file_offset = None
                port_match = DIRECT_IO_RE.search(instr)
                port = None
                if port_match:
                    port_text = port_match.group("inport") or port_match.group("outport")
                    port = int(port_text, 16)
                port_key = f"0x{port:02X}" if port is not None else "DX/string"
                counts[port_key] = counts.get(port_key, 0) + 1
                rows.append(
                    {
                        "file": file_offset,
                        "cpu": address,
                        "region": region["label"],
                        "type": region["type"],
                        "port": port,
                        "instr": instr,
                    }
                )
    except FileNotFoundError:
        print("ndisasm is required for io-scan", file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as exc:
        print(exc.stderr.decode("utf-8", errors="replace"), file=sys.stderr)
        return exc.returncode

    if args.summary:
        for port_key, count in sorted(counts.items(), key=lambda item: (item[0] == "DX/string", item[0])):
            print(f"{port_key}: {count}")
        return 0

    if args.limit:
        rows = rows[: args.limit]

    if args.format == "markdown":
        print("| File | CPU | Region | Port | Instruction |")
        print("| ---: | ---: | --- | ---: | --- |")
        for row in rows:
            file_text = "" if row["file"] is None else f"`0x{int(row['file']):05X}`"
            port_text = "`DX/string`" if row["port"] is None else f"`0x{int(row['port']):02X}`"
            print(
                f"| {file_text} | `0x{int(row['cpu']):05X}` | "
                f"`{row['region']}` | {port_text} | `{row['instr']}` |"
            )
    else:
        for row in rows:
            file_text = "unknown" if row["file"] is None else f"0x{int(row['file']):05X}"
            port_text = "DX/string" if row["port"] is None else f"0x{int(row['port']):02X}"
            print(
                f"file={file_text} cpu=0x{int(row['cpu']):05X} "
                f"region={row['region']} port={port_text} {row['instr']}"
            )
    return 0


def resolve_target(target: str, near_seg: int) -> tuple[str, int | None]:
    target = target.lower()
    if target.startswith("[") or not target:
        return target, None
    if ":" in target:
        seg_text, off_text = target.split(":", 1)
        try:
            phys = seg_off_to_phys(parse_addr_part(seg_text), parse_addr_part(off_text))
        except ValueError:
            return target, None
        return f"{parse_addr_part(seg_text):04X}:{parse_addr_part(off_text):04X}", phys
    try:
        off = parse_int(target)
    except ValueError:
        return target, None
    try:
        phys = seg_off_to_phys(near_seg, off)
    except ValueError:
        return target, None
    return f"{near_seg:04X}:{off:04X}", phys


def cmd_xrefs(args: argparse.Namespace) -> int:
    data = read_rom(args.rom)
    start = parse_int(args.start)
    end = parse_int(args.end)
    if not 0 <= start < end <= len(data):
        print("invalid start/end range", file=sys.stderr)
        return 1

    origin = file_to_phys(start)
    command = [
        "ndisasm",
        "-b",
        "16",
        "-o",
        f"0x{origin:x}",
        "-",
    ]
    try:
        result = subprocess.run(
            command,
            check=True,
            input=data[start:end],
            capture_output=True,
        )
    except FileNotFoundError:
        print("ndisasm is required for xrefs", file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as exc:
        print(exc.stderr.decode("utf-8", errors="replace"), file=sys.stderr)
        return exc.returncode

    near_seg = args.near_seg
    target_counts: dict[str, tuple[int, int | None, set[str]]] = {}
    rows: list[tuple[int, str, str, int | None, str]] = []
    disassembly = result.stdout.decode("utf-8", errors="replace")
    for line in disassembly.splitlines():
        match = XREF_RE.match(line)
        if not match:
            continue
        op = match.group("op")
        target = match.group("target") or ""
        address = int(match.group("addr"), 16)
        label, phys = resolve_target(target, near_seg)
        rows.append((address, op, label, phys, line))
        count, _, ops = target_counts.get(label, (0, phys, set()))
        ops.add(op)
        target_counts[label] = (count + 1, phys, ops)

    if args.format == "markdown":
        print("| Count | Target | File | Ops |")
        print("| ---: | --- | ---: | --- |")
        for label, (count, phys, ops) in sorted(
            target_counts.items(), key=lambda item: (-item[1][0], item[0])
        )[: args.limit]:
            file_text = f"`0x{phys_to_file(phys):05X}`" if phys is not None else ""
            print(f"| {count} | `{label}` | {file_text} | `{','.join(sorted(ops))}` |")
    else:
        for address, op, label, phys, _line in rows[: args.limit]:
            file_text = f" file 0x{phys_to_file(phys):05X}" if phys is not None else ""
            print(f"{address:05X}: {op:5s} {label}{file_text}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rom", type=Path, default=ROM_PATH)
    subparsers = parser.add_subparsers(dest="command", required=True)

    verify = subparsers.add_parser("verify", help="check ROM size and SHA-256")
    verify.set_defaults(func=cmd_verify)

    addr = subparsers.add_parser("addr", help="convert file/physical/segment addresses")
    addr.add_argument(
        "address",
        nargs="+",
        help="file:0x46912, phys:0xc6912, c688:0053, or a number",
    )
    addr.add_argument(
        "--format",
        choices=("text", "compact", "tsv"),
        default="text",
        help="output format",
    )
    addr.add_argument(
        "--segment",
        help="parse bare values as offsets in this segment and require all inputs to fit it",
    )
    addr.add_argument("--stdin", action="store_true", help="read extra addresses from stdin")
    addr.set_defaults(func=cmd_addr)

    bank = subparsers.add_parser("bank", help="describe a MAME bank port/value mapping")
    bank.add_argument("port", help="bank select port 0x10..0x17")
    bank.add_argument("value", help="value written to the bank select port")
    bank.add_argument("--cpu", help="optional CPU physical address to map through this bank")
    bank.set_defaults(func=cmd_bank)

    strings_parser = subparsers.add_parser("strings", help="list printable ASCII strings")
    strings_parser.add_argument("-n", "--minimum", type=int, default=8)
    strings_parser.add_argument("--start", default="0")
    strings_parser.add_argument("--end")
    strings_parser.set_defaults(func=cmd_strings)

    glyphs = subparsers.add_parser("glyphs", help="render fixed-height 1bpp glyphs")
    glyphs.add_argument("--base", default=f"0x{MAIN_GLYPH_BASE:x}", help="file offset of glyph 0/first-code")
    font_base = glyphs.add_mutually_exclusive_group()
    font_base.add_argument("--bold", action="store_true", help=f"use bold glyph base 0x{BOLD_GLYPH_BASE:05X}")
    font_base.add_argument("--small", action="store_true", help=f"use small/down-shifted glyph base 0x{SMALL_GLYPH_BASE:05X}")
    font_base.add_argument(
        "--small-bold",
        action="store_true",
        help=f"use small bold/down-shifted glyph base 0x{SMALL_BOLD_GLYPH_BASE:05X}",
    )
    font_base.add_argument("--narrow", action="store_true", help=f"use narrow glyph base 0x{NARROW_GLYPH_BASE:05X}")
    font_base.add_argument(
        "--narrow-bold",
        action="store_true",
        help=f"use narrow bold glyph base 0x{NARROW_BOLD_GLYPH_BASE:05X}",
    )
    font_base.add_argument(
        "--narrow-small",
        action="store_true",
        help=f"use narrow small/down-shifted glyph base 0x{NARROW_SMALL_GLYPH_BASE:05X}",
    )
    font_base.add_argument(
        "--narrow-small-bold",
        "--narrow-bold-small",
        action="store_true",
        dest="narrow_small_bold",
        help=f"use narrow small bold/down-shifted glyph base 0x{NARROW_SMALL_BOLD_GLYPH_BASE:05X}",
    )
    font_base.add_argument("--sparse", action="store_true", help=f"use sparse/remapped glyph base 0x{SPARSE_GLYPH_BASE:05X}")
    font_base.add_argument(
        "--sparse-bold",
        action="store_true",
        help=f"use sparse/remapped bold glyph base 0x{SPARSE_BOLD_GLYPH_BASE:05X}",
    )
    font_base.add_argument(
        "--sparse-small",
        action="store_true",
        help=f"use sparse/remapped small glyph base 0x{SPARSE_SMALL_GLYPH_BASE:05X}",
    )
    font_base.add_argument(
        "--sparse-small-bold",
        "--sparse-bold-small",
        action="store_true",
        dest="sparse_small_bold",
        help=f"use sparse/remapped small bold glyph base 0x{SPARSE_SMALL_BOLD_GLYPH_BASE:05X}",
    )
    glyphs.add_argument("--first-code", default="0x20", help="character code for first glyph")
    glyphs.add_argument("--height", type=int, default=8)
    glyphs.add_argument("--columns", type=int, default=8)
    glyphs.add_argument("--width-table", default="0x58000", help="optional file offset of width/metadata table")
    glyphs.add_argument("--count", type=int, default=16, help="default glyph count when no text/code is given")
    glyphs.add_argument("--text", help="render glyphs for this text")
    glyphs.add_argument("--code", action="append", help="render a specific code; may be repeated")
    glyphs.set_defaults(func=cmd_glyphs)

    bitmap = subparsers.add_parser("bitmap", help="render fixed-size 1bpp bitmap blocks")
    bitmap.add_argument("--base", required=True, help="file offset of the first bitmap block")
    bitmap.add_argument("--row-bytes", type=int, default=6, help="bytes per bitmap row")
    bitmap.add_argument("--height", type=int, default=40, help="bitmap height in rows")
    bitmap.add_argument("--columns", type=int, help="visible columns; defaults to row-bytes * 8")
    bitmap.add_argument("--count", type=int, default=1, help="number of sequential bitmap blocks to render")
    bitmap.add_argument("--stride", help="bytes between bitmap blocks; defaults to row-bytes * height")
    bitmap.add_argument("--invert", action="store_true", help="render zero bits as set pixels")
    bitmap.set_defaults(func=cmd_bitmap)

    bitmap_records = subparsers.add_parser(
        "bitmap-records",
        help="scan for plausible FF 42 bitmap resource records",
    )
    bitmap_records.add_argument("--start", default="0", help="file offset to start scanning")
    bitmap_records.add_argument("--end", help="file offset to stop scanning; defaults to ROM end")
    bitmap_records.add_argument("--min-height", type=int, default=1)
    bitmap_records.add_argument("--max-height", type=int, default=64)
    bitmap_records.add_argument("--min-width", type=int, default=1)
    bitmap_records.add_argument("--max-width", type=int, default=480)
    bitmap_records.add_argument("--limit", type=int, default=0, help="maximum records to print; 0 means all")
    bitmap_records.add_argument(
        "--require-position",
        action="store_true",
        help="only include FF 42 records immediately preceded by an FF 40 position record",
    )
    bitmap_records.add_argument("--commands", action="store_true", help="also print matching bitmap render commands")
    bitmap_records.add_argument("--format", choices=("text", "markdown"), default="text")
    bitmap_records.set_defaults(func=cmd_bitmap_records)

    position_ops = subparsers.add_parser(
        "position-ops",
        help="find FF 40 position records followed by another resource opcode",
    )
    position_ops.add_argument("--start", default="0", help="file offset to start scanning")
    position_ops.add_argument("--end", help="file offset to stop scanning; defaults to ROM end")
    position_ops.add_argument("--max-gap", type=int, default=80, help="maximum bytes after FF 40 to search")
    position_ops.add_argument("--min-opcode", type=lambda value: parse_int(value), default=0x40)
    position_ops.add_argument("--max-opcode", type=lambda value: parse_int(value), default=0x4F)
    position_ops.add_argument("--limit", type=int, default=0, help="maximum records to print; 0 means all")
    position_ops.set_defaults(func=cmd_position_ops)

    disasm = subparsers.add_parser(
        "disasm",
        help="disassemble a byte window from a segment:offset, file, or physical address",
    )
    disasm.add_argument(
        "start",
        nargs="+",
        help="start address as file:, phys:, segment:off, or a raw value",
    )
    disasm.add_argument("--count", type=parse_int, default=0x400, help="number of bytes to decode")
    disasm.add_argument(
        "--segment",
        help=(
            "parse bare values as offsets in this segment; also supplies the "
            "segment for --origin offset"
        ),
    )
    disasm.add_argument(
        "--bank-base",
        help=(
            "file offset mapped to segment offset 0000 for banked code, such as "
            "file:0x30000 for the linguistic 3000: window"
        ),
    )
    disasm.add_argument(
        "--origin",
        choices=("auto", "phys", "offset"),
        default="auto",
        help=(
            "address origin passed to ndisasm; auto uses segment offsets for "
            "segment inputs and physical addresses otherwise"
        ),
    )
    disasm.add_argument("--stdin", action="store_true", help="read extra start addresses from stdin")
    disasm.add_argument(
        "--count-output",
        action="store_true",
        help="emit an extra blank line after each decode block",
    )
    disasm.set_defaults(func=cmd_disasm)

    xref_scan = subparsers.add_parser(
        "xref-scan",
        help="scan markdown docs for TODO-xref address markers",
    )
    xref_scan.add_argument(
        "scope",
        nargs="*",
        default=["docs/disassembly/*.md"],
        help="markdown files, globs, or directories to scan",
    )
    xref_scan.add_argument(
        "--include-readme",
        action="store_true",
        help="include README.md files in the scan",
    )
    xref_scan.add_argument("--format", choices=("text", "markdown"), default="text")
    xref_scan.set_defaults(func=cmd_xref_scan)

    queue_audit = subparsers.add_parser(
        "queue-audit",
        help="report Root Expansion Queue coverage and open vs seen roots",
    )
    queue_audit.add_argument(
        "--queue",
        default="docs/disassembly/README.md",
        help="path to the root queue file",
    )
    queue_audit.add_argument(
        "--scope-docs",
        nargs="*",
        default=["docs/disassembly/*.md"],
        help="markdown files that define already-implemented roots",
    )
    queue_audit.add_argument(
        "--open-only",
        action="store_true",
        help="show only queue entries not found in other docs",
    )
    queue_audit.add_argument("--format", choices=("text", "markdown"), default="text")
    queue_audit.set_defaults(func=cmd_queue_audit)

    xrefs = subparsers.add_parser("xrefs", help="linear direct branch/call inventory using ndisasm")
    xrefs.add_argument("--start", default="0x40000")
    xrefs.add_argument("--end", default="0x50000")
    xrefs.add_argument("--near-seg", type=lambda value: parse_addr_part(value), default=0xC000)
    xrefs.add_argument("--limit", type=int, default=40)
    xrefs.add_argument("--format", choices=("text", "markdown"), default="text")
    xrefs.set_defaults(func=cmd_xrefs)

    regions = subparsers.add_parser("regions", help="list ROM map regions")
    regions.add_argument("--regions", type=Path, default=REGION_MAP_PATH, help="TSV region map path")
    regions.add_argument("--types", help="comma-separated region types to include")
    regions.add_argument("--format", choices=("text", "markdown"), default="text")
    regions.set_defaults(func=cmd_regions)

    io_scan = subparsers.add_parser("io-scan", help="scan mapped ROM regions for x86 in/out instructions")
    io_scan.add_argument("--regions", type=Path, default=REGION_MAP_PATH, help="TSV region map path")
    io_scan.add_argument(
        "--types",
        default="code,monitor-code",
        help="comma-separated region types to disassemble and scan",
    )
    io_scan.add_argument("--summary", action="store_true", help="summarize hits by direct port")
    io_scan.add_argument("--limit", type=int, default=0, help="maximum rows to print; 0 means all")
    io_scan.add_argument("--format", choices=("text", "markdown"), default="text")
    io_scan.set_defaults(func=cmd_io_scan)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
