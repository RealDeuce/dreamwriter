#!/usr/bin/env python3
"""List public and external symbols from 16-bit OMF .obj files."""

from __future__ import annotations

import argparse
from pathlib import Path


EXTDEF = 0x8C
PUBDEF = 0x90
PUBDEF32 = 0x91


def read_index(data: bytes, pos: int) -> tuple[int, int]:
    first = data[pos]
    pos += 1
    if first & 0x80:
        value = ((first & 0x7F) << 8) | data[pos]
        pos += 1
        return value, pos
    return first, pos


def read_name(data: bytes, pos: int) -> tuple[str, int]:
    length = data[pos]
    pos += 1
    raw = data[pos : pos + length]
    pos += length
    return raw.decode("ascii", errors="replace"), pos


def symbols_from_obj(path: Path) -> tuple[set[str], set[str]]:
    public: set[str] = set()
    external: set[str] = set()
    blob = path.read_bytes()
    pos = 0
    while pos + 3 <= len(blob):
        rectype = blob[pos]
        reclen = blob[pos + 1] | (blob[pos + 2] << 8)
        pos += 3
        if pos + reclen > len(blob):
            break
        data = blob[pos : pos + reclen - 1]
        pos += reclen

        if rectype == EXTDEF:
            p = 0
            while p < len(data):
                name, p = read_name(data, p)
                _, p = read_index(data, p)
                external.add(name)
        elif rectype in {PUBDEF, PUBDEF32}:
            p = 0
            _, p = read_index(data, p)  # group index
            seg_index, p = read_index(data, p)
            if seg_index == 0:
                p += 2  # base frame
            offset_size = 4 if rectype == PUBDEF32 else 2
            while p < len(data):
                name, p = read_name(data, p)
                p += offset_size
                _, p = read_index(data, p)
                public.add(name)
    return public, external


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("objects", nargs="+", type=Path)
    parser.add_argument("--unresolved", action="store_true")
    parser.add_argument("--unresolved-by-file", action="store_true")
    args = parser.parse_args()

    all_public: set[str] = set()
    all_external: set[str] = set()
    by_file: list[tuple[Path, set[str], set[str]]] = []
    for obj in args.objects:
        public, external = symbols_from_obj(obj)
        by_file.append((obj, public, external))
        all_public |= public
        all_external |= external

    if args.unresolved:
        for name in sorted(all_external - all_public):
            print(name)
        return

    if args.unresolved_by_file:
        for obj, _, external in by_file:
            names = sorted(external - all_public)
            if not names:
                continue
            print(obj)
            for name in names:
                print(f"  {name}")
        return

    for obj, public, external in by_file:
        for name in sorted(public):
            print(f"public {obj} {name}")
        for name in sorted(external):
            print(f"extern {obj} {name}")


if __name__ == "__main__":
    main()
