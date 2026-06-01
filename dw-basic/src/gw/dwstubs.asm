; DreamWriter GW-BASIC first-pass compatibility shims.
;
; A routine belongs here only when this file deliberately satisfies the
; caller's contract for the current port. Unsupported BASIC statements jump to
; GW-BASIC's normal error paths; optional OEM hooks return explicit minimal
; values. Do not add a generic "ret" just to satisfy the linker.

%include "dwoem.inc"

extern FCERR
extern DERFNF
extern DERDNA
extern _RET

global CHNENT
global FILIND
global LPTDSP
global LRUN
global OKGETM
global OUTLOD
global PRGFLI

CHNENT:
FILIND:
LRUN:
OKGETM:
OUTLOD:
PRGFLI:
    ; Program-file backends are not enabled. These entry points are reached by
    ; LOAD/RUN/MERGE-style paths, so fail as a file lookup rather than jumping
    ; to NODSKS, which is the startup NEW/scratch initializer.
    jmp DERFNF

LPTDSP:
    dw DERDNA        ; EOF
    dw DERDNA        ; LOC
    dw DERDNA        ; LOF
    dw _RET          ; CLS
    dw _RET          ; SWD
    dw DERDNA        ; RND
    dw DERDNA        ; OPN
    dw DERDNA        ; SIN
    dw _RET          ; SOT
    dw .gps          ; GPS
    dw .gwd          ; GWD
    dw _RET          ; SCW
    dw _RET          ; GCW
    dw DERDNA        ; BIN
    dw _RET          ; BOT

.gps:
    xor ah, ah
    ret

.gwd:
    mov ah, 255
    ret

global DLINE
global GPUTG
global LCPY
global MACLNG
global MCLXEQ
global PEKFLT
global POKFLT

DLINE:
GPUTG:
MACLNG:
MCLXEQ:
    jmp FCERR

PEKFLT:
POKFLT:
    ; No DreamWriter-specific PEEK/POKE addresses are intercepted yet. Return
    ; NZ so GW-BASIC performs the ordinary ES:[BX] read or ES:[DX] write.
    or sp, sp
    ret

LCPY:
    ; LCOPYS saves the text pointer before calling the OEM hardcopy hook and
    ; raises FCERR itself when carry returns set. Return an error instead of
    ; jumping past that cleanup.
    stc
    ret

global CMPFBC
global CSRATR
global DECFET
global DONOTE
global FETCHR
global FETCHZ
global FIXINP
global FKYADV
global FKYFMT
global GETFBC
global GETHED
global GRPSIZ
global GWINI
global INFMAP
global INKMAP
global MAPSUP
global POLCOM
global POLLEV
global PRGFIN
global PROCHK
global PRODIR
global PRTMAP
global RDPEN
global RDSTIK
global RDTRIG
global SCRSTT
global SEGINI
global SETCBF
global SETFBC
global PIXSIZ
global READC
global FETCHC
global STOREC
global SETATR
global NSETCX
global SCALXY
global MAPXYC
global DOWNC
global LEFTC
global RIGHTC
global SWIDTH
global EDTMAP
global SYSTEM
global SYSTME
global VALSC2

CMPFBC:
CSRATR:
DECFET:
DONOTE:
FETCHR:
FETCHZ:
FIXINP:
INFMAP:
INKMAP:
MAPSUP:
POLCOM:
PRGFIN:
PROCHK:
PRODIR:
RDSTIK:
RDTRIG:
SCRSTT:
SEGINI:
SETCBF:
SETFBC:
SWIDTH:
VALSC2:
    clc
    ret

RDPEN:
    xor bx, bx
    clc
    ret

POLLEV:
    ; No firmware interrupt flag is wired into GW-BASIC yet. Ask CHKINT to run
    ; POLKEY on each poll; KEYINP still performs the nonblocking keyboard test.
    push ax
    mov al, 1
    or al, al
    pop ax
    ret

