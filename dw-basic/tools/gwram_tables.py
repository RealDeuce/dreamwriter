#!/usr/bin/env python3
"""Post-process generated GWRAM NASM.

GWRAM uses MASM macros as a compact RAM layout DSL.  The generic converter
intentionally drops macro bodies, so this pass supplies the small NASM macro
set needed by the generated declarations.
"""

from __future__ import annotations

import argparse
from pathlib import Path


RAM_MACROS = r"""
; GWRAM RAM-declaration macros reconstructed from the MASM source.
%assign DW_BASIC_GWRAM_PDIRAM_PHASE 0

%macro RINIT 2
global %1
%1:
%endmacro

%macro R 2
global %1
%1:
%if %2
resb %2
%endif
%endmacro

%macro R1 2
global %1
%1 equ $-1
%if %2
resb %2
%endif
%endmacro

%macro PDIRAM 0
%if DW_BASIC_GWRAM_PDIRAM_PHASE = 0
db 0
%elif DW_BASIC_GWRAM_PDIRAM_PHASE = 1
	RINIT	KEYSW,1
db 0
%endif
%assign DW_BASIC_GWRAM_PDIRAM_PHASE DW_BASIC_GWRAM_PDIRAM_PHASE+1
%endmacro

%macro PDURAM 0
	R	LINLEN,1
	R	LINCNT,1
	R	CRTWID,1
	R	WDOTOP,1
	R	WDOBOT,1
	R	WDOLFT,1
	R	WDORGT,1
	R	WDTFLG,1
	R	LINTTB,2*(NMLINE+1)
	R	TRMCUR,2
	R	FSTLIN,1
	R	FSTCOL,1
	R	LSTLIN,1
	R	LSTCOL,1
	R	CSRY,1
	R	CSRX,1
%endmacro
"""


def patch_gwram(path: Path) -> None:
    text = path.read_text()
    if "DW_BASIC_GWRAM_PDIRAM_PHASE" not in text:
        marker = '%include "gio86u.inc"\n'
        text = text.replace(marker, marker + RAM_MACROS + "\n", 1)
    text = text.replace(
        ';\n;** The following line is used by a source maint. tool - do not remove\n;** (OEM FUNCTION KEY DEFINITIONS) **************\n;',
        ';\n%if NMKEYF\n;** The following line is used by a source maint. tool - do not remove\n;** (OEM FUNCTION KEY DEFINITIONS) **************\n;',
        1,
    )
    text = text.replace(
        ';**(END OF DEFINITIONS) *************************\n;The preceding line is used by a source maint. tool - do not remove.\n;',
        ';**(END OF DEFINITIONS) *************************\n;The preceding line is used by a source maint. tool - do not remove.\n%endif\n;',
        1,
    )
    text = text.replace("%define FPDVAR PDIDS1", "FPDVAR equ PDIDS1")
    text = text.replace("%assign KYBQSZ 32", "KYBQSZ equ 32")
    path.write_text(text)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    args = parser.parse_args()
    patch_gwram(args.path)


if __name__ == "__main__":
    main()
