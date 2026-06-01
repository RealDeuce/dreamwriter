; DreamWriter GW-BASIC device dispatch table.
;
; This file is intentionally hand-written.  The upstream GIOTBL source is a
; MASM macro table for a configurable DOS/CP/M device set, while this port only
; exposes the console keyboard/screen devices during first bring-up. Keep the
; absolute non-disk device slots in table order even when a backend is stubbed:
; GIO has hard-coded probes for LPT1 during startup cleanup.

%include "dwoem.inc"
%include "gio86u.inc"

extern CONDSP
extern DSKDSP
extern KYBDSP
extern KYBINI
extern KYBTRM
extern LPTDSP
extern SCNDSP
extern SCNINI
extern SCNTRM
extern _RET

global _DVTBL
global _DVPTR
global _DVINI
global _DVTRM

_DVTBL:
db "KYBD", DOL__KYBD
db "SCRN", DOL__SCRN
db "CONS", DOL__CONS
db "LPT1", DOL__LPT1
db 0

_DVPTR:
dw DSKDSP
dw KYBDSP
dw SCNDSP
dw CONDSP
dw LPTDSP

_DVINI:
dw KYBINI
dw SCNINI
dw _RET
dw _RET

_DVTRM:
dw KYBTRM
dw SCNTRM
dw _RET
dw _RET
