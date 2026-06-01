#!/usr/bin/env python3
"""Patch converted GW-BASIC code for the flat64 ROM CARD model.

The flat64 model is the current target: one overlay is loaded into a dedicated
64K segment and BASIC runs with CS=DS=ES=SS.  The original GW-BASIC sources also
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
        "TBUFF equ BUF ;ROM CARD launch has no CP/M command buffer\n\tMOV\tbyte [TBUFF],0 ;ROM CARD launch has no CP/M/DOS command tail\n\tMOV\tBX,TBUFF ;POINT TO FIRST CHAR OF COMMAND BUFFER",
        1,
    )
    text = re.sub(
        r"""[ \t]*MOV[ \t]+AL,255 ;if heading is printed, display Fn keys also
[ \t]*MOV[ \t]+byte \[KEYSW\],[ \t]*AL
[ \t]*CALL[ \t]+GETHED ;Get OEM specific portion of the heading""",
        "\tXOR\tAL,AL ;DreamWriter has no function-key display row\n"
        "\tMOV\tbyte [KEYSW],AL\n"
        "\tCALL\tGETHED ;Get OEM specific portion of the heading",
        text,
        count=1,
    )
    text = text.replace(
        "PRNTIT:\tCALL\tSTROUT ;Print it\n\tMOV\tBX,HEDING ;GET HEADING (\"BASIC VERSION...\")\n\tCALL\tSTROUT ;PRINT IT",
        "PRNTIT:\n\tCALL\tSTROUT ;Print it\n\tMOV\tBX,HEDING ;GET HEADING (\"BASIC VERSION...\")\n\tCALL\tSTROUT ;PRINT IT",
        1,
    )
    text = re.sub(
        r"""[ \t]*MOV[ \t]+byte \[KEYSW\],[ \t]*AL ;Show current status of keys
[ \t]*CALL[ \t]+SKEYON ;Set function key display on""",
        "\tMOV\tbyte [KEYSW],AL ;Function-key display remains disabled\n"
        "\tCALL\tSKEYON ;No-op without soft-key slots",
        text,
        count=1,
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


def patch_bimisc(path: Path) -> None:
    text = path.read_text(errors="replace")
    text = replace_once(
        text,
        """global INITRP
INITRP:
extern TRPTBL
\tMOV\tBX,TRPTBL ;HL=TRAP TABLE ADDRESS
\tMOV\tCH,NUMTRP ;B=NUMBER OF TRAPS
\tXOR\tAL,AL
INITP0:\tMOV\tbyte [BX],AL ;TRAP OFF
\tINC\tBX
\tMOV\tbyte [BX],AL
\tINC\tBX
\tMOV\tbyte [BX],AL ;CLEAR GOSUB ADDR TOO!
\tINC\tBX
\tDEC\tCH
\tJNZ\tINITP0
\tMOV byte [ONGSBF], AL
\tRET
""",
        """global INITRP
INITRP:
extern TRPTBL
%if NUMTRP
\tMOV\tBX,TRPTBL ;HL=TRAP TABLE ADDRESS
\tMOV\tCH,NUMTRP ;B=NUMBER OF TRAPS
\tXOR\tAL,AL
INITP0:\tMOV\tbyte [BX],AL ;TRAP OFF
\tINC\tBX
\tMOV\tbyte [BX],AL
\tINC\tBX
\tMOV\tbyte [BX],AL ;CLEAR GOSUB ADDR TOO!
\tINC\tBX
\tDEC\tCH
\tJNZ\tINITP0
%else
\tXOR\tAL,AL
%endif
\tMOV byte [ONGSBF], AL
\tRET
""",
    )
    text = replace_once(
        text,
        """GOTRP:
\tMOV AL, byte [ONEFLG]
\tOR\tAL,AL
\tJZ\t$+3
\tRET ;CAN'T TRAP FROM ERROR TRAP
\tPUSH\tBX ;SAVE TES\bXT POINTER
""",
        """GOTRP:
\tMOV AL, byte [ONEFLG]
\tOR\tAL,AL
\tJZ\t$+3
\tRET ;CAN'T TRAP FROM ERROR TRAP
%if NUMTRP == 0
\tRET
%endif
\tPUSH\tBX ;SAVE TES\bXT POINTER
""",
    )
    path.write_text(text)


def patch_giokyb(path: Path) -> None:
    text = path.read_text(errors="replace")
    text = replace_once(
        text,
        """QONEBT:
\tJMP\tQUEKEY ;else queue the key for CHSNS
""",
        """QONEBT:
\tCALL\tTRPCHK ;Trap key-shaped one-byte controls if enabled
\tJNZ\tGETKLP ;branch if Key was trapped (don't queue)
\tJMP\tQUEKEY ;else queue the key for CHSNS
""",
    )
    text = replace_once(
        text,
        """TRPKTB:
db 30,NMKEYF+0o0 ;ON KEY (Cursor Up)
db 29,NMKEYF+0o1 ;ON KEY (Cursor Left)
db 28,NMKEYF+0o2 ;ON KEY (Cursor Right)
db 31,NMKEYF+0o3 ;ON KEY (Cursor Down)
db 0o0 ;end-of-table
""",
        """TRPKTB:
db 27,DW_KEY_EVENT_ESCAPE ;ON KEY(1) - CAN/Escape
db 9,DW_KEY_EVENT_TAB ;ON KEY(2) - Tab
db 18,DW_KEY_EVENT_INSERT ;ON KEY(4) - Insert
db 8,DW_KEY_EVENT_BACKSPACE ;ON KEY(5) - Backspace
db 13,DW_KEY_EVENT_RETURN ;ON KEY(6) - Return
db 11,DW_KEY_EVENT_WP ;ON KEY(7) - WP/ORGN Home
db 30,DW_CURSOR_KEY_EVENT_BASE+0o0 ;ON KEY(11) - Cursor Up
db 29,DW_CURSOR_KEY_EVENT_BASE+0o1 ;ON KEY(12) - Cursor Left
db 28,DW_CURSOR_KEY_EVENT_BASE+0o2 ;ON KEY(13) - Cursor Right
db 31,DW_CURSOR_KEY_EVENT_BASE+0o3 ;ON KEY(14) - Cursor Down
db 0o0 ;end-of-table
""",
    )
    path.write_text(text)


def patch_scndrv(path: Path) -> None:
    text = path.read_text(errors="replace")
    text = replace_once(
        text,
        """\tPUSH\tCX
\tDEC\tCL ; Reserve status line
\tMOV byte [WDOBOT], CL ; Set window bottom
\tPOP\tCX
""",
        """\tPUSH\tCX
%if NMKEYF
\tDEC\tCL ; Reserve function-key display line
%endif
\tMOV byte [WDOBOT], CL ; Set window bottom
\tPOP\tCX
""",
    )
    path.write_text(text)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "module",
        choices=["bimisc", "giokyb", "gwinit", "itsa86", "gio86", "scndrv"],
    )
    parser.add_argument("path", type=Path)
    args = parser.parse_args()

    if args.module == "bimisc":
        patch_bimisc(args.path)
    elif args.module == "giokyb":
        patch_giokyb(args.path)
    elif args.module == "gwinit":
        patch_gwinit(args.path)
    elif args.module == "itsa86":
        patch_itsa86(args.path)
    elif args.module == "gio86":
        patch_gio86(args.path)
    else:
        patch_scndrv(args.path)


if __name__ == "__main__":
    main()
