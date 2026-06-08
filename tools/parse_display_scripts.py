#!/usr/bin/env python3
"""Parse display script data referenced by traced code.

Extracts call sites from trace-full.txt, resolves display script
addresses, parses FF-command sequences, and catalogs:
  - Text strings (printable bytes between commands)
  - FF 42 bitmap references (segment:offset, dimensions)
  - FF 44 rectangle draws
  - FF 40 position commands
  - FF 02 text cursor positions
  - FF 06 attribute settings

Usage:
  parse_display_scripts.py [--trace PATH] [--rom PATH]
  parse_display_scripts.py --addr SEG:OFF --len N [--rom PATH]
"""

from __future__ import annotations

import argparse
import re
import struct
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_DIR = SCRIPT_DIR.parent

ROM_PATH = REPO_DIR / "v3.1" / "t4_ir_3.1_e588.ic303"
TRACE_PATH = REPO_DIR / "v3.1" / "docs" / "disassembly" / "trace-full.txt"

SEGMENTS = {
    "C000": 0xC0000,
    "C772": 0xC7720,
    "DEF0": 0xDEF00,
    "EE17": 0xEE170,
    "EF8A": 0xEF8A0,
    "ED1B": 0xED1B0,
    "AD00": 0xAD000,
}


def seg_to_file(seg: int, off: int) -> int | None:
    name = f"{seg:04X}"
    if name in SEGMENTS:
        return SEGMENTS[name] + off
    # physical = seg*16 + off, assume identity for fixed windows
    phys = seg * 16 + off
    if 0xC0000 <= phys < 0x100000:
        return phys
    return None


def parse_display_script(rom: bytes, file_off: int, length: int,
                         seg_str: str, si_off: int) -> dict:
    """Parse a display script and return extracted items."""
    result = {
        "addr": f"{seg_str}:{si_off:04X}",
        "file": f"0x{file_off:05X}",
        "length": length,
        "strings": [],
        "bitmaps": [],
        "commands": [],
    }

    pos = file_off
    end = file_off + length
    cur_text = []
    text_start = pos

    while pos < end and pos < len(rom):
        b = rom[pos]

        if b == 0xFF and pos + 1 < end:
            # flush pending text
            if cur_text:
                text = "".join(cur_text)
                if len(text.strip()) >= 2:
                    result["strings"].append({
                        "file": f"0x{text_start:05X}",
                        "text": text,
                    })
                cur_text = []

            cmd = rom[pos + 1]
            if cmd == 0x42 and pos + 9 < end:
                # FF 42: bitmap blit
                height = struct.unpack_from("<H", rom, pos + 2)[0]
                width = struct.unpack_from("<H", rom, pos + 4)[0]
                src_off = struct.unpack_from("<H", rom, pos + 6)[0]
                src_seg = struct.unpack_from("<H", rom, pos + 8)[0]
                row_bytes = (width + 7) // 8
                result["bitmaps"].append({
                    "file_ref": f"0x{pos:05X}",
                    "src": f"{src_seg:04X}:{src_off:04X}",
                    "src_file": seg_to_file(src_seg, src_off),
                    "width": width,
                    "height": height,
                    "row_bytes": row_bytes,
                    "size": height * row_bytes,
                })
                result["commands"].append(
                    f"FF 42 bitmap {width}x{height} at {src_seg:04X}:{src_off:04X}"
                )
                pos += 10
                continue
            elif cmd == 0x44 and pos + 13 < end:
                # FF 44: rectangle
                result["commands"].append(f"FF 44 rectangle")
                pos += 14
                continue
            elif cmd == 0x40 and pos + 5 < end:
                # FF 40: position
                x = struct.unpack_from("<H", rom, pos + 2)[0]
                y = struct.unpack_from("<H", rom, pos + 4)[0]
                result["commands"].append(f"FF 40 pos({x},{y})")
                pos += 6
                continue
            elif cmd == 0x02 and pos + 5 < end:
                # FF 02: text cursor
                x = struct.unpack_from("<H", rom, pos + 2)[0]
                y = struct.unpack_from("<H", rom, pos + 4)[0]
                result["commands"].append(f"FF 02 cursor({x},{y})")
                pos += 6
                continue
            elif cmd == 0x06 and pos + 7 < end:
                # FF 06: attribute
                result["commands"].append(f"FF 06 attr")
                pos += 8
                continue
            elif cmd == 0x04 and pos + 3 < end:
                # FF 04: font select
                result["commands"].append(f"FF 04 font")
                pos += 4
                continue
            elif cmd == 0x00:
                # FF 00: clear
                result["commands"].append(f"FF 00 clear")
                pos += 2
                continue
            elif cmd == 0x28:
                # FF 28: unknown short command
                result["commands"].append(f"FF 28")
                pos += 2
                continue
            elif cmd == 0xFF:
                # FF FF: end marker or padding
                result["commands"].append(f"FF FF end")
                pos += 2
                continue
            elif cmd == 0x3E:
                # FF 3E: glyph blit
                result["commands"].append(f"FF 3E glyph")
                pos += 2
                continue
            elif cmd == 0x4F:
                # FF 4F: unknown
                result["commands"].append(f"FF 4F")
                pos += 2
                continue
            else:
                result["commands"].append(f"FF {cmd:02X} unknown")
                pos += 2
                continue
        elif 0x20 <= b < 0xFF:
            if not cur_text:
                text_start = pos
            cur_text.append(chr(b) if 0x20 <= b < 0x7F else ".")
            pos += 1
        else:
            if cur_text:
                text = "".join(cur_text)
                if len(text.strip()) >= 2:
                    result["strings"].append({
                        "file": f"0x{text_start:05X}",
                        "text": text,
                    })
                cur_text = []
            pos += 1

    # flush final text
    if cur_text:
        text = "".join(cur_text)
        if len(text.strip()) >= 2:
            result["strings"].append({
                "file": f"0x{text_start:05X}",
                "text": text,
            })

    return result


