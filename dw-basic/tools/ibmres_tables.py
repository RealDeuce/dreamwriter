#!/usr/bin/env python3
"""Expand the IBM reserved-word table macros in generated NASM."""

from __future__ import annotations

import re
import sys
from pathlib import Path


TARGET_RENAMES = {
    "COMMON": "BASIC_COMMON",
    "BASIC_COMMON": "BASIC_COMMON",
    "TIMES": "TIMES_STMT",
    "VIEW": "VIEW_STMT",
    "WINDOW": "WINDOW_STMT",
}

DISABLED_DISPATCH = {
    "BLOAD": "NODSKS",
    "BSAVE": "NODSKS",
    "CHAIN": "NODSKS",
    "CHDIR": "NODSKS",
    "CIRCLE": "FCERR",
    "COM": "FCERR",
    "CVD": "FCERR",
    "CVI": "FCERR",
    "CVS": "FCERR",
    "DRAW": "FCERR",
    "ENVIRON": "FCERR",
    "ERDEV": "FCERR",
    "FIELD": "NODSKS",
    "FILES": "NODSKS",
    "GET": "NODSKS",
    "IOCTL": "FCERR",
    "JIS": "FCERR",
    "KILL": "NODSKS",
    "KLEN": "FCERR",
    "KPOS": "FCERR",
    "KTN": "FCERR",
    "LCOPY": "FCERR",
    "LOAD": "NODSKS",
    "LPOS": "FCERR",
    "LSET": "NODSKS",
    "MERGE": "NODSKS",
    "MKD$": "FCERR",
    "MKDIR": "NODSKS",
    "MKI$": "FCERR",
    "MKS$": "FCERR",
    "MOTOR": "FCERR",
    "NAME": "NODSKS",
    "PAINT": "FCERR",
    "PALETTE": "FCERR",
    "PEN": "FCERR",
    "PLAY": "FCERR",
    "PMAP": "FCERR",
    "PRESET": "FCERR",
    "PSET": "FCERR",
    "PUT": "NODSKS",
    "RESET": "NODSKS",
    "RMDIR": "NODSKS",
    "RSET": "NODSKS",
    "SAVE": "NODSKS",
    "SHELL": "FCERR",
    "SOUND": "FCERR",
    "STICK": "FCERR",
    "STRIG": "FCERR",
    "SYSTEM": "FCERR",
    "TIMER": "FCERR",
}

TOKEN_RENAMES = {
    "BASIC_COMMON": "COMMON",
    "VIEW_STMT": "VIEW",
    "WINDOW_STMT": "WINDOW",
    "TIMES_STMT": "TIME$",
}

ABSOLUTE_GLOBAL_PREFIXES = ("DOL_",)
ABSOLUTE_GLOBALS = {
    "ATNTK",
    "BOTCON",
    "CLINTK",
    "DIVTK",
    "DOL_CDBLF",
    "DOL_CHRFN",
    "DOL_CSNGF",
    "DOL_DATCO",
    "DOL_REMCO",
    "DOL_RNDFN",
    "EQULTK",
    "ERCTK",
    "ERLTK",
    "EXPTK",
    "FNTK",
    "GREATK",
    "IDIVTK",
    "INSRTK",
    "LASNUM",
    "LESSTK",
    "LSTOPK",
    "MIDTK",
    "MINUTK",
    "MULTK",
    "NMREL",
    "NOTTK",
    "NUMCMD",
    "NUMGFN",
    "ONEFUN",
    "PLUSTK",
    "SNGQTK",
    "SPCTK",
    "SQRTK",
    "STEPTK",
    "TABTK",
    "THENTK",
    "TOPCON",
    "USINTK",
    "USRTK",
}


def token_name(name: str) -> str:
    return "DOL_" + TOKEN_RENAMES.get(name, name)


def target_name(name: str) -> str:
    return TARGET_RENAMES.get(name, name)


def dispatch_target(token: str, target: str) -> str:
    return DISABLED_DISPATCH.get(display_name(token), target_name(target))


def display_name(name: str) -> str:
    return TOKEN_RENAMES.get(name, name)


