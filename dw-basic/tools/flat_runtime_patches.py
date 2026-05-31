#!/usr/bin/env python3
"""Patch converted GW-BASIC startup code for the flat64 ROM CARD model.

The flat64 model is the current target: one overlay is loaded into one 64K
segment and BASIC runs with CS=DS=ES=SS.  The original GW-BASIC sources also
contain split code/data startup machinery; keep split128 policy in
docs/memory-model.md rather than deleting those original paths silently.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path


def replace_once(text: str, old: str, new: str) -> str:
    if old not in text:
        raise SystemExit(f"patch pattern not found:\n{old}")
    return text.replace(old, new, 1)


def patch_gwinit(path: Path) -> None:
    text = path.read_text(errors="replace")
    text = replace_once(
        text,
        """extern BEGDSG ;Beg. of the data segment, offset from CS
db 0o272
dw BEGDSG ;MOVI DX,BEGDSP
db 0o261, 0o4 ;MOVI CL,4   Divide by 16 to ...
db 0o323, 0o352 ;SHR  DX,CL  get paragraph address
db 0o214, 0o311 ;MOV  CX,CS  add in code segment
db 0o3, 0o321 ;ADD  DX,CS
db 0o264, 0o46 ;MOVBI AH,38 SPECIAL FUNCTION TO CALC END
;            OF CS AND RETURN START OF DS
db 0o315, 0o41 ;INT  33     CALL SCP DOS
db 0o214, 0o330 ;MOV  AX,DS  SAVE DS FOR EXIT VECTOR
db 0o216, 0o332 ;MOV  DS,DX  SET UP SEG REGS
db 0o216, 0o302 ;MOV  ES,DX
""",
        """extern BEGDSG ;Beg. of the data segment, offset from CS
extern DW_LOADER_LIMIT
; Flat ROM CARD build: code and data labels are linked in one segment.
; Keep DS/ES/SS in the loaded segment instead of computing an EXE-style DSEG.
push cs
pop dx
mov ax, ds ;SAVE DS FOR EXIT VECTOR
mov ds, dx
mov es, dx
""",
    )
    text = re.sub(
        r"""extern CPMMEM
\s*MOV\s+BX,\s+(?:CPMMEM|\[CPMMEM\]) ;Load bytes free within segment
;For DYNCOM, CPMMEM holds the last segment addr of the system\(i\.e\. CPMMEM=2\)
extern SEGOFF
\s*CALL\s+SEGOFF ;Return byte offset of segment from current DS
\s*MOV\s+\[MEMSIZ\],\s*BX ;USE AS DEFAULT
\s*MOV\s+\[MAXMEM\],\s*BX ;set MAX DS size for CLEAR statement
""",
        """extern CPMMEM
\tMOV\tBX,word [DW_LOADER_LIMIT] ;ROM CARD approved work-area byte limit
\tMOV\t[MEMSIZ],BX ;USE AS DEFAULT
\tMOV\t[MAXMEM],BX ;set MAX DS size for CLEAR statement
""",
        text,
        count=1,
    )
    text = text.replace(
        "\tCALL\tMAPCLC ;Calc. (but don't set) the new mem. map",
        "\t; Flat ROM CARD build keeps the startup data map in place.",
    )
    text = text.replace("\tMOV\tBX,MEMSIZ ;get size of memory", "\tMOV\tBX,word [MEMSIZ] ;get size of memory")
    text = text.replace("\tMOV\tBX,MEMSIZ\n", "\tMOV\tBX,word [MEMSIZ]\n")
    text = text.replace("\tMOV\tBX,TOPMEM\n", "\tMOV\tBX,word [TOPMEM]\n")
    text = text.replace("\tMOV\tBX,TEMP8 ;Load address of command line file name", "\tMOV\tBX,word [TEMP8] ;Load address of command line file name")
    text = text.replace("\tMOV\tBX,TEMP8 ;Get pointer to file or 0", "\tMOV\tBX,word [TEMP8] ;Get pointer to file or 0")
    text = text.replace("\tMOV\tBX,TXTTAB\n", "\tMOV\tBX,word [TXTTAB]\n")
    text = text.replace(
        "\tMOV\tSP,BX\n\tXOR\tAL,AL ;INITIALIZE PROTECT FLAG",
        "\tMOV\tSP,BX\n\tSTI\n\tXOR\tAL,AL ;INITIALIZE PROTECT FLAG",
        1,
    )
    text = text.replace(
        """extern SCNIPL