def extract_6557_calls(trace: str) -> list[tuple[str, int, int]]:
    """Extract static (seg, SI, CX) triples from C000:6557 call sites."""
    calls = []
    lines = trace.splitlines()
    si_val = dx_val = cx_val = None

    for line in lines:
        line = line.strip()
        m = re.match(r"\S+\s+\w+\s+mov si,0x([0-9a-f]+)", line, re.I)
        if m:
            si_val = int(m.group(1), 16)
        m = re.match(r"\S+\s+\w+\s+mov dx,0x([0-9a-f]+)", line, re.I)
        if m:
            dx_val = int(m.group(1), 16)
        m = re.match(r"\S+\s+\w+\s+mov cx,0x([0-9a-f]+)", line, re.I)
        if m:
            cx_val = int(m.group(1), 16)
        if "call 0x6557" in line and si_val is not None and dx_val is not None and cx_val is not None:
            calls.append((f"{dx_val:04X}", si_val, cx_val))
            si_val = dx_val = cx_val = None

    return calls


def extract_3f35_calls(trace: str) -> list[tuple[str, int, int]]:
    """Extract static (seg, AX, CX) triples from C000:3F35 far calls."""
    calls = []
    lines = trace.splitlines()
    ax_val = bx_val = cx_val = None

    for line in lines:
        line = line.strip()
        m = re.match(r"\S+\s+\w+\s+mov ax,0x([0-9a-f]+)", line, re.I)
        if m:
            ax_val = int(m.group(1), 16)
        m = re.match(r"\S+\s+\w+\s+mov bx,0x([0-9a-f]+)", line, re.I)
        if m:
            bx_val = int(m.group(1), 16)
        m = re.match(r"\S+\s+\w+\s+mov cx,0x([0-9a-f]+)", line, re.I)
        if m:
            cx_val = int(m.group(1), 16)
        if "call 0xc000:0x3f35" in line or "call 0x3f35" in line:
            if ax_val is not None and bx_val is not None and cx_val is not None:
                if bx_val >= 0xC000 and ax_val < 0x8000:
                    calls.append((f"{bx_val:04X}", ax_val, cx_val))
            ax_val = bx_val = cx_val = None

    return calls


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--rom", type=Path, default=ROM_PATH)
    parser.add_argument("--trace", type=Path, default=TRACE_PATH)
    parser.add_argument("--addr", help="Parse single script at SEG:OFF")
    parser.add_argument("--len", type=lambda x: int(x, 0), help="Script length")
    parser.add_argument("--bitmaps-only", action="store_true",
                        help="Only show scripts containing bitmaps")
    parser.add_argument("--strings-only", action="store_true",
                        help="Only show extracted strings")
    args = parser.parse_args()

    rom = args.rom.read_bytes()

    if args.addr:
        m = re.match(r"([0-9a-fA-F]{3,4}):([0-9a-fA-F]{1,4})$", args.addr)
        if not m:
            sys.exit(f"Bad address: {args.addr}")
        seg = int(m.group(1), 16)
        off = int(m.group(2), 16)
        length = args.len or 256
        file_off = seg_to_file(seg, off)
        if file_off is None:
            sys.exit(f"Cannot resolve {args.addr}")
        result = parse_display_script(rom, file_off, length, f"{seg:04X}", off)
        print_result(result, args)
        return

    # Extract all call sites from trace
    trace = args.trace.read_text()

    calls_6557 = extract_6557_calls(trace)
    calls_3f35 = extract_3f35_calls(trace)

    # Deduplicate by (seg, offset)
    seen = set()
    all_calls = []
    for seg_str, offset, length in calls_6557:
        key = (seg_str, offset)
        if key not in seen:
            seen.add(key)
            all_calls.append((seg_str, offset, length))

    for seg_str, offset, length in calls_3f35:
        seg_val = int(seg_str, 16)
        file_off = seg_to_file(seg_val, offset)
        if file_off is not None:
            key = (seg_str, offset)
            if key not in seen:
                seen.add(key)
                all_calls.append((seg_str, offset, length))

    # Sort by file offset
    def sort_key(item):
        seg_val = int(item[0], 16)
        f = seg_to_file(seg_val, item[1])
        return f if f is not None else 0

    all_calls.sort(key=sort_key)

    all_strings = []
    all_bitmaps = []

    for seg_str, offset, length in all_calls:
        seg_val = int(seg_str, 16)
        file_off = seg_to_file(seg_val, offset)
        if file_off is None:
            continue
        result = parse_display_script(rom, file_off, length, seg_str, offset)

        if args.bitmaps_only and not result["bitmaps"]:
            continue
        if args.strings_only:
            all_strings.extend(result["strings"])
            continue

        print_result(result, args)

    if args.strings_only and all_strings:
        # Deduplicate and sort by file offset
        seen_texts = set()
        for s in sorted(all_strings, key=lambda x: x["file"]):
            text = s["text"].strip()
            if text and text not in seen_texts:
                seen_texts.add(text)
                print(f"  {s['file']}: {text}")


def print_result(result: dict, args):
    if args.bitmaps_only:
        for bm in result["bitmaps"]:
            src_file = f"0x{bm['src_file']:05X}" if bm["src_file"] else "?"
            print(f"  {result['addr']} -> {bm['src']} (file {src_file}) "
                  f"{bm['width']}x{bm['height']} ({bm['size']} bytes)")
        return

    print(f"\n=== {result['addr']} (file {result['file']}, {result['length']} bytes) ===")
    if result["commands"]:
        for cmd in result["commands"]:
            print(f"  cmd: {cmd}")
    if result["strings"]:
        for s in result["strings"]:
            print(f"  str: {s['file']}: {s['text']}")
    if result["bitmaps"]:
        for bm in result["bitmaps"]:
            src_file = f"0x{bm['src_file']:05X}" if bm["src_file"] else "?"
            print(f"  bmp: {bm['src']} (file {src_file}) "
                  f"{bm['width']}x{bm['height']} ({bm['size']} bytes)")


if __name__ == "__main__":
    main()
