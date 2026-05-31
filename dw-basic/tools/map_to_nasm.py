#!/usr/bin/env python3
"""Export selected flatlink map symbols as NASM defines."""

from __future__ import annotations

import argparse
from pathlib import Path


def read_symbols(path: Path) -> dict[str, int]:
    symbols: dict[str, int] = {}
    for line in path.read_text(errors="replace").splitlines():
        parts = line.split()
        if len(parts) != 2:
            continue
        address, name = parts
        if len(address) != 8:
            continue
        try:
            symbols[name] = int(address, 16)
        except ValueError:
            continue
    return symbols


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("map", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("symbols", nargs="+")
    args = parser.parse_args()

    symbols = read_symbols(args.map)
    lines = ["; Auto-generated from " + str(args.map)]
    for name in args.symbols:
        if name not in symbols:
            raise SystemExit(f"missing symbol in map: {name}")
        lines.append(f"%define GW_{name} 0x{symbols[name]:04x}")
    args.output.write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
