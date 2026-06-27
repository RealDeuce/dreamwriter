#!/usr/bin/env python3
"""Render a raw DreamWriter LCD framebuffer dump to a PNG image."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def parse_int(text: str) -> int:
    return int(text, 0)


def render_framebuffer(
    data: bytes,
    width: int,
    height: int,
    stride: int,
    scale: int,
) -> Image.Image:
    needed = stride * height
    if len(data) < needed:
        raise ValueError(f"framebuffer has {len(data)} bytes; need at least {needed}")

    image = Image.new("1", (width, height), 1)
    pixels = image.load()
    for y in range(height):
        row = data[y * stride : y * stride + stride]
        for x in range(width):
            byte = row[x // 8]
            bit = 0x80 >> (x % 8)
            if byte & bit:
                pixels[x, y] = 0

    if scale != 1:
        image = image.resize((width * scale, height * scale), Image.Resampling.NEAREST)
    return image.convert("RGB")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="raw framebuffer dump")
    parser.add_argument("output", type=Path, help="PNG output path")
    parser.add_argument("--width", type=parse_int, default=480)
    parser.add_argument("--height", type=parse_int, default=64)
    parser.add_argument("--stride", type=parse_int, default=64, help="bytes per scanline")
    parser.add_argument("--scale", type=parse_int, default=1)
    args = parser.parse_args()

    try:
        image = render_framebuffer(
            args.input.read_bytes(),
            width=args.width,
            height=args.height,
            stride=args.stride,
            scale=args.scale,
        )
        image.save(args.output)
    except (OSError, ValueError) as exc:
        parser.exit(1, f"{parser.prog}: error: {exc}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
