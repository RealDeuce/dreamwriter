#!/usr/bin/env python3
"""Patch generated gwdata.asm table regions that were MASM macro-generated.

This pass follows the current flat64 memory model.  It preserves RAM
reservation semantics with resb/resw, but it does not materialize the original
MASM CSEG/DSEG ORG gaps.  Those gaps belong to the future split128 model
described in docs/memory-model.md.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path


ERROR_REGION_START = "global ERRTAB"
ERROR_REGION_END = "; SUBTTL CONSTANTS FOR ROM BASIC I/O"


def convert_dup_reservations(line: str) -> str:
    code, sep, comment = line.partition(";")
    if sep and not code.strip():
        return line

    def replace_db(match: re.Match[str]) -> str:
        return match.group(1) + "resb " + match.group(2)

    def replace_dw(match: re.Match[str]) -> str:
        return match.group(1) + "resw " + match.group(2)

    code = re.sub(
        r"^(\s*)db\s+\(?([^()]+?)\)?\s+dup\s+\(\?\)\s*$",
        replace_db,
        code,
        flags=re.I,
    )
    code = re.sub(
        r"^(\s*)dw\s+\(?([^()]+?)\)?\s+dup\s+\(\?\)\s*$",
        replace_dw,
        code,
        flags=re.I,
    )
    code = re.sub(r"^(\s*)times\s+(.+?)\s+db\s+0\s*$", r"\1resb \2", code, flags=re.I)
    code = re.sub(r"^(\s*)times\s+(.+?)\s+dw\s+0\s*$", r"\1resw \2", code, flags=re.I)
    if sep:
        return code.rstrip() + " " + sep + comment
    return code


def parse_error_region(src: Path) -> list[str]:
    lines = src.read_text(errors="replace").splitlines()
    in_region = False
    pending_labels: list[str] = []
    out: list[str] = [
        "; Error-message table generated from gw-basic/gwdata.asm.",
        "global ERRTAB",
        "ERRTAB:",
        "db 0",
    ]

    for raw in lines:
        code = raw.split(";", 1)[0].strip()
        if not in_region:
            if code == "ERRTAB:":
                in_region = True
            continue
        if code.startswith("PUBLIC\tLSTERR") or code.startswith("PUBLIC LSTERR"):
            break

        m = re.match(r"PUBLIC\s+(.+)$", code, flags=re.I)
        if m:
            for name in m.group(1).split(","):
                name = name.strip()
                if name in {"$OVMSG", "OVRMSG", "$DIV0M", "DIVMSG"} and name not in pending_labels:
                    pending_labels.append(name)
            if "DSKLOC" in [n.strip() for n in m.group(1).split(",")]:
                out.append("DSKLOC equ $+6")
            continue

        m = re.match(r"([A-Za-z_$][\w$]*):$", code)
        if (
            m
            and m.group(1) in {"$OVMSG", "OVRMSG", "$DIV0M", "DIVMSG"}
            and m.group(1) not in pending_labels
        ):
            pending_labels.append(m.group(1))
            continue

        m = re.match(r'DCL\s+"(.*)"$', code, flags=re.I)
        if not m:
            continue

        for label in pending_labels:
            nasm_label = "DOL_" + label[1:] if label.startswith("$") else label
            out.append("global " + nasm_label)
            out.append(nasm_label + ":")
        pending_labels.clear()
        text = m.group(1).replace("\\", "\\\\").replace('"', '\\"')
        out.append(f'db "{text}", 0')

    out.extend(
        [
            "%define LSTERR ERRC_LSTERR",
            "",
        ]
    )
    return out


def patch_gwdata(path: Path, original: Path) -> None:
    lines = path.read_text(errors="replace").splitlines()
    error_table = parse_error_region(original)

    patched: list[str] = []
    i = 0
    saw_ramlow = False
    saw_datstr = False
    in_dsctmp = False
    emitted_dscptr = False
    while i < len(lines):
        stripped = lines[i].strip()

        if stripped == "%assign QQ QQ-2":
            i += 1
            continue

        if stripped == ERROR_REGION_START:
            patched.extend(error_table)
            i += 1
            while i < len(lines) and not lines[i].strip().startswith(ERROR_REGION_END):
                i += 1
            continue

        if stripped == "REPT\t10" or stripped == "REPT 10":
            if i + 2 < len(lines) and "dw 65535" in lines[i + 1].lower():
                patched.append("times 10 dw 65535")
                i += 3
                continue
            if i + 2 < len(lines) and "dw 1 dup (?)" in lines[i + 1].lower():
                patched.append("resw 10")
                i += 3
                continue

        if stripped == "ACRLF":
            patched.append("db 13, 10")
            i += 1
            continue

        if stripped == "DO_EXT":
            patched.append("; DO_EXT handled by explicit extern declarations")
            i += 1
            continue

        if stripped == "%define OPCNT (($-DBLDSP)/2)-1":
            patched.append("OPCNT equ (($-DBLDSP)/2)-1")
            i += 1
            continue
        if stripped in {"%define CNSLEN ENDCNS-CONSTR", "CNSLEN equ ENDCNS-CONSTR"}:
            patched.append("CNSLEN equ DATSTR_SRC-CONSTR")
            i += 1
            continue
        if stripped in {"%define CONSTR $", "CONSTR equ $"}:
            patched.append("CONSTR:")
            i += 1
            continue
        if stripped.startswith("%define RAMLOW $"):
            if not saw_ramlow:
                patched.append("; source RAMLOW phase marker")
                saw_ramlow = True
            else:
                patched.append("RAMLOW:")
            i += 1
            continue
        if stripped in {"%define DATSTR $", "DATSTR equ $"}:
            if not saw_datstr:
                patched.append("DATSTR_SRC equ $")
                saw_datstr = True
            else:
                patched.append("DATSTR equ $")
            i += 1
            continue
        if stripped == "%define ENDCNS $":
            patched.append("ENDCNS:")
            i += 1
            continue
        if stripped == "%define FILDEV FILNAM":
            patched.append("FILDEV equ FILNAM")
            i += 1
            continue
        if stripped == "%define FILNM FILNAM+1":
            patched.append("FILNM equ FILNAM+1")
            i += 1
            continue
        if stripped == "global DSCPTR" and emitted_dscptr:
            i += 1
            continue
        if stripped.startswith("%define DSCPTR $-2") or stripped.startswith("DSCPTR equ $-2"):
            i += 1
            continue

        line = lines[i]
        if stripped == "NULCNT:":
            patched.append("global NULCNT")
        if stripped == "DSCTMP:":
            in_dsctmp = True
        elif in_dsctmp and (
            stripped.startswith("times STRSIZ db 0")
            or stripped.lower().startswith("db strsiz dup (?)")
            or stripped.lower().startswith("db (strsiz) dup (?)")
        ):
            patched.append("resb 1 ;string descriptor length")
            patched.append("global DSCPTR")
            patched.append("DSCPTR:")
            patched.append("resb STRSIZ-1 ;string descriptor pointer/type")
            emitted_dscptr = True
            in_dsctmp = False
            i += 1
            continue
        if ";COPY OF THE RANDOM NUMBER SEED" in line or ";LAST RANDOM NUMBER GENERATED" in line:
            line = re.sub(r"\bdb\s+122\b", "db 0o122", line, flags=re.I)
        elif ";BETWEEN 0 AND 1" in line:
            line = re.sub(r"\bdb\s+307\b", "db 0o307", line, flags=re.I)
        elif re.match(r"\s*db\s+117\s*$", line, flags=re.I):
            line = re.sub(r"\bdb\s+117\b", "db 0o117", line, flags=re.I)
        elif re.match(r"\s*db\s+200\s*$", line, flags=re.I):
            line = re.sub(r"\bdb\s+200\b", "db 0o200", line, flags=re.I)
        patched.append(convert_dup_reservations(line))
        i += 1

    path.write_text("\n".join(patched) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("generated", type=Path)
    parser.add_argument("original", type=Path)
    args = parser.parse_args()
    patch_gwdata(args.generated, args.original)


if __name__ == "__main__":
    main()
