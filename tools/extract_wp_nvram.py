#!/usr/bin/env python3
"""List or extract DreamWriter WP files from a Dreamulator NVRAM image."""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path


DEFAULT_STORE_OFFSET = 0x18000
FAT_OFFSET = 0x80
ROOT_OFFSET = 0x800
ROOT_SIZE = 0x800
DATA_OFFSET = 0x1800
CLUSTER_SIZE = 0x400
ROOT_ENTRY_SIZE = 32


@dataclass(frozen=True)
class DirectoryEntry:
    raw_name: bytes
    attr: int
    cluster: int
    size: int
    root_offset: int

    @property
    def display_name(self) -> str:
        base = self.raw_name[:8].decode("ascii", "replace").rstrip()
        ext = self.raw_name[8:11].decode("ascii", "replace").rstrip()
        return f"{base}.{ext}" if ext else base


def get_fat12(volume: bytes, cluster: int) -> int:
    pos = FAT_OFFSET + (cluster * 3) // 2
    if pos + 1 >= len(volume):
        raise ValueError(f"FAT entry for cluster {cluster} is outside volume")
    pair = volume[pos] | (volume[pos + 1] << 8)
    if cluster & 1:
        return (pair >> 4) & 0x0FFF
    return pair & 0x0FFF


def iter_directory(volume: bytes) -> list[DirectoryEntry]:
    entries: list[DirectoryEntry] = []
    root_end = ROOT_OFFSET + ROOT_SIZE
    if root_end > len(volume):
        raise ValueError("root directory is outside volume")
    for root_offset in range(ROOT_OFFSET, root_end, ROOT_ENTRY_SIZE):
        entry = volume[root_offset : root_offset + ROOT_ENTRY_SIZE]
        first = entry[0]
        if first == 0x00:
            break
        if first == 0xE5:
            continue
        attr = entry[0x0B]
        if attr & 0x08:
            continue
        cluster = int.from_bytes(entry[0x1A:0x1C], "little")
        size = int.from_bytes(entry[0x1C:0x20], "little")
        entries.append(DirectoryEntry(entry[:11], attr, cluster, size, root_offset))
    return entries


def read_file(volume: bytes, entry: DirectoryEntry) -> bytes:
    if entry.cluster < 2:
        return b""
    data = bytearray()
    seen: set[int] = set()
    cluster = entry.cluster
    while 2 <= cluster < 0xFF8:
        if cluster in seen:
            raise ValueError(f"FAT chain loop at cluster {cluster}")
        seen.add(cluster)
        off = DATA_OFFSET + (cluster - 2) * CLUSTER_SIZE
        end = off + CLUSTER_SIZE
        if end > len(volume):
            raise ValueError(f"cluster {cluster} is outside volume")
        data.extend(volume[off:end])
        if len(data) >= entry.size:
            return bytes(data[: entry.size])
        cluster = get_fat12(volume, cluster)
    if len(data) < entry.size:
        raise ValueError(
            f"FAT chain ended after {len(data)} bytes, expected {entry.size}"
        )
    return bytes(data[: entry.size])


def load_volume(path: Path, store_offset: int) -> bytes:
    image = path.read_bytes()
    if store_offset < 0 or store_offset >= len(image):
        raise ValueError(f"store offset 0x{store_offset:x} is outside image")
    return image[store_offset:]


def find_entry(entries: list[DirectoryEntry], name: str) -> DirectoryEntry:
    folded = name.upper()
    matches = [entry for entry in entries if entry.display_name.upper() == folded]
    if len(matches) == 1:
        return matches[0]
    raw = folded.replace(".", "")
    matches = [
        entry
        for entry in entries
        if entry.raw_name.decode("ascii", "replace").strip().upper() == raw
    ]
    if len(matches) == 1:
        return matches[0]
    raise ValueError(f"file not found: {name}")


def format_hex(data: bytes) -> str:
    lines = []
    for off in range(0, len(data), 16):
        chunk = data[off : off + 16]
        lines.append(f"{off:04x}: " + " ".join(f"{byte:02x}" for byte in chunk))
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("nvram", type=Path, help="Dreamulator .nvram image")
    parser.add_argument(
        "--store-offset",
        type=lambda text: int(text, 0),
        default=DEFAULT_STORE_OFFSET,
        help="offset of the built-in store volume in the NVRAM image",
    )
    parser.add_argument("--list", action="store_true", help="list directory entries")
    parser.add_argument("--extract", metavar="NAME", help="extract one file by name")
    parser.add_argument("--output", type=Path, help="write extracted payload here")
    parser.add_argument(
        "--hex",
        action="store_true",
        help="print extracted payload as hex instead of raw bytes",
    )
    args = parser.parse_args(argv)

    try:
        volume = load_volume(args.nvram, args.store_offset)
        entries = iter_directory(volume)
        if args.list or not args.extract:
            for entry in entries:
                print(
                    f"{entry.display_name:<12} attr=0x{entry.attr:02x} "
                    f"cluster={entry.cluster:<4} size={entry.size:<6} "
                    f"root=0x{entry.root_offset:04x}"
                )
        if args.extract:
            payload = read_file(volume, find_entry(entries, args.extract))
            if args.output:
                args.output.write_bytes(payload)
            elif args.hex:
                print(format_hex(payload))
            else:
                sys.stdout.buffer.write(payload)
    except (OSError, ValueError) as exc:
        print(f"{args.nvram}: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
