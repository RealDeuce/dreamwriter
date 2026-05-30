; Auto-converted mechanically from gw-basic/kanj86.asm
; Edit the converter or the generated source deliberately; do not hand-wave syntax changes.

; [ This translation created 10-Feb-83 by Version 4.3 ]
; .RADIX  8
%include "dwoem.inc"
; TITLE   KANJ86 - KANJI String Function Support for Basic-86
; COMMENT *
; 
; --------- --- ---- -- ---------
; COPYRIGHT (C) 1982 BY MICROSOFT
; --------- --- ---- -- ---------
; 
;         Author: Tom Corbett - Microsoft Inc.  -  April 28, 1982
; 
%include "gio86u.inc" ;contains DB definition
%include "msdosu.inc"
%if CPM86
; TODO include CPM86U
%endif
global KTNFN
KTNFN:
global JISFN
JISFN:
global KLENFN
KLENFN:
global KPOSFN
KPOSFN:
extern SNERR
	JMP	SNERR
