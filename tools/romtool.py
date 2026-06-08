#!/usr/bin/env python3
"""Data inspection tools for the DreamWriter T400 ROM images.

Usage:
  romtool.py dump <offset> [len]        Hex+ASCII dump at file offset
  romtool.py seg <seg:off> [len]        Hex+ASCII dump at segment:offset
  romtool.py words <offset> [count]     Read 16-bit word table at file offset
  romtool.py segwords <seg:off> [count] Read 16-bit word table at segment:offset
  romtool.py strings <offset> [len]     Show printable strings at file offset
  romtool.py find <hex|ascii> [--from X] [--to Y]  Search ROM for pattern
  romtool.py addr <seg:off>             Convert segment:offset to file offset
  romtool.py seg2file <seg:off>         Alias for addr
  romtool.py file2seg <offset>          Show all known segment:offset for file offset
  romtool.py disasm <offset> [count]    Disassemble with ndisasm at file offset
  romtool.py segdisasm <seg:off> [cnt]  Disassemble at segment:offset

All offsets accept hex (0x prefix or plain hex) or decimal.
Default ROM is v3.1; pass --v21 for v2.1.
"""

from __future__ import annotations

import argparse
import re
import struct
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_DIR = SCRIPT_DIR.parent

ROMS = {
    "v31": {
        "path": REPO_DIR / "v3.1" / "t4_ir_3.1_e588.ic303",
        "size": 0x100000,
        "segments": {
            "C000": (0xC0000, 0x10000),
            "C772": (0xC7720, 0x10000),
            "DEF0": (0xDEF00, 0x10000),
            "EE17": (0xEE170, 0x10000),
            "EF8A": (0xEF8A0, 0x10000),
            "ED1B": (0xED1B0, 0x10000),
            "AD00": (0xAD000, 0x10000),
            "3000": (0x80000, 0x10000),  # banked
            "6000": (0x80000, 0x20000),  # banked window 3
            "8000": (0xA0000, 0x20000),  # banked window 4
        },
    },
    "v21": {
        "path": REPO_DIR / "v2.1" / "t4_ir_2.1.ic303",
        "size": 0x80000,
        "segments": {
            "C000": (0x40000, 0x10000),
            "C688": (0x46880, 0x10000),
            "DC98": (0x5C980, 0x10000),
        },
    },
}


def parse_int(s: str) -> int:
    s = s.strip().rstrip("hH")
    if s.startswith("0x") or s.startswith("0X"):
        return int(s, 16)
    if re.match(r"^[0-9a-fA-F]+$", s) and any(c in "abcdefABCDEF" for c in s):
        return int(s, 16)
    return int(s, 0)


def parse_segoff(s: str) -> tuple[int, int]:
    m = re.match(r"([0-9a-fA-F]{3,4}):([0-9a-fA-F]{1,4})$", s)
    if not m:
        raise ValueError(f"Bad segment:offset format: {s!r} (expected e.g. C000:1234)")
    return int(m.group(1), 16), int(m.group(2), 16)


def seg_to_file(seg: int, off: int, rom_info: dict) -> int | None:
    seg_name = f"{seg:04X}"
    if seg_name in rom_info["segments"]:
        file_base, _ = rom_info["segments"][seg_name]
        return file_base + off
    # fall back to physical address within ROM
    phys = (seg << 4) + off
    # check all known bank mappings
    for name, (file_base, max_size) in rom_info["segments"].items():
        seg_val = int(name, 16)
        seg_phys = seg_val << 4
        if phys >= seg_phys and phys < seg_phys + max_size:
            return file_base + (phys - seg_phys)
    return None


def file_to_segs(offset: int, rom_info: dict) -> list[tuple[str, int]]:
    results = []
    for name, (file_base, max_size) in rom_info["segments"].items():
        if file_base <= offset < file_base + max_size:
            off = offset - file_base
            if off < 0x10000:
                results.append((name, off))
    return results


def load_rom(rom_info: dict) -> bytes:
    path = rom_info["path"]
    if not path.exists():
        sys.exit(f"ROM not found: {path}")
    return path.read_bytes()


def hex_dump(data: bytes, base_offset: int, seg_label: str | None = None):
    for i in range(0, len(data), 16):
        chunk = data[i : i + 16]
        hex_part = " ".join(f"{b:02X}" for b in chunk)
        ascii_part = "".join(chr(b) if 32 <= b < 127 else "." for b in chunk)
        addr = base_offset + i
        if seg_label:
            seg_val = int(seg_label, 16)
            seg_off = addr - (seg_val << 4) if addr >= (seg_val << 4) else addr
            label = f"{seg_label}:{seg_off:04X}"
        else:
            label = f"{addr:05X}"
        print(f"  {label}: {hex_part:<48s}  {ascii_part}")


