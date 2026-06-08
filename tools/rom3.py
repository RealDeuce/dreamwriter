#!/usr/bin/env python3
"""ROM helpers for the DreamWriter T400 ROM 3.1 image.

Overrides rom2.py constants for the 1 MiB v3.1 ROM (identity-mapped,
no physical offset).
"""

from __future__ import annotations

import hashlib
import sys
from pathlib import Path

import rom2

# Override v2.1 constants for v3.1.
ROM_PATH = Path("v3.1/t4_ir_3.1_e588.ic303")
ROM_SIZE = 0x100000
ROM_LOAD_PHYS = 0x00000
SHA256 = "d105317a9818a1b29b5d6f4c676f96bbd961646a571a0f4b6dc9b88cbe1de8e2"

# Patch rom2 module globals so all its functions use v3.1 values.
rom2.ROM_PATH = ROM_PATH
rom2.ROM_SIZE = ROM_SIZE
rom2.ROM_LOAD_PHYS = ROM_LOAD_PHYS
rom2.SHA256 = SHA256

# Re-export everything validate_snippets.py needs.
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
