#!/usr/bin/env python3
"""First-pass comparison report for DreamWriter-family ROM dumps."""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
import zlib
from pathlib import Path


REPO_DIR = Path(__file__).resolve().parent.parent
BLOCK_SIZE = 0x20000

REFERENCE_ROMS = [
    ("t400-v2.1", REPO_DIR / "v2.1" / "t4_ir_2.1.ic303"),
    ("t400-v3.1", REPO_DIR / "v3.1" / "t4_ir_3.1_e588.ic303"),
    ("t400-v3.1.260", REPO_DIR / "v3.1.260" / "t4_ir_3.1_8c8f.ic303"),
]


def read_file(path: Path) -> bytes:
    try:
        return path.read_bytes()
    except FileNotFoundError:
        raise SystemExit(f"not found: {path}") from None


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha1(data: bytes) -> str:
    return hashlib.sha1(data).hexdigest()


def crc32(data: bytes) -> str:
    return f"{zlib.crc32(data) & 0xFFFFFFFF:08x}"


def file_id(data: bytes) -> str:
    return f"size={len(data)} sha256={sha256(data)}"


def printable_runs(data: bytes, needle: bytes, limit: int = 96) -> list[tuple[int, str]]:
    results: list[tuple[int, str]] = []
    start = 0
    while True:
        pos = data.find(needle, start)
        if pos < 0:
            break
        end = pos
        while end < len(data) and end - pos < limit and 32 <= data[end] < 127:
            end += 1
        text = data[pos:end].decode("ascii", errors="replace").rstrip()
        results.append((pos, text))
        start = pos + 1
    return results


def reset_vector(data: bytes) -> tuple[int, bytes, str]:
    offset = max(0, len(data) - 0x10)
    tail = data[offset : offset + 0x10]
    if len(tail) >= 6 and tail[0] == 0xFA and tail[1] == 0xEA:
        off = tail[2] | (tail[3] << 8)
        seg = tail[4] | (tail[5] << 8)
        return offset, tail, f"cli; jmp far {seg:04X}:{off:04X}"
    if len(tail) >= 5 and tail[0] == 0xEA:
        off = tail[1] | (tail[2] << 8)
        seg = tail[3] | (tail[4] << 8)
        return offset, tail, f"jmp far {seg:04X}:{off:04X}"
    return offset, tail, "unrecognized"


def block_hashes(data: bytes) -> list[str]:
    return [sha256(data[i : i + BLOCK_SIZE]) for i in range(0, len(data), BLOCK_SIZE)]


def exact_block_matches(left: bytes, right: bytes) -> list[tuple[int, int]]:
    left_hashes = block_hashes(left)
    right_hashes = block_hashes(right)
    matches: list[tuple[int, int]] = []
    for left_index, left_hash in enumerate(left_hashes):
        for right_index, right_hash in enumerate(right_hashes):
            if left_hash == right_hash:
                matches.append((left_index, right_index))
    return matches


def differing_byte_count(left: bytes, right: bytes) -> tuple[int, int]:
    paired = min(len(left), len(right))
    count = sum(1 for a, b in zip(left[:paired], right[:paired]) if a != b)
    count += abs(len(left) - len(right))
    return count, max(len(left), len(right))


def first_differences(left: bytes, right: bytes, limit: int = 8) -> list[tuple[int, int | None, int | None]]:
    diffs: list[tuple[int, int | None, int | None]] = []
    size = max(len(left), len(right))
    for offset in range(size):
        a = left[offset] if offset < len(left) else None
        b = right[offset] if offset < len(right) else None
        if a != b:
            diffs.append((offset, a, b))
            if len(diffs) >= limit:
                break
    return diffs


def load_references() -> list[tuple[str, Path, bytes]]:
    refs: list[tuple[str, Path, bytes]] = []
    for name, path in REFERENCE_ROMS:
        if path.exists():
            refs.append((name, path, read_file(path)))
    return refs


def print_dump_report(path: Path, data: bytes, refs: list[tuple[str, Path, bytes]]) -> None:
    print(f"## {path}")
    print()
    print(f"- size:   {len(data)} bytes / 0x{len(data):X}")
    print(f"- sha256: {sha256(data)}")
    print(f"- sha1:   {sha1(data)}")
    print(f"- crc32:  {crc32(data)}")

    reset_offset, reset_tail, reset_text = reset_vector(data)
    reset_bytes = " ".join(f"{byte:02X}" for byte in reset_tail)
    print(f"- reset:  file 0x{reset_offset:X}: {reset_text}")
    print(f"          {reset_bytes}")

    banners = printable_runs(data, b"Diagnostic ")
    if banners:
        print("- diagnostic strings:")
        for offset, text in banners:
            print(f"  - file 0x{offset:X}: {text}")
    else:
        print("- diagnostic strings: none found")

    exact_refs = [(name, ref_path) for name, ref_path, ref in refs if data == ref]
    if exact_refs:
        print("- exact reference match:")
        for name, ref_path in exact_refs:
            print(f"  - {name}: {ref_path.relative_to(REPO_DIR)}")
        print()
        return

    print("- reference comparison:")
    for name, ref_path, ref in refs:
        diff_count, diff_size = differing_byte_count(data, ref)
        matches = exact_block_matches(data, ref)
        print(f"  - {name} ({ref_path.relative_to(REPO_DIR)}):")
        print(f"    - {file_id(ref)}")
        print(f"    - differing bytes: {diff_count} / {diff_size}")
        if matches:
            match_text = ", ".join(f"new[{a}]=ref[{b}]" for a, b in matches)
            print(f"    - exact 128K block matches: {match_text}")
        else:
            print("    - exact 128K block matches: none")
        diffs = first_differences(data, ref)
        if diffs:
            rendered = []
            for offset, a, b in diffs:
                left = "--" if a is None else f"{a:02X}"
                right = "--" if b is None else f"{b:02X}"
                rendered.append(f"0x{offset:X}:{left}/{right}")
            print(f"    - first differences: {', '.join(rendered)}")
    print()


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Compare new DreamWriter-family ROM dumps against checked-in references."
    )
    parser.add_argument("rom", nargs="+", type=Path, help="ROM dump path(s) to inspect")
    args = parser.parse_args(argv)

    refs = load_references()
    if not refs:
        raise SystemExit("no reference ROMs found")

    for rom_path in args.rom:
        print_dump_report(rom_path, read_file(rom_path), refs)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
