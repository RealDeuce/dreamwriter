#!/usr/bin/env python3
"""ROM helpers for the DreamWriter T400 ROM 3.1.260 image."""

from __future__ import annotations

import hashlib
import sys
from pathlib import Path

import rom2

ROM_PATH = Path("v3.1.260/t4_ir_3.1_8c8f.ic303")
ROM_SIZE = 0x100000
ROM_LOAD_PHYS = 0x00000
SHA256 = "884787d0f69bff1869bb05c5a5c1a20aef57d519f6fd87a19caa5039c09912a2"

# Patch rom2 module globals so shared helpers use the 1 MiB v3.1.260 image.
rom2.ROM_PATH = ROM_PATH
rom2.ROM_SIZE = ROM_SIZE
rom2.ROM_LOAD_PHYS = ROM_LOAD_PHYS
rom2.SHA256 = SHA256

from rom2 import (  # noqa: E402
    expand_markdown_inputs,
    file_to_phys,
    parse_addr_expr,
    parse_addr_part,
    parse_file_base,
    parse_seg_off_label,
    phys_to_file,
    read_rom,
    seg_off_to_phys,
)


def verify() -> bool:
    data = read_rom(ROM_PATH)
    return hashlib.sha256(data).hexdigest() == SHA256


if __name__ == "__main__":
    if verify():
        print(f"OK: {ROM_PATH} matches {SHA256[:16]}...")
    else:
        print(f"FAIL: {ROM_PATH} hash mismatch", file=sys.stderr)
        sys.exit(1)