EDTMAP:
PRTMAP:
    ; The generic screen driver expects OEM mapping hooks to turn output
    ; controls into AH=0xff function codes before CTLDSP dispatches FUNTAB.
    ; Leaving CR/LF as plain bytes makes the display path try to wrap/draw
    ; them as printable cells instead of running LCARET/LFEED.
    or al, al
    jz .done
    cmp al, 32
    jb .control
    cmp al, 127
    jne .done
.control:
    mov ah, 0xff
    cmp al, 0
.done:
    ret

GRPSIZ:
    ; Gengrp calls this during GRPINI even when graphics statements are not
    ; available. Return the LCD pixel extent using the original BC/DE naming:
    ; CX is X, DX is Y.
    mov cx, 479
    mov dx, 63
    ret

PIXSIZ:
    ; Text-only bring-up: real graphics statements test this and raise FCERR.
    xor al, al
    ret

GETFBC:
    ; Foreground/background color pair for GRPRST. With PIXSIZ=0 this is only
    ; used to seed gengrp state.
    mov al, 1
    xor bx, bx
    clc
    ret

READC:
FETCHC:
STOREC:
SETATR:
NSETCX:
SCALXY:
MAPXYC:
DOWNC:
LEFTC:
RIGHTC:
    ; Pixel backend hooks. They should not be reached while PIXSIZ reports
    ; text-only mode, but keep the gengrp initialization/link contract explicit.
    clc
    ret

softkey_format:
    dw (10 << 8) | 6
    db 1

FKYADV:
    ; Single fixed soft-key page. Return NZ so callers know there is a page to
    ; display and LABEL does not interpret the advance as "past the last page".
    push ax
    mov al, 1
    or al, al
    pop ax
    ret

FKYFMT:
    ; BX -> CH=key count, CL=chars/key, byte first key number.
    mov bx, softkey_format
    ret

extern CLRSCN
extern SCNSWI
extern SCNBRK
extern SCNCLR
extern KEYSW
extern CSRTYP
extern CSRFLG
extern dw_cursor_init

GWINI:
    pushf
    pusha
    push ds
    push es
    call dw_cursor_init
    call CLRSCN
    mov al, 80
    mov cl, 8
    call SCNSWI
    mov byte [KEYSW], 0
    call SCNBRK
    call SCNCLR
    pop es
    pop ds
    popa
    popf
    ret

GETHED:
    mov bx, .empty_heading
    cmp byte [bx], 0
    ret
.empty_heading:
    db 0

extern CLSALL
extern GIOTRM
extern INITFG

SYSTEM:
    jnz .not_eos
    push cs
    pop ds
    call CLSALL
    jmp SYSTME
.not_eos:
    ret

SYSTME:
    push cs
    pop ds
    cmp byte [INITFG], 0
    je .restore
    call GIOTRM
.restore:
    cli
    mov ax, [DW_EXIT_SP]
    or ax, ax
    jz .halt
    mov ax, [DW_EXIT_ES]
    mov es, ax
    mov ax, [DW_EXIT_SS]
    mov ss, ax
    mov sp, [DW_EXIT_SP]
    mov bp, sp
    mov ax, [DW_EXIT_IP]
    mov [bp], ax
    mov ax, [DW_EXIT_CS]
    mov [bp+2], ax
    mov ax, [DW_EXIT_DS]
    mov ds, ax
    sti
    retf
.halt:
    sti
    hlt
    jmp .halt

global SETC
SETC:
    jmp FCERR

global DW_LOADER_LIMIT
DW_LOADER_LIMIT:
    dw 0
global DW_EXIT_DS
DW_EXIT_DS:
    dw 0
global DW_EXIT_ES
DW_EXIT_ES:
    dw 0
global DW_EXIT_SS
DW_EXIT_SS:
    dw 0
global DW_EXIT_SP
DW_EXIT_SP:
    dw 0
global DW_EXIT_IP
DW_EXIT_IP:
    dw 0
global DW_EXIT_CS
DW_EXIT_CS:
    dw 0

%include "dwapi.asm"

global LSTVAR
LSTVAR:
    dw 0
