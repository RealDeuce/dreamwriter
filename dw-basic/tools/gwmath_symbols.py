#!/usr/bin/env python3
"""Patch generated combined math package declarations."""

from __future__ import annotations

import argparse
from pathlib import Path


MATH2_EXPORTS = {
    "DOL_CDS",
    "DOL_CSD",
    "DOL_CSI",
    "DOL_DINT",
    "DOL_FI",
    "DOL_FIDIG",
    "DOL_FIND",
    "DOL_FINEX",
    "DOL_FINS",
    "DOL_FLT",
    "DOL_FMULD",
    "DOL_FMULS",
    "DOL_FOUT2",
    "DOL_FOTAN",
    "DOL_FOTCV",
    "DOL_FOTED",
    "DOL_FOTNV",
    "DOL_INT",
    "DOL_LOG",
    "DOL_NORMD",
    "DOL_NORMS",
    "DOL_POLY",
    "DOL_POLYX",
    "DOL_QINT",
    "DOL_RND",
    "DOL_ROUND",
    "DOL_ROUNS",
    "DOL_ROUNX",
    "DOL_SIGD",
    "DOL_FS",
    "FRCDBL",
    "NGBLDX",
}


def patch_math(path: Path) -> None:
    lines = path.read_text().splitlines()
    out: list[str] = []
    inserted = False
    for line in lines:
        if not inserted and line.startswith("global "):
            out.extend("global " + name for name in sorted(MATH2_EXPORTS))
            inserted = True
        out.append(line)

    text = "\n".join(out) + "\n"
    text = text.replace("\tMOV\tAL,DOL_FAC\n", "\tmov ax,DOL_FAC\n")
    path.write_text(text)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    args = parser.parse_args()
    patch_math(args.path)


if __name__ == "__main__":
    main()
