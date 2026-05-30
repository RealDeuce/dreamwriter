; Auto-converted mechanically from ../gw-basic/giocon.asm
; Edit the converter or the generated source deliberately; do not hand-wave syntax changes.

; [ This translation created 10-Feb-83 by Version 4.3 ]
; .RADIX  8
%include "dwoem.inc"
; TITLE   GIOCON - Machine Independent CONS: Device Support
; COMMENT *
; 
; --------- --- ---- -- ---------
; COPYRIGHT (C) 1982 BY MICROSOFT
; --------- --- ---- -- ---------
; 
%include "gio86u.inc"
%define CPM86 0o0 ;CPM86
;This module becomes NULL if CONSSW is 0
;
%include "msdosu.inc" ;MSDOS Constant Definitions
global CONDSP
global _RET
global CONSOT
extern DERBFM
extern PDCBAX
extern DEVBOT
extern DEVBIN
; SUBTTL  CONS (Raw-CRT output Dispatch Table and Routines)
;Console Dispatch Table
;
CONDSP:
dw (DERBFM) ;test EOF for file opened to this device
dw (DERBFM) ;LOC
dw (DERBFM) ;LOF
dw (_RET) ;perform special CLOSE functions for this device
dw (DERBFM) ;set device width
dw (DERBFM) ;GET/PUT random record from/to this device
dw (CONOPN) ;perform special OPEN functions for this device
dw (DERBFM) ;input 1 byte from file opened on this device
dw (CONSOT) ;output 1 byte to file opened on this device
dw (CONGPS) ;POS
dw (CONGWD) ;get device width
dw (_RET) ;set device comma width
dw (_RET) ;get device comma width
dw (DEVBIN) ;block input from file opened on this device
dw (DEVBOT) ;block output to file opened on this device
;CONOPN - perform any device dependent open functions.
; Entry - [AL]=  device id
;                0 if default device,
;                1..n for Disk A:, B:, ...
;                -1..-n for non-disk devices
;         [BX] = file number (0..n)
;         [CX] = random record size if [FILMOD] = random
;                (if [CX] = 0, use default record size)
;         [DI] = device offset (2=SCND, 4=SCRN, etc.)
;         [FILMOD] = file mode
;                    MD.SQI = 1 ;sequential input
;                    MD.SQO = 2 ;sequential output
;                    MD.RND = 3 ;random
;                    MD.APP = 4 ;append
;         [FILNAM] = filename
;         [FILEXT] = 1..3 byte filename extension
; Exit  - [SI] points to new FDB
;         FDB is linked into FDB chain with all standard
;         fields initialized.
;         All other registers are preserved.
;
extern INIFDB
CONOPN:
	MOV	AH,MD_SQO ;allow open for output only
	MOV	DX,255 ;initial file column position=0
;initial file width=255
	JMP	INIFDB
;CONGPS - return current file position.
; Entry - SI points to File-Data-Block.
; Exit  - [AH] = current file column. (0-relative)
;         All other registers preserved
;
CONGPS:	MOV	AH,0o0
_RET:	RET
;CONGWD - get device width
; Exit  - [AH] = device width as set by xxxSWD
;         All other registers preserved
;
CONGWD:
	MOV	AH,255 ;infinite width
	RET
;CONSOT - Write one byte to the console.
;
;ENTRY  - AL = Character to output
;EXIT   - All registers except SI and DI are preserved.
;
CONSOT:	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	CMP	AL,255
	JZ	CONSOX ;Don't allow outputing FFH
	MOV	DL,AL
mov ah, C_DCIO
int 33 ;Direct Console I/O
CONSOX:	JMP	PDCBAX ;Pop DX,CX,BX,AX and RET
