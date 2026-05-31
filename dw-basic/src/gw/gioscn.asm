; Auto-converted mechanically from ../gw-basic/gioscn.asm
; Edit the converter or the generated source deliberately; do not hand-wave syntax changes.

; [ This translation created 10-Feb-83 by Version 4.3 ]
; .RADIX  8
%include "dwoem.inc"
; TITLE   GIOSCN - Screen Machine Independent Device Driver Code
; COMMENT *
; 
; --------- --- ---- -- ---------
; COPYRIGHT (C) 1982 BY MICROSOFT
; --------- --- ---- -- ---------
; 
%include "gio86u.inc"
%define CPM86 0o0 ;CPM86 Operating System
%define IBMCSR IBMLIK ;IBM compatibile cursor control interface
;Definition of scroll types
; Choice of scroll type is by switch SCROLT.
; Switches defined here are used to implement a specific SCROLT type.
; If other scroll types are needed then additional SCROLT types should be
;   defined here.
%define INVLIN SCROLT ;Invisible (function key) Line
%define FKFSRL (SCROLT-0o1) AND 0o1 ;Clear fkeys/full scroll/rewrite fkeys
%include "msdosu.inc" ;Operating System Constants
global SCNDSP
global SCNINI
global SCNTRM
extern DERBFM
extern INIFDB
extern DEVBIN
extern DEVBOT
extern TWOBYT
;Screen Dispatch Table
;
SCNDSP:
dw (DERBFM) ;test EOF for file opened to this device
dw (DERBFM) ;LOC
dw (DERBFM) ;LOF
dw (SCNCLS) ;perform special CLOSE functions for this device
dw (SCNSWD) ;set device width
dw (DERBFM) ;GET/PUT random record from/to this device
dw (SCNOPN) ;perform special OPEN functions for this device
dw (DERBFM) ;input 1 byte from file opened on this device
dw (SCNSOT) ;output 1 byte to file opened on this device
dw (SCNGPS) ;POS
dw (SCNGWD) ;get device width
dw (SCNSCW) ;set device comma width
dw (SCNGCW) ;get device comma width
dw (DEVBIN) ;block input from file opened on this device
dw (DEVBOT) ;block output to file opened on this device
global SCNSWD
global SCNSOT
global SCNGPS
global SCNGWD
global SCNSCW
global SCNGCW
; SUBTTL CRT Primitive I/O Routines
;SCNINI is called to initialize Screen when BASIC comes up
;
extern WDTFLG
SCNINI:
	MOV AL, byte [LINLEN] ; Get CRT logical line length
	MOV byte [WDTFLG], AL ; Default width of device SCRN:
	RET
;SCNTRM is called to Clean-up Screen when BASIC terminates
;
extern TKEYOF
SCNTRM:	CALL	TKEYOF ;Turn off KEY display
extern SCNPOS
	CALL	SCNPOS ;[DX]=current cursor location
	RET
;SCNCLS - perform any device dependent close functions.
; Entry - SI points to File-Data-Block.
; Exit  - All registers preserved.
;         This routine is called before BASIC releases the
;         file-data-block associated with this file.
;
SCNCLS:	RET
;SCNSWD - set device width
; Entry - [DX] = new device width
; Exit  - All registers preserved
;
SCNSWD:
extern SWIDTH
extern LINCNT
extern WDTFLG
	MOV byte [WDTFLG], DL ;Set/Reset infinite length flag
	CMP	DL,255
	JNZ	SCNWD1 ;BRIF not infinite length
	RET
SCNWD1:	PUSH	CX
	PUSH	AX
	MOV	AL,DL ;pass Width in AL
	MOV CL, byte [LINCNT] ;pass Height in CL
	CALL	SWIDTH ;Let screen editor set width
	POP	AX
	POP	CX
	RET
;SCNOPN - perform any device dependent open functions.
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
SCNOPN:
	CALL	SCNGPS ;[AH]=current column position
	MOV	DH,AH ;[DH]=current column position
	MOV	AH,MD_SQO ;allow open for output only
	MOV DL, byte [WDTFLG] ;initial file logical width
	JMP	INIFDB
global CALTTY
global DOL_CATTY
;CALTTY IS A SPECIAL ROUTINE TO OUTPUT ERROR MESSAGE TO TTY, REGARDLESS
;   OF CURRENT FILE I/O.
; Entry - [AL] = byte to be output
; Exit  - All registers preserved
;
extern OUTDO
extern PTRFIL
DOL_CATTY:
CALTTY:	PUSH	word [PTRFIL]
	MOV word [PTRFIL], 0o0 ;Make sure we go to the "TTY"
	CALL	OUTDO
	POP	word [PTRFIL]
	RET
;SCNSOT - Sequential Output.
; Entry - SI points to File-Data-Block.
;         [AL] = byte to be output.
; Exit  - SI, DI can be changed.
;         All other registers preserved
;         This routine expands tabs if appropriate.
;         It need not force a carriage return when width
;         exceeded as this is handled at a lower level.
;
SCNSOT:
extern SCNOUT
	PUSHF
	PUSH	AX
