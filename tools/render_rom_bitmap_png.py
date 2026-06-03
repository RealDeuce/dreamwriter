#!/usr/bin/env python3
"""Render a fixed-size 1bpp ROM bitmap as a PNG."""

from __future__ import annotations

import argparse
import struct
import sys
import zlib
from pathlib import Path


ROM_PATH = Path("t4_ir_2.1.ic303")


def parse_int(value: str) -> int:
    value = value.strip().lower()
    if value.startswith("$"):
        return int(value[1:], 16)
    if any(char in value for char in "abcdef"):
        return int(value, 16)
    return int(value, 0)


def png_chunk(kind: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + kind
        + payload
        + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
    )


def write_grayscale_png(path: Path, pixels: list[bytes], width: int, height: int) -> None:
    raw = bytearray()
    for row in pixels:
        raw.append(0)  # PNG filter type 0: none.
        raw.extend(row)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 0, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", ihdr)
        + png_chunk(b"IDAT", zlib.compress(bytes(raw), level=9))
        + png_chunk(b"IEND", b"")
    )
    path.write_bytes(png)


def render_bitmap(
    data: bytes,
    offset: int,
    width: int,
    height: int,
    row_bytes: int,
    stride: int,
    scale: int,
    invert: bool,
) -> list[bytes]:
    end = offset + stride * (height - 1) + row_bytes
    if offset < 0 or end > len(data):
        raise ValueError(
            f"bitmap range 0x{offset:x}..0x{end:x} exceeds ROM size 0x{len(data):x}"
        )

    rows: list[bytes] = []
    for y in range(height):
        source = data[offset + y * stride : offset + y * stride + row_bytes]
        row = bytearray()
        for x in range(width):
            byte = source[x // 8]
            bit_set = bool(byte & (0x80 >> (x % 8)))
            if invert:
                bit_set = not bit_set
            value = 0 if bit_set else 255
            for _ in range(scale):
                row.append(value)
        for _ in range(scale):
            rows.append(bytes(row))
    return rows


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("offset", help="ROM file offset of the bitmap, e.g. 0x53a2f")
    parser.add_argument("width", type=int, help="visible bitmap width in pixels")
    parser.add_argument("height", type=int, help="bitmap height in rows")
    parser.add_argument("output", type=Path, help="PNG output path")
    parser.add_argument("--rom", type=Path, default=ROM_PATH, help="ROM image path")
    parser.add_argument(
        "--row-bytes",
        type=int,
        help="bytes per source row; defaults to ceil(width / 8)",
    )
    parser.add_argument(
        "--stride",
        type=lambda value: parse_int(value),
        help="bytes between source rows; defaults to --row-bytes",
    )
    parser.add_argument("--scale", type=int, default=1, help="nearest-neighbor pixel scale")
    parser.add_argument(
        "--invert",
        action="store_true",
        help="treat zero bits as ink instead of one bits",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    offset = parse_int(args.offset)
    row_bytes = args.row_bytes if args.row_bytes is not None else (args.width + 7) // 8
    stride = args.stride if args.stride is not None else row_bytes

    if args.width <= 0 or args.height <= 0:
        print("width and height must be positive", file=sys.stderr)
        return 1
    if row_bytes <= 0 or row_bytes * 8 < args.width:
        print("--row-bytes is too small for the requested width", file=sys.stderr)
        return 1
    if stride < row_bytes:
        print("--stride must be at least --row-bytes", file=sys.stderr)
        return 1
    if args.scale <= 0:
        print("--scale must be positive", file=sys.stderr)
        return 1

    data = args.rom.read_bytes()
    try:
        rows = render_bitmap(
            data,
            offset,
            args.width,
            args.height,
            row_bytes,
            stride,
            args.scale,
            args.invert,
        )
    except ValueError as exc:
        print(exc, file=sys.stderr)
        return 1

    args.output.parent.mkdir(parents=True, exist_ok=True)
    write_grayscale_png(args.output, rows, args.width * args.scale, args.height * args.scale)
    print(
        f"wrote {args.output} from file 0x{offset:05X} "
        f"({args.width}x{args.height}, row_bytes={row_bytes}, stride={stride}, scale={args.scale})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
