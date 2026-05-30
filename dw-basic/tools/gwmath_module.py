#!/usr/bin/env python3
"""Generate the combined GW-BASIC math module.

The upstream math package is split across math1.asm and math2.asm, but math1
opens the code segment and math2 closes it.  Treating math2 as a separate object
creates bogus unresolved symbols, so this joins the sources before conversion.
"""

from __future__ import annotations

import argparse
import tempfile
from pathlib import Path

import masm2nasm


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("math1", type=Path)
    parser.add_argument("math2", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    combined = (
        args.math1.read_text(errors="replace")
        + "\n\n; --- continuation from "
        + str(args.math2)
        + " ---\n\n"
        + args.math2.read_text(errors="replace")
    )
    with tempfile.NamedTemporaryFile("w", suffix="-math86.asm", delete=False) as tmp:
        tmp_path = Path(tmp.name)
        tmp.write(combined)
    try:
        masm2nasm.convert_file(tmp_path, args.output)
    finally:
        tmp_path.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