;If last char SCNSOT was called with was the 1st byte of a 2-byte char,
; SCNSOT saved it in TWOBYT so they be both output as one 16-bit character.
;
	MOV AH, byte [TWOBYT] ;If two byte, put first in [AH]
	OR	AH,AH
	JZ	SCNSO1 ;BRIF not second of two bytes
	MOV byte [TWOBYT], 0o0 ;Clear TWOBYT flag
	JMP	SCNSO3 ;Output both bytes at once
SCNSO1:
extern F_EDIT
	TEST byte [F_EDIT], 0o377
	JZ	SCNS1A ;BRIF not in editor, don't collect FF codes
	CMP	AL,255
	JZ	SCNS1B ;BRIF is first of two bytes
SCNS1A:
	JMP	SCNSO2 ;branch if not 1st of 2-bytes
SCNS1B:
	MOV byte [TWOBYT], AL ;save char for next time
	JMP	SCNSOX ;Set two byte flag and return
SCNSO2:
	XOR	AH,AH ;clear high-byte (not 2-byte char)
SCNSO3:	CALL	SCNOL1
SCNSOX:	POP	AX
	POPF
	RET
;SCNSOT level 1
; Outputs AX, destroys AX
;
SCNOL1:
extern LSTCHR
;For IBM Compatibility, the following filter performs the following translations
;    x x x CR x x x    === x x x CR LF x x x
;    x x x CR LF x x x === x x x CR LF x x x
;
;    If (Char = CR) then
;       output CR : output LF
;    else if (char <> LF) or (LSTCHR <> CR) then
;       output char
;    else
;       {eat the LF which follows a CR}
;    LSTCHR = CHR
;
	CMP byte [LSTCHR], ASCCR
	MOV byte [LSTCHR], AL ;save this char for comparison with next
	JNE	NTCRLF ;branch if not LF after CR
	CMP	AL,ASCLF
	JE	RET22 ;eat LF if it follows CR
NTCRLF:
	PUSH	AX
	CALL	SCNOL2 ;output this char
	POP	AX
	CMP	AL,ASCCR
	JNE	RET22 ;if not CR, just output char
	MOV	AX,ASCLF ;else map CR to CR LF
	CALL	SCNOL2
RET22:	RET
;SCNSOT level 2
; Output [AX], destroys AX
;
SCNOL2:
	OR	SI,SI
	JZ	SCNSO8 ;BRIF is not file I/O
	CMP	AL,ASCCR
	JZ	SCNSO8 ;BRIF CR, don't do wrap
	PUSH	AX ;save char to be output
	MOV AL, byte [CSRX]
	OR	AH,AH ;see if 2-byte char
	JZ	SCNSO4 ;BRIF not DBLCHR
	INC	AL ;Need two char posns for DBLCHR
SCNSO4:
	CMP	AL,byte [F_WID+SI] ;Compare posn with file width
	JA	SCNSCR ;Beyond max, force CR
	CMP AL, byte [LINLEN]
	JBE	SCNSO7 ;Within line, go ahead and output
	DEC	AL
	MOV byte [CSRX], AL ;Make sure there's room before end of line
SCNSO7:	POP	AX ;restore char to be output
SCNSO8:
	JMP	SCNOUT ;Output the char in [AX] and return
SCNSCR:	CMP AL, byte [LINLEN]
	JZ	SCNSO7 ;BRIF file width .EQ. device width, use wrap code
	MOV	AX,ASCCR
	CALL	SCNOUT ;Force new line
	MOV	AX,ASCLF
	CALL	SCNOUT
	JMP	SCNSO7 ;Output the character
;POS(X) function
;
global POS
extern SNGFLT
extern LINLEN
POS:	MOV AL, byte [CSRX] ;[AL]=current 1 relative position
	CMP AL, byte [LINLEN]
	JBE	POS0 ;BRIF not beyond end of line
	MOV	AL,0o1 ;Else next char will go in first column
POS0:	JMP	SNGFLT ;return result to user
;SCNGPS - return current file position.
; Entry - SI points to File-Data-Block.
; Exit  - [AH] = current file column. (0-relative)
;         All other registers preserved
;
extern CSRX
SCNGPS:	MOV AH, byte [CSRX]
	PUSHF
	CMP AH, byte [LINLEN]
	JBE	SCNGP1 ;BRIF not beyond edge of screen
	MOV AH, byte [LINLEN] ;Force posn within screen
SCNGP1:	POPF
	DEC	AH ;Make it 0 relative
	RET
;SCNGWD - get device width
; Exit  - [AH] = device width as set by xxxSWD
;         All other registers preserved
;
SCNGWD:
extern LINLEN
	MOV AH, byte [LINLEN]
	OR	SI,SI
	JZ	SCNGWX ;BRIF not file I/O, use device width
	MOV	AH,byte [F_WID+SI] ;Is file I/O, use FDB width
SCNGWX:	RET
;SCNSCW - set device comma width
; Entry - [BX] = new device comma width
; Exit  - SI, DI can be changed.
;         All other registers preserved
;
SCNSCW:	RET
;SCNGCW - get device comma width
; Exit  - [BX] = device comma width as set by xxxSCW
;         All other registers preserved
;
SCNGCW:	RET