def parse_int(text: str) -> int:
    text = text.strip()
    if text.startswith("0o"):
        return int(text, 8)
    return int(text, 10)


def byte_expr(value: int) -> str:
    if 32 <= value < 127 and value not in {ord('"'), ord("\\")}:
        return f'"{chr(value)}"'
    return str(value)


def reserved_word_bytes(name: str, is_function: bool) -> list[str]:
    text = display_name(name)
    if len(text) < 2:
        raise ValueError(f"reserved word too short for Q macro: {name}")
    out = [f"db {byte_expr(ord(ch))}" for ch in text[1:-1]]
    out.append(f"db {byte_expr(ord(text[-1]) + 128)}")
    suffix = "-128" if is_function else ""
    out.append(f"db {token_name(name)}{suffix}")
    return out


def should_drop_global(line: str) -> bool:
    match = re.fullmatch(r"global\s+(.+)", line.strip())
    if not match:
        return False
    names = [name.strip() for name in match.group(1).split(",")]
    return all(name in ABSOLUTE_GLOBALS or name.startswith(ABSOLUTE_GLOBAL_PREFIXES) for name in names)


def patch_ibmres(path: Path) -> None:
    out: list[str] = []
    qq: int | None = None
    include_inserted = False

    for line in path.read_text().splitlines():
        stripped = line.strip()

        if not include_inserted and stripped.startswith("; [ This translation"):
            out.append(line)
            out.append('%include "dwoem.inc"')
            include_inserted = True
            continue

        if should_drop_global(line):
            continue

        match = re.fullmatch(r"%(?:define|assign)\s+QQ\s+(.+)", stripped)
        if match:
            expr = match.group(1).strip()
            match_qq_add = re.fullmatch(r"QQ\+([0-9]+)", expr)
            if match_qq_add:
                if qq is None:
                    raise ValueError("QQ increment before initialization")
                qq += int(match_qq_add.group(1))
            else:
                qq = parse_int(expr)
            out.append(f"; {stripped}")
            continue

        match = re.fullmatch(r"R\s+([A-Za-z_.$?][\w.$?]*)(?:\s+;.*)?", stripped)
        if match:
            if qq is None:
                raise ValueError("R macro before QQ initialization")
            name = match.group(1)
            target = dispatch_target(name, name)
            out.append(f"extern {target}")
            out.append(f"dw {target}")
            qq += 1
            if name != "DUMMY":
                out.append(f"%assign {token_name(name)} {qq}")
            continue

        match = re.fullmatch(r"R2\s+([A-Za-z_.$?][\w.$?]*),\s*([A-Za-z_.$?][\w.$?]*)(?:\s+;.*)?", stripped)
        if match:
            if qq is None:
                raise ValueError("R2 macro before QQ initialization")
            name = match.group(1)
            target = dispatch_target(name, match.group(2))
            out.append(f"extern {target}")
            out.append(f"dw {target}")
            qq += 1
            if name != "DUMMY":
                out.append(f"%assign {token_name(name)} {qq}")
            continue

        match = re.fullmatch(r"T\s+([A-Za-z_.$?][\w.$?]*)(?:\s+;.*)?", stripped)
        if match:
            if qq is None:
                raise ValueError("T macro before QQ initialization")
            name = match.group(1)
            qq += 1
            if name != "DUMMY":
                out.append(f"%assign {token_name(name)} {qq}")
            continue

        match = re.fullmatch(r"Q(F?)\s+([A-Za-z_.$?][\w.$?]*)(?:\s+;.*)?", stripped)
        if match:
            out.extend(reserved_word_bytes(match.group(2), is_function=bool(match.group(1))))
            continue

        match = re.fullmatch(r"%define\s+([A-Za-z_.$?][\w.$?]*)\s+(.+?)(?:\s+;.*)?", stripped)
        if match and qq is not None and "QQ" in match.group(2):
            name = match.group(1)
            expr = match.group(2).replace("QQ", str(qq))
            out.append(f"%assign {name} {expr}")
            continue

        out.append(line)

    path.write_text("\n".join(out) + "\n")


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} generated-ibmres.asm")
    patch_ibmres(Path(sys.argv[1]))


if __name__ == "__main__":
    main()
