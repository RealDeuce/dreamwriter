; Auto-converted mechanically from gw-basic/biboot.asm
; Edit the converter or the generated source deliberately; do not hand-wave syntax changes.

; [ This translation created 10-Feb-83 by Version 4.3 ]
; .RADIX  8
%include "dwoem.inc"
; TITLE   BIBOOT - Initialization File for ASM86 BASICs
; COMMENT *
; 
; --------- --- ---- -- --------- -----------
; COPYRIGHT (C) 1982 BY MICROSOFT CORPORATION
; --------- --- ---- -- --------- -----------
; 
;         by Niklas Traub
%include "gio86u.inc"
%define CPM86 0
%include "msdosu.inc"
; SUBTTL  ASM86 Version
;
;  There is a problem with running the ASM86 sources for BASIC as they
; stand.  MSDOS puts a 100 hex byte control block at the beginning of the
; EXE file and sets up the ES register to point to it.  BASIC, however,
; expects this block to be at 0 in the code segment. The quick and dirty
; solution is to copy the block into the code segment before doing anything
; else.  This module is included in the linker file list AFTER all others,
; but is executed first since it is defined as the entry point.
;  A 100H bytes are copied from ES:0 to CS:0 and then jump is done to
; the START label.  To accomodate the block, BINTRP should have an ORG 100H
; before any code.
;
; NOTE: Never convert the EXE file to a COM file.  COM files have the CS
;       register pointing to the control block on entry, so all offsets
;       for immediate values will be off by 100H.
;
extern START
;BIBOOT - ASM86 Version Specific Initialization
;Entry  - ES:0 pointing to start of control block.
;         DS:0 pointing to start of control block.
;
BIBOOT:
	MOV	CX,CS ; Get BASIC's segment
	MOV	ES,CX ; Make it the destination segment
	XOR	SI,SI ; Start at ES:0
	XOR	DI,DI ; Destination is CS:0
	MOV	CX,0o200 ; There are 100H bytes to move
	CLD
 REP	MOVSW
	MOV	CX,DS ; Restore segment registers
	MOV	ES,CX
	JMP	START
;
; Last label in data segment.  Is used by BASIC to initialize TXTTAB, etc.
;
global LSTVAR
LSTVAR:
	END	BIBOOT ; BIBOOT is the entry point.
;
