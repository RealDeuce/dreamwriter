; DreamWriter GW-BASIC first-pass stubs for disabled OEM surfaces.
;
; These are deliberately small link shims for features that the DreamWriter
; port has not enabled yet: disk files, graphics, printer, COM, pen/joystick,
; and macro-language hooks. Console and keyboard primitives are intentionally
; not resolved here; those need real DreamWriter implementations.

%include "dwoem.inc"

extern FCERR
extern NODSKS

global CHNENT
global FILIND
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
    jmp NODSKS

global DLINE
global GLINE
global LCPY
global MACLNG
global MCLXEQ
global PEKFLT
global POINT
global POKFLT

DLINE:
GLINE:
LCPY:
MACLNG:
MCLXEQ:
PEKFLT:
POINT:
POKFLT:
    jmp FCERR

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
global GRPINI
global GRPRST
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
global SCRATR
global SCRSTT
global SEGINI
global SETCBF
global SETCLR
global SETFBC
global SWIDTH
global CSRDSP
global EDTMAP
global GPUTG
global SYSTME
global VALSC2

CMPFBC:
CSRDSP:
CSRATR:
DECFET:
DONOTE:
EDTMAP:
FETCHR:
FETCHZ:
FIXINP:
FKYADV:
FKYFMT:
GETFBC:
GETHED:
GRPINI:
GRPRST:
GWINI:
GPUTG:
INFMAP:
INKMAP:
MAPSUP:
POLCOM:
POLLEV:
PRGFIN:
PROCHK:
PRODIR:
PRTMAP:
RDPEN:
RDSTIK:
RDTRIG:
SCRATR:
SCRSTT:
SEGINI:
SETCBF:
SETCLR:
SETFBC:
SWIDTH:
SYSTME:
VALSC2:
    clc
    ret

global SETC
SETC:
    jmp FCERR

global LSTVAR
LSTVAR:
    dw 0