def cmd_dump(rom: bytes, args, rom_info: dict):
    offset = parse_int(args.offset)
    length = parse_int(args.length) if args.length else 256
    hex_dump(rom[offset : offset + length], offset)


def cmd_seg(rom: bytes, args, rom_info: dict):
    seg, off = parse_segoff(args.segoff)
    file_off = seg_to_file(seg, off, rom_info)
    if file_off is None:
        sys.exit(f"Cannot resolve {seg:04X}:{off:04X} to file offset")
    length = parse_int(args.length) if args.length else 256
    print(f"  {seg:04X}:{off:04X} = file 0x{file_off:05X}")
    hex_dump(rom[file_off : file_off + length], file_off, f"{seg:04X}")


def cmd_words(rom: bytes, args, rom_info: dict):
    offset = parse_int(args.offset)
    count = parse_int(args.count) if args.count else 16
    for i in range(count):
        pos = offset + i * 2
        if pos + 2 > len(rom):
            break
        val = struct.unpack_from("<H", rom, pos)[0]
        segs = file_to_segs(offset, rom_info)
        label = f"{pos:05X}"
        print(f"  [{i:3d}] {label}: 0x{val:04X} ({val:5d})")


def cmd_segwords(rom: bytes, args, rom_info: dict):
    seg, off = parse_segoff(args.segoff)
    file_off = seg_to_file(seg, off, rom_info)
    if file_off is None:
        sys.exit(f"Cannot resolve {seg:04X}:{off:04X}")
    count = parse_int(args.count) if args.count else 16
    print(f"  {seg:04X}:{off:04X} = file 0x{file_off:05X}")
    for i in range(count):
        pos = file_off + i * 2
        if pos + 2 > len(rom):
            break
        val = struct.unpack_from("<H", rom, pos)[0]
        print(f"  [{i:3d}] {seg:04X}:{off + i * 2:04X}: 0x{val:04X} ({val:5d})")


def cmd_strings(rom: bytes, args, rom_info: dict):
    offset = parse_int(args.offset)
    length = parse_int(args.length) if args.length else 4096
    min_len = 4
    region = rom[offset : offset + length]
    cur = []
    start = 0
    for i, b in enumerate(region):
        if 32 <= b < 127:
            if not cur:
                start = i
            cur.append(chr(b))
        else:
            if len(cur) >= min_len:
                segs = file_to_segs(offset + start, rom_info)
                seg_str = ", ".join(f"{s}:{o:04X}" for s, o in segs)
                loc = f"0x{offset + start:05X}"
                if seg_str:
                    loc += f" ({seg_str})"
                print(f"  {loc}: {''.join(cur)}")
            cur = []


def cmd_find(rom: bytes, args, rom_info: dict):
    pattern_str = args.pattern
    start = parse_int(args.start) if args.start else 0
    end = parse_int(args.end) if args.end else len(rom)

    # detect hex pattern (pairs of hex digits, optionally space-separated)
    hex_clean = pattern_str.replace(" ", "")
    if re.match(r"^([0-9a-fA-F]{2})+$", hex_clean) and len(hex_clean) >= 4:
        needle = bytes.fromhex(hex_clean)
        desc = f"hex {hex_clean}"
    else:
        needle = pattern_str.encode("ascii", errors="replace")
        desc = f"ascii {pattern_str!r}"

    print(f"  Searching for {desc} in 0x{start:05X}..0x{end:05X}")
    pos = start
    hits = 0
    while pos < end:
        idx = rom.find(needle, pos, end)
        if idx < 0:
            break
        segs = file_to_segs(idx, rom_info)
        seg_str = ", ".join(f"{s}:{o:04X}" for s, o in segs)
        ctx = rom[idx : idx + max(len(needle), 40)]
        ascii_ctx = "".join(chr(b) if 32 <= b < 127 else "." for b in ctx)
        loc = f"0x{idx:05X}"
        if seg_str:
            loc += f" ({seg_str})"
        print(f"  {loc}: {ascii_ctx}")
        pos = idx + 1
        hits += 1
        if hits >= 50:
            print("  ... (truncated at 50 hits)")
            break
    if hits == 0:
        print("  (no matches)")


def cmd_addr(rom: bytes, args, rom_info: dict):
    seg, off = parse_segoff(args.segoff)
    file_off = seg_to_file(seg, off, rom_info)
    phys = (seg << 4) + off
    print(f"  Segment:Offset : {seg:04X}:{off:04X}")
    print(f"  Physical (CPU) : 0x{phys:05X}")
    if file_off is not None:
        print(f"  File offset    : 0x{file_off:05X}")
        other_segs = file_to_segs(file_off, rom_info)
        if other_segs:
            aliases = [f"{s}:{o:04X}" for s, o in other_segs if s != f"{seg:04X}" or o != off]
            if aliases:
                print(f"  Also addressable as: {', '.join(aliases)}")
    else:
        print(f"  File offset    : (unknown - not in any known segment)")


