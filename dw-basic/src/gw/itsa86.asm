; Auto-converted mechanically from ../gw-basic/itsa86.asm
; Edit the converter or the generated source deliberately; do not hand-wave syntax changes.

; [ This translation created 10-Feb-83 by Version 4.3 ]
; .RADIX  8
%include "dwoem.inc"
; TITLE   ITSA86 - Resident Initialization for I8086
; COMMENT *
;
; --------- --- ---- -- --------- -----------
; COPYRIGHT (C) 1982 BY MICROSOFT CORPORATION
; --------- --- ---- -- --------- -----------
;
;         by Len Oorthuys Microsoft Corp.
;************************************************************************
;*                                                                      *
;*  NOTE: Any code linked after this module is discarded after          *
;*        Initialization of BASIC.                                      *
;*                                                                      *
;************************************************************************
%include "gio86u.inc"
%define CPM86 0o0
%define TETRA 0o0 ;Save DS in DATSEG(defined in CS and
;   used by interrupt routine).
%include "msdosu.inc"
extern TEMP8
extern TXTTAB
extern NODSKS
extern LRUN
extern READY
global WORDS
WORDS: db " Bytes free" ;WORDS
db 0o0
; SUBTTL  INITSA
global INITSA
INITSA:
	CALL	NODSKS
	CALL	MAPINI ;Init the new memory map
	MOV BX, word [TXTTAB]
	DEC	BX
	MOV	word [BX+0o0],0
	MOV BX, word [TEMP8] ;POINT TO START OF COMMAND LINE
	MOV	AL,byte [BX+0o0] ;GET BYTE POINTED TO
	OR	AL,AL ;IF ZERO, NO FILE SEEN
	JZ	GREADY
	JMP	LRUN ;TRY TO RUN FILE
GREADY:	JMP	READY
;BASVAR - Retrieve or Modify BASIC Internal Data Locations
;This routine provides a method to retrieve or modify certain BASIC internal
;data locations.  This routine is provided as support for PEEK and
;POKE filsters.  These data items have been documented to IBM GW BASIC users
;in the IBM Technical Reference Manual.
;
;Entry - AX = Value to set (if PSW.C set)
;        BX = 0 for current program line number
;             1 for last program line containing an error
;             2 for address of user program text
;             3 for address of user variable table
;        PSW.C set indicates to write the variable
;        PSW.C reset indicates to read the variable
;Exit  - AX = value of appropriate variable
;        BX modified
;
extern CURLIN
extern ERRLIN
extern TXTTAB
extern VARTAB
global BASVAR
BVTAB: dw CURLIN
dw ERRLIN
dw TXTTAB
dw VARTAB
BASVAR:
	PUSHF
	SHL	BX,0o1 ;make word offset
	POPF ;preserve PSW.C (input parameter)
	MOV	BX,word [BVTAB+BX] ;Get address of appropriate variable
	JNB	BASVRD ;Performing read function
	MOV	word [BX+0o0],AX ;Perform write function
BASVRD:	MOV	AX,word [BX+0o0] ;Perform read function
	RET
; SUBTTL  Initialization Support Routines
extern CSWFLG
extern CSWSIZ
extern MSWFLG
extern MSWSIZ
extern NEWDS
extern STKLOW
extern MEMSIZ
extern TOPMEM
extern SAVSEG
extern MAXMEM
extern FILTAB
extern FREFLG ;BYTES FREE message flag
extern CLEARC
extern OMERR
extern SETCBF ;OEM Set COM Buf (size & location)
extern LINPRT
extern STROUT
extern CRDO ;COM
extern CPMMEM
global MAPCLC
global MAPINI
;MAPINI - Set up the final memory map.
;Entry  - NEWDS  = final DS:
;         MSWSIZ = final MAXMEM
;Exit   - DS: and stack moved.
;
MAPINI:
; Flat ROM CARD build: data is already in the linked load segment.
	RET
MAPINI_ORIGINAL:
;Move the stack to the end of the new memory map
	POP	BX ;Return address
	CLI ;disable external interrupts
; while changing memory map
	MOV	AX,word [NEWDS]
	MOV	SS,AX
	MOV SP, word [MSWSIZ] ;
	PUSH	BX ;Return address
;Move the data segment
	MOV	ES,AX ;NEWDS
	XOR	SI,SI
	MOV CX, word [TXTTAB] ;Amount of memory to move
	SHR	CX,0o1 ;In words
	CLD
	MOV	BX,DS
	CMP	AX,BX ;Test for direction of copy
	JB	BLKCPY ;brif destination is below source
	STD ;Copy up
	MOV SI, word [TXTTAB] ;starting from top
BLKCPY:
	MOV	DI,SI
 REP	MOVSW
;Set new data segment
	MOV	DS,AX ;NEWDS
extern SEGINI
	CALL	SEGINI
	MOV	AX,DS
	MOV word [SAVSEG], AX ;For PEEK/POKE
	STI ;enable external interrupts
;Insure zeros at TXTTAB
	MOV BX, word [TXTTAB]
	MOV	word [BX+0o0],0
	MOV	byte [BX+0o2],0 ;Three zeros necessary
;Call CLEARC to set up stack and finalize the memory map
	MOV AX, word [MSWSIZ]
;Make sure that [TXTTAB]+<stack size>+32 does not overflow memory
	MOV BX, word [TOPMEM]
	SUB BX, word [STKLOW] ;BX=stack size
	JBE	GOMERR ;BRIF illegal stack(0 or less bytes)
	NEG	BX
	ADD	BX,AX ;BX=new stack bottom
	JNB	GOMERR ;BRIF MSWSIZ is less than stack size
	SUB	BX,32 ;Leave a little room for a program
	JB	GOMERR ;BRIF no room left
	CMP BX, word [TXTTAB] ;Is new MAXMEM big enough?
	JBE	GOMERR ;BRIF new MAXMEM smaller than data area
