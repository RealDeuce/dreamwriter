#!/usr/bin/env python3
"""Install an EROMCARD.X payload into a formatted DreamWriter SRAM image."""

from __future__ import annotations

import argparse
import math
import struct
from pathlib import Path


SECTOR_SIZE = 0x80
ROOT_ENTRY_SIZE = 0x20
ROOT_SECTORS = 4


def read_word(data: bytes | bytearray, offset: int) -> int:
    return struct.unpack_from("<H", data, offset)[0]


def write_word(data: bytearray, offset: int, value: int) -> None:
    struct.pack_into("<H", data, offset, value & 0xFFFF)


def write_dword(data: bytearray, offset: int, value: int) -> None:
    struct.pack_into("<I", data, offset, value & 0xFFFFFFFF)


def root_offset(geometry: int) -> int:
    return (3 * geometry + 1) * SECTOR_SIZE


def data_offset(geometry: int, cluster: int) -> int:
    return (3 * geometry + 0x21 + (cluster - 2)) * SECTOR_SIZE


def max_cluster(geometry: int) -> int:
    return (geometry * 0x100) - (3 * geometry + 0x1F)


def get_fat12(data: bytes | bytearray, cluster: int) -> int:
    pos = SECTOR_SIZE + (cluster * 3) // 2
    pair = data[pos] | (data[pos + 1] << 8)
    if cluster & 1:
        return (pair >> 4) & 0x0FFF
    return pair & 0x0FFF


def set_fat12(data: bytearray, cluster: int, value: int) -> None:
    pos = SECTOR_SIZE + (cluster * 3) // 2
    value &= 0x0FFF
    pair = data[pos] | (data[pos + 1] << 8)
    if cluster & 1:
        pair = (pair & 0x000F) | (value << 4)
    else:
        pair = (pair & 0xF000) | value
    data[pos] = pair & 0xFF
    data[pos + 1] = pair >> 8


def encode_83(name: str) -> bytes:
    base, dot, ext = name.partition(".")
    if not dot:
        ext = ""
    base = base.upper()
    ext = ext.upper()
    if not (1 <= len(base) <= 8 and len(ext) <= 3):
        raise ValueError(f"not an 8.3 filename: {name}")
    return base.encode("ascii").ljust(8, b" ") + ext.encode("ascii").ljust(3, b" ")


def find_root_entry(card: bytes | bytearray, geometry: int, raw_name: bytes) -> int:
    root = root_offset(geometry)
    for index in range(ROOT_SECTORS * SECTOR_SIZE // ROOT_ENTRY_SIZE):
        off = root + index * ROOT_ENTRY_SIZE
        first = card[off]
        if card[off : off + 11] == raw_name:
            raise ValueError("EROMCARD.X already exists in image")
        if first in (0x00, 0xE5):
            return off
    raise ValueError("root directory is full")


def allocate_clusters(card: bytearray, geometry: int, size: int) -> list[int]:
    needed = max(1, math.ceil(size / SECTOR_SIZE))
    clusters: list[int] = []
    for cluster in range(2, max_cluster(geometry)):
        if get_fat12(card, cluster) == 0:
            clusters.append(cluster)
            if len(clusters) == needed:
                break
    if len(clusters) != needed:
        raise ValueError("not enough free clusters")
    for index, cluster in enumerate(clusters):
        next_cluster = clusters[index + 1] if index + 1 < len(clusters) else 0xFFF
        set_fat12(card, cluster, next_cluster)
    return clusters


def install_file(card: bytearray, geometry: int, name: str, payload: bytes) -> None:
    raw_name = encode_83(name)
    entry = find_root_entry(card, geometry, raw_name)
    clusters = allocate_clusters(card, geometry, len(payload))

    for index, cluster in enumerate(clusters):
        off = data_offset(geometry, cluster)
        chunk = payload[index * SECTOR_SIZE : (index + 1) * SECTOR_SIZE]
        card[off : off + SECTOR_SIZE] = b"\x00" * SECTOR_SIZE
        card[off : off + len(chunk)] = chunk

    card[entry : entry + ROOT_ENTRY_SIZE] = b"\x00" * ROOT_ENTRY_SIZE
    card[entry : entry + 11] = raw_name
    card[entry + 11] = 0x20
    write_word(card, entry + 0x1A, clusters[0])
    write_dword(card, entry + 0x1C, len(payload))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--card-in", default="/tmp/dw-card-1m.bin")
    parser.add_argument("--card-out", default="/tmp/dw-card-1m-dw-basic.bin")
    parser.add_argument("--payload", default="build/EROMCARD.X")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    card = bytearray(Path(args.card_in).read_bytes())
    payload = Path(args.payload).read_bytes()

    if read_word(card, 0) != 0x1997 or read_word(card, 2) != 0x0126:
        raise ValueError("input does not look like a formatted DreamWriter SRAM card")
    if len(payload) < 8 or read_word(payload, 0) != 0xA4F0 or read_word(payload, 2) != 0x1997:
        raise ValueError("payload does not look like a DreamWriter EROMCARD.X image")

    geometry = read_word(card, 4)
    install_file(card, geometry, "EROMCARD.X", payload)
    Path(args.card_out).write_bytes(card)
    print(f"installed EROMCARD.X ({len(payload)} bytes) into {args.card_out}")


if __name__ == "__main__":
    main()