def cmd_file2seg(rom: bytes, args, rom_info: dict):
    offset = parse_int(args.offset)
    segs = file_to_segs(offset, rom_info)
    print(f"  File offset: 0x{offset:05X}")
    if segs:
        for name, off in segs:
            print(f"  {name}:{off:04X}")
    else:
        print("  (not in any known segment)")


def cmd_disasm(rom: bytes, args, rom_info: dict):
    offset = parse_int(args.offset)
    count = parse_int(args.count) if args.count else 32
    chunk = rom[offset : offset + count * 8]
    try:
        result = subprocess.run(
            ["ndisasm", "-b", "16", "-o", f"0x{offset:X}", "-"],
            input=chunk,
            capture_output=True,
            timeout=5,
        )
        lines = result.stdout.decode(errors="replace").splitlines()[:count]
        for line in lines:
            print(f"  {line}")
    except FileNotFoundError:
        sys.exit("ndisasm not found (install nasm package)")


def cmd_segdisasm(rom: bytes, args, rom_info: dict):
    seg, off = parse_segoff(args.segoff)
    file_off = seg_to_file(seg, off, rom_info)
    if file_off is None:
        sys.exit(f"Cannot resolve {seg:04X}:{off:04X}")
    count = parse_int(args.count) if args.count else 32
    chunk = rom[file_off : file_off + count * 8]
    print(f"  {seg:04X}:{off:04X} = file 0x{file_off:05X}")
    try:
        result = subprocess.run(
            ["ndisasm", "-b", "16", "-o", f"0x{off:X}", "-"],
            input=chunk,
            capture_output=True,
            timeout=5,
        )
        lines = result.stdout.decode(errors="replace").splitlines()[:count]
        for line in lines:
            print(f"  {seg:04X}:{line}")
    except FileNotFoundError:
        sys.exit("ndisasm not found (install nasm package)")


def main():
    parser = argparse.ArgumentParser(
        description="DreamWriter T400 ROM data inspection tools"
    )
    parser.add_argument("--v21", action="store_true", help="Use v2.1 ROM instead of v3.1")
    sub = parser.add_subparsers(dest="command")

    p = sub.add_parser("dump", help="Hex+ASCII dump at file offset")
    p.add_argument("offset")
    p.add_argument("length", nargs="?")

    p = sub.add_parser("seg", help="Hex+ASCII dump at segment:offset")
    p.add_argument("segoff")
    p.add_argument("length", nargs="?")

    p = sub.add_parser("words", help="Read 16-bit word table at file offset")
    p.add_argument("offset")
    p.add_argument("count", nargs="?")

    p = sub.add_parser("segwords", help="Read 16-bit word table at segment:offset")
    p.add_argument("segoff")
    p.add_argument("count", nargs="?")

    p = sub.add_parser("strings", help="Show printable strings at file offset")
    p.add_argument("offset")
    p.add_argument("length", nargs="?")

    p = sub.add_parser("find", help="Search ROM for hex or ASCII pattern")
    p.add_argument("pattern")
    p.add_argument("--from", dest="start")
    p.add_argument("--to", dest="end")

    p = sub.add_parser("addr", help="Convert segment:offset to file offset")
    p.add_argument("segoff")

    p = sub.add_parser("seg2file", help="Alias for addr")
    p.add_argument("segoff")

    p = sub.add_parser("file2seg", help="Show segment:offset for file offset")
    p.add_argument("offset")

    p = sub.add_parser("disasm", help="Disassemble at file offset")
    p.add_argument("offset")
    p.add_argument("count", nargs="?")

    p = sub.add_parser("segdisasm", help="Disassemble at segment:offset")
    p.add_argument("segoff")
    p.add_argument("count", nargs="?")

    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        return

    rom_key = "v21" if args.v21 else "v31"
    rom_info = ROMS[rom_key]
    rom = load_rom(rom_info)

    dispatch = {
        "dump": cmd_dump,
        "seg": cmd_seg,
        "words": cmd_words,
        "segwords": cmd_segwords,
        "strings": cmd_strings,
        "find": cmd_find,
        "addr": cmd_addr,
        "seg2file": cmd_addr,
        "file2seg": cmd_file2seg,
        "disasm": cmd_disasm,
        "segdisasm": cmd_segdisasm,
    }
    dispatch[args.command](rom, args, rom_info)


if __name__ == "__main__":
    main()