MAXRQ1:	MOV	BX,AX
	SUB BX, word [MAXMEM] ;Calc. seg. size difference
	MOV word [MAXMEM], AX ;Memory request
	ADD word [TOPMEM], BX
	ADD word [STKLOW], BX
	ADD word [FILTAB], BX
	ADD word [MEMSIZ], BX
	POP	BX ;Return address (BX saved by CLEARC)
	CALL	CLEARC
	PUSH	BX ;Return address (BX saved by CLEARC)
;Set up program segment prefix
	MOV	DX,DS
	MOV	AH,38 ;Function ^H26
	INT	33 ;MSDOS function request
;Print free bytes message
	TEST byte [FREFLG], 255 ;BYTES FREE message flag
	JNZ	MAPINX ;Exit - message not to be printed
	MOV BX, word [MEMSIZ]
	SUB BX, word [TXTTAB]
	DEC	BX
	DEC	BX
	CALL	LINPRT ;PRINT # OF BYTES FREE
	MOV	BX,WORDS ;TYPE THE HEADING
	CALL	STROUT ;"BYTES FREE"
	CALL	CRDO ;PRINT CARRIAGE RETURN
MAPINX:	RET
GOMERR:	JMP	OMERR
; SUBTTL  End of the New CS:
;All code loaded after this label is resident only until routine MAPINI
;initializes the new memory map.
CSEND:
;MAPCLC - Calculate the final memory map limits.
;Entry  - CSWFLG = Flag nonzero when /C: option exists
;         CSWSIZ = /C: option size
;         MSWFLG = Flag nonzero when /M: option exists
;         MSWSIZ = /C: option size
;Exit   - NEWDS  = Final DS: address
;         MSWSIZ = Highest memory address (future MAXMEM)
;
MAPCLC:
; Flat ROM CARD build: keep current DS and the loader-provided memory limit.
	MOV	AX,DS
	MOV	word [NEWDS],AX
	MOV	AX,word [MEMSIZ]
	MOV	word [MSWSIZ],AX
	RET
MAPCLC_ORIGINAL:
;Validate/get COM buffer size
	MOV	DX,CSEND ;Location of COM buffer (New end of CS:)
	ADD	DX,15 ;Round to next higher paragraph
	MOV	CL,4
	SHR	DX,CL
	MOV	CX,CS
	ADD	CX,DX ;Segment offset of COM buffer
	MOV DX, word [CSWSIZ] ;Segment size request
	TEST byte [CSWFLG], 255 ;Was there a /C: opt - PSW.Z for SETCBF
	CALL	SETCBF ;Report buffer size/loc
	JB	GOMERR ; & validate size
	MOV word [CSWSIZ], DX ;COM buffer size
;Calculate NEWDS (New DS:)
; DX  - COM buffer size
; NEWDS = (D+15/16) + DS:
	ADD	DX,15 ;Round off to paragraph
	SHR	DX,0o1
	SHR	DX,0o1
	SHR	DX,0o1
	SHR	DX,0o1
	ADD	DX,CX ;Skip COM buffer
	JO	GOMERR
	MOV word [NEWDS], DX
;Validate the /M option or calculate the maximum possible MAXMEM
;1. Calcualte maximum MAXMEM based on the NEWDS
;2. If there was no /M option then goto 4
;3. Compare /M to the maximum and declare an error if /M is larger
;4. Save the new memory size as MSWSIZ
	PUSH	BX ;Save text pointer
	MOV	BX,word [CPMMEM]
	SUB	BX,DX ;Avail paragraphs
	JB	GOMERR
	MOV	DX,65535/16 ;Max usable paragraphs
	CMP	BX,DX
	JB	MAXREQ ;More than enough
	MOV	BX,DX
MAXREQ:	MOV	CL,4
	SHL	BX,CL ;DX has valid maximum bytes
	TEST byte [MSWFLG], 255
	JZ	NOMOPT ;No memory option
	MOV DX, word [MSWSIZ] ;Get /M: size
	CMP	BX,DX
	JB	GOMERR ;Not enough for request
	MOV	BX,DX
NOMOPT:	MOV word [MSWSIZ], BX ;New MAXMEM
;       ADDI    BX,^D256
;       JB      MAXRQ1                  ;BRIF very large MAXMEM, value OK
;       CMP     BX,TXTTAB               ;Is new MAXMEM big enough?
;       JBE     GOMERR                  ;BRIF new MAXMEM smaller than data area
	POP	BX
	RET
;SEGOFF     Convert end of memory segment to offset from current DS
;
;   On entry:   BX=last segment in memory
;               DS=current data segment
;
;   On exit:    BX=offset from current segment to paragraph specified by BX
;               Other registers unchanged, flags modified
;
global SEGOFF
extern OMERR
SEGOFF:	PUSH	CX
	MOV	CX,DS
	SUB	BX,CX ;[BX]=number of paragraphs free for DSEG
	JBE	SGOFER ;BRIF last segment is less than current
	MOV	CX,0o7777 ;[CX]=max num of paragraphs BASIC could use
	CMP	BX,CX
	JBE	LESS64 ;Brif less than 64k bytes available
	MOV	BX,CX ;don't need more than 64k bytes
LESS64:
	MOV	CL,0o4
	SHL	BX,CL ;convert paragraphs to bytes
	POP	CX ;restore caller's CX
	RET
SGOFER:	JMP	OMERR
