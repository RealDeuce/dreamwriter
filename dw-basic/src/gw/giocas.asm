; Auto-converted mechanically from gw-basic/giocas.asm
; Edit the converter or the generated source deliberately; do not hand-wave syntax changes.

; [ This translation created 10-Feb-83 by Version 4.3 ]
; .RADIX  8
%include "dwoem.inc"
; TITLE   GIOCAS - Cassette Machine Independent Device Driver Code
; COMMENT *
; 
; --------- --- ---- -- ---------
; COPYRIGHT (C) 1981 BY MICROSOFT
; --------- --- ---- -- ---------
; 
; Written by:     Len Oorthuys
; 
%include "gio86u.inc"
%include "msdosu.inc"
extern DERDNA
global MOTOR
MOTOR:	JMP	DERDNA ;Device unavailable error