\tCALL\tSCNIPL ;Screen editor initialization
\tCALL\tGWINI ;OEM specific initialization
extern SNDRST
\tCALL\tSNDRST ;reset sound queue, disable speaker
extern GIOINI
\tCALL\tGIOINI
\tMOV\tBX,word [MEMSIZ]
\tMOV\t[TOPMEM],BX
\tMOV\tBX,KBUF-1 ;INITIALIZE KBUF-1 WITH A COLON
\tMOV\tbyte [BX],":" ;DIRECT INPUTS RESTART OK.
\tCALL\tSTKINI ;REALLY SET UP INIT'S TEMPORARY STACK
""",
        """extern SCNIPL
\tCALL\tSCNIPL ;Screen editor initialization
\tCALL\tGWINI ;OEM specific initialization
extern SNDRST
\tCALL\tSNDRST ;reset sound queue, disable speaker
extern GIOINI
\tCALL\tGIOINI
\tMOV\tBX,word [MEMSIZ]
\tMOV\t[TOPMEM],BX
\tMOV\tBX,KBUF-1 ;INITIALIZE KBUF-1 WITH A COLON
\tMOV\tbyte [BX],":" ;DIRECT INPUTS RESTART OK.
\tCALL\tSTKINI ;REALLY SET UP INIT'S TEMPORARY STACK
""",
        1,
    )
    text = text.replace(
        "TBUFF equ CPMWRM+128 ;WHERE CP/M COMMAND BUFFER IS LOCATED\n\tMOV\tBX,TBUFF ;POINT TO FIRST CHAR OF COMMAND BUFFER",
        "TBUFF equ CPMWRM+128 ;WHERE CP/M COMMAND BUFFER IS LOCATED\n\tMOV\tbyte [TBUFF],0 ;ROM CARD launch has no CP/M/DOS command tail\n\tMOV\tBX,TBUFF ;POINT TO FIRST CHAR OF COMMAND BUFFER",
        1,
    )
    text = text.replace(
        "\tMOV\tAL,255 ;if heading is printed, display Fn keys also\n\tMOV\tbyte [KEYSW],AL\n\tCALL\tGETHED ;Get OEM specific portion of the heading",
        "\tMOV\tAL,255 ;if heading is printed, display Fn keys also\n\tMOV\tbyte [KEYSW],AL\n\tCALL\tGETHED ;Get OEM specific portion of the heading",
    )
    text = text.replace(
        "PRNTIT:\tCALL\tSTROUT ;Print it\n\tMOV\tBX,HEDING ;GET HEADING (\"BASIC VERSION...\")\n\tCALL\tSTROUT ;PRINT IT",
        "PRNTIT:\n\tCALL\tSTROUT ;Print it\n\tMOV\tBX,HEDING ;GET HEADING (\"BASIC VERSION...\")\n\tCALL\tSTROUT ;PRINT IT",
        1,
    )
    text = text.replace(
        "\tMOV\tbyte [KEYSW],AL ;Show current status of keys\n\tCALL\tSKEYON ;Set function key display on",
        "\tMOV\tbyte [KEYSW],AL ;Show current status of keys\n\tCALL\tSKEYON ;Set function key display on",
        1,
    )
    text = text.replace(
        "\tMOV\tbyte [INITFG],AL ;Set the initialization complete flag\n;indicating errors no longer result in an exit\n;to the OS\n\tJMP\tINITSA",
        "\tMOV\tbyte [INITFG],AL ;Set the initialization complete flag\n;indicating errors no longer result in an exit\n;to the OS\n\tJMP\tINITSA",
        1,
    )
    path.write_text(text)


def patch_itsa86(path: Path) -> None:
    text = path.read_text(errors="replace")
    text = replace_once(
        text,
        """INITSA:
\tCALL\tNODSKS
\tCALL\tMAPINI ;Init the new memory map
""",
        """INITSA:
\tCALL\tNODSKS
\tCALL\tMAPINI ;Init the new memory map
""",
    )
    text = replace_once(
        text,
        """\tOR\tAL,AL ;IF ZERO, NO FILE SEEN
\tJZ\tGREADY
\tJMP\tLRUN ;TRY TO RUN FILE
GREADY:\tJMP\tREADY
""",
        """\tOR\tAL,AL ;IF ZERO, NO FILE SEEN
\tJZ\tGREADY
\tJMP\tLRUN ;TRY TO RUN FILE
GREADY:\tJMP\tREADY
""",
    )
    text = re.sub(
        r"""MAPINI:
;Move the stack to the end of the new memory map
\s*POP\s+BX ;Return address
\s*CLI ;disable external interrupts
; while changing memory map
\s*MOV\s+AX,\s*word \[NEWDS\]
""",
        """MAPINI:
; Flat ROM CARD build: data is already in the linked load segment.
\tRET
MAPINI_ORIGINAL:
;Move the stack to the end of the new memory map
\tPOP\tBX ;Return address
\tCLI ;disable external interrupts
; while changing memory map
\tMOV\tAX,word [NEWDS]
""",
        text,
        count=1,
    )
    text = re.sub(
        r"""MAPCLC:
;Validate/get COM buffer size
\s*MOV\s+DX,\s*CSEND ;Location of COM buffer \(New end of CS:\)
""",
        """MAPCLC:
; Flat ROM CARD build: keep current DS and the loader-provided memory limit.
\tMOV\tAX,DS
\tMOV\tword [NEWDS],AX
\tMOV\tAX,word [MEMSIZ]
\tMOV\tword [MSWSIZ],AX
\tRET
MAPCLC_ORIGINAL:
;Validate/get COM buffer size
\tMOV\tDX,CSEND ;Location of COM buffer (New end of CS:)
""",
        text,
        count=1,
    )
    path.write_text(text)


def patch_gio86(path: Path) -> None:
    text = path.read_text(errors="replace")
    text = replace_once(
        text,
        """MSISET:\tPUSH\tAX
\tPUSH\tDX
\tPUSH\tES
\tMOV\tAX,36 ;MSDOS fatal error interrupt
\tMOV\tBX,DINTAD ;Get save location for fatal error
\tCALL\tSAVVEC
\tDEC\tAX ;MSDOS Ctl-C interrupt
\tMOV\tBX,CTLCAD ;Get save location
\tCALL\tSAVVEC
\tPUSH\tCS
\tPOP\tES ;BASIC code segment to ES
\tMOV\tDX,MSCTLC ;BASIC Ctl-C handler address
\tCALL\tSETVEC ;BASIC Ctl-C handler vector set
\tINC\tAX ;MSDOS fatal error interrupt
\tMOV\tDX,ERRC_DSKERR
\tCALL\tSETVEC ;BASIC fatal error handler vector set
\tPOP\tES
\tPOP\tDX
\tPOP\tAX
\tRET
MSIRST:\tPUSH\tAX
\tPUSH\tES
\tMOV\tAX,36 ;MSDOS fatal error interrupt
\tLES DX, [DINTAD] ;Get MSDOS fatal error handler add/par
\tCALL\tSETVEC
\tDEC\tAX ;MSDOS Ctl-C interrupt
\tLES DX, [CTLCAD] ;Get MSDOS Ctl-C handler add/par
\tCALL\tSETVEC
\tPOP\tES
\tPOP\tAX
\tRET
""",
        """MSISET:
; ROM CARD build has no DOS vector API. The original routine installs Ctrl-C
; and critical-error vectors through INT 21h, which is not a valid contract
; here. Preserve the caller-visible all-registers-preserved behavior by
; returning directly.
\tRET
MSIRST:
\tRET
""",
    )
    path.write_text(text)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("module", choices=["gwinit", "itsa86", "gio86"])
    parser.add_argument("path", type=Path)
    args = parser.parse_args()

    if args.module == "gwinit":
        patch_gwinit(args.path)
    elif args.module == "itsa86":
        patch_itsa86(args.path)
    else:
        patch_gio86(args.path)


if __name__ == "__main__":
    main()
