; Auto-converted mechanically from ../gw-basic/gwinit.asm
; Edit the converter or the generated source deliberately; do not hand-wave syntax changes.

; [ This translation created 10-Feb-83 by Version 4.3 ]
; .RADIX  8
%include "dwoem.inc"
; TITLE   GWINIT GW-BASIC-86 Initialization
;Assumes LEN2, FIVMEM, FIVEO, I8086, PURE
%define TRACEF 0o0 ;for Debugging when DEBUG can't be used
%define CPM86 0o0
%define DYNBUF 0o0
%define BSEGSZ 0o0 ;Size of Buffer segment for Misc. Buffers
; .RADIX	10
extern LSTVAR ;Last variable in RAM
extern FILTAB
extern STKLOW
extern MAXMEM
extern TSTACK
extern ERRFLG
extern MEMSIZ
extern TOPMEM
extern SAVSTK
extern FRETOP
extern TXTTAB
extern PROFLG
extern CHNFLG
extern MRGFLG
extern ERRFLG
extern CHNFLG
extern MRGFLG
extern ERRFLG
extern PRMSTK
extern PRMPRV
extern FCERR
extern SNERR
;
%define SWTCHR 0o57 ;DEFAULT SWITCH CHARACTER IS SLASH
extern MAKUPL
extern CNSGET
extern CHRGTR
extern OUTDO
extern LINPRT
extern CRDO
extern OMERRR
extern REASON
extern READY
extern STKINI
extern DCOMPR
extern SYNCHR
extern BUF
extern SNERR
extern FCERR
extern ATN
extern COS
extern MSWFLG
extern MSWSIZ
extern CSWFLG
extern CSWSIZ
extern NEWDS
extern MAPCLC
extern MAPINI
extern INITSA
; SUBTTL  INIT - System Initialization Code
global INIT
extern STROUT
extern HEDING
extern WORDS
extern GWINI
extern BUF
extern KBUF
INIT:
; For safety, a label has been defined in BINTRP.MAC that contains the
; start of the data segment.  That is where the O.S. control block will
; be copied to, so it MUST be first in the DSEG.
; BEGDSG is declared as a code segment external here even though it
; really is in the data segment.  This makes it easier to get the offset
; of the beginning of the data segment from the beginning of the code
; segment.  The beginning of DATASG MUST be within 64K of the beginning
; of CODESG for this to work.  No error will be generated, so be careful.
;
extern BEGDSG ;Beg. of the data segment, offset from CS
extern DW_LOADER_LIMIT
; Flat ROM CARD build: code and data labels are linked in one segment.
; Keep DS/ES/SS in the loaded segment instead of computing an EXE-style DSEG.
push cs
pop dx
mov ax, ds ;SAVE DS FOR EXIT VECTOR
mov ds, dx
mov es, dx
;Initialize the jump vector for exit to MSDOS.  MSDOS 2.0 requires that
; exit is made through the segment prefix table which is located at DS:0.
; For .EXE files, DS is not the same as CS at program initiation time (NOW).
extern CPMEXT
db 0o307
db 0o6
dw CPMEXT ;MOVI CPMEXT,^D0
db 0o0, 0o0 ;            INS86 has 4 params
;            & some may not be words
db 0o220
db 0o243
dw CPMEXT+2 ;NOP         NOP - pad to item 3 of INS86
;MOV  CPMEXT+2,AX
	CLI ;Setting the stack segment and stack
;pointer must be an indivisable
;operation.
db 0o216, 0o322 ;MOV SS,DX
	MOV	BX,BUF+128 ;Use BUF for a temporary stack.
	MOV [MEMSIZ], BX
	MOV	SP,BX
	STI
	XOR	AL,AL ;INITIALIZE PROTECT FLAG
	MOV byte [PROFLG], AL
	MOV byte [MSWFLG], AL ;Init /M: flag
	MOV byte [CSWFLG], AL ;Init /C: flag
extern CNSLEN
extern CONSTR
extern ENDBUF
extern RAMLOW
	mov cx, CNSLEN+3
mov ch, cl ;Get number of bytes to move
	MOV	BX,RAMLOW ;WHERE THE CONSTANTS ARE STORE IN RAM
	MOV	DX,CONSTR ;WHERE THE CONSTANTS ARE HELD IN ROM
MORMOV: ;MOVE ROM INITIALIZATION VALUES TO RAM
db 0o213
db 0o362
db 0o56
db 0o254 ;CODE SEGMENT FETCH
	MOV	byte [BX],AL ;STORE IT AWAY IN RAM
	INC	BX
	INC	DX
	DEC	CH
	JNZ	MORMOV ;IF NOT, KEEP SHOVELING THEM DOWN
	STI
extern SCNIPL
	CALL	SCNIPL ;Screen editor initialization
	CALL	GWINI ;OEM specific initialization
extern SNDRST
	CALL	SNDRST ;reset sound queue, disable speaker
extern GIOINI
	CALL	GIOINI
	MOV BX, [MEMSIZ]
	MOV [TOPMEM], BX
	MOV	BX,KBUF-1 ;INITIALIZE KBUF-1 WITH A COLON
	MOV	byte [BX],":" ;DIRECT INPUTS RESTART OK.
	CALL	STKINI ;REALLY SET UP INIT'S TEMPORARY STACK
;
;       Check CP/M Version Number
extern CPMREA
	MOV	BX,34*256+33+0 ;2.x Read / Write
CPMVR1:	MOV [CPMREA], BX ;Save Read/Write Codes
extern CNTOFL
	XOR	AL,AL
	MOV byte [CNTOFL], AL
extern ENDBUF
	MOV byte [ENDBUF], AL ;MAKE SURE OVERRUNS STOP
extern DSEGZ
	MOV byte [DSEGZ], AL ;(DS) LOCATED ZERO
	MOV byte [CHNFLG], AL ;MAKE SURE CHAINS AND MERGES
	MOV byte [MRGFLG], AL ;DONT TRY TO HAPPEN
	MOV byte [ERRFLG], AL ;DON'T ALLOW EDIT TO BE CALLED ON ERRORS
extern TEMPST
extern TEMPPT
	MOV	BX,TEMPST
	MOV [TEMPPT], BX
	MOV	BX,PRMSTK ;INITIALIZE PARAMETER BLOCK CHAIN
	MOV [PRMPRV], BX
; SUBTTL Read Operating System Parameters (memsiz etc.)
; THE FOLLOWING CODE SCANS A CP/M COMMAND LINE FOR BASIC.
; THE FOLLOWING SWITCHES ARE RECOGNIZED:
;
;       /M:<TOPMEM>
;       /F:<FILES>
;       /S:<MAX RECORD SIZE>
;       /C:<COM INPUT QUEUE SIZE>
;
extern CPMMEM
	MOV	BX,word [DW_LOADER_LIMIT] ;ROM CARD approved work-area byte limit
	MOV	[MEMSIZ],BX ;USE AS DEFAULT
	MOV	[MAXMEM],BX ;set MAX DS size for CLEAR statement
extern DSEGZ
	MOV	BX,DSEGZ ;IN THE DATA SEGMENT
	MOV [TEMP8], BX ;SO IF RE-INITAILIZE OK
extern CPMWRM
TBUFF equ CPMWRM+128 ;WHERE CP/M COMMAND BUFFER IS LOCATED
	MOV	byte [TBUFF],0 ;ROM CARD launch has no CP/M/DOS command tail
	MOV	BX,TBUFF ;POINT TO FIRST CHAR OF COMMAND BUFFER
	MOV	AL,byte [BX] ;WHICH CONTAINS # OF CHARS IN COMMAND
	OR	AL,AL ;IS THERE A COMMAND?
	MOV [TEMP8], BX ;SAVE POINTER TO THIS ZERO
	JNZ	??L000
	JMP	DONCMD ;NOTHING IN COMMAND BUFFER
??L000:
	MOV	CH,byte [BX] ;AND [B]
	INC	BX ;POINT TO FIRST CHAR IN BUFFER
TBFLP:	MOV	AL,byte [BX] ;GET CHAR FROM BUFFER
	DEC	BX ;BACK UP POINTER
	MOV	byte [BX],AL ;STORE CHAR BACK
	INC	BX ;NOW ADVANCE CHAR TO ONE PLACE
	INC	BX ;AFTER PREVIOUS POSIT.
	DEC	CH
	JNZ	TBFLP ;KEEP MOVING CHARS
	DEC	BX ;BACK UP POINTER
ENDCMD:	MOV	byte [BX],0 ;STORE TERMINATOR FOR CHRGET (0)
	MOV [TEMP8], BX ;SAVE POINTER TO NEW ZERO (OLD DESTROYED)
	MOV	BX,TBUFF-1 ;POINT TO CHAR BEFORE BUFFER
	CALL	CHRGTR ;IGNORE LEADING SPACES
	OR	AL,AL
	JNZ	??L001
	JMP	DONCMD ;END OF COMMAND
??L001:
	CMP	AL,SWTCHR ;IS IT A SLASH
	JZ	FNDSLH ;YES
	DEC	BX ;BACK UP POINTER
	MOV	byte [BX],34 ;STORE DOUBLE QUOTE
	MOV [TEMP8], BX ;SAVE POINTER TO START OF FILE NAME
	INC	BX ;BUMP POINTER
ISSLH:	CMP	AL,SWTCHR ;OPTION?
	JZ	FNDSLH ;YES
	CALL	CHRGTR ;SKIP OVER CHAR IN FILE NAME
	OR	AL,AL ;SET CC'S
	JNZ	ISSLH ;KEEP LOOKING FOR OPTION
	JMP	DONCMD ;THATS IT
FNDSLH:	MOV	byte [BX],0 ;STORE TERMINATOR OVER "/"
SCANSW:
	CALL	CHRGTR ;GET CHAR AFTER SLASH
SCANS1:
	CALL	MAKUPL ;CONVERT SWITCH TO UPPER CASE
	CMP	AL,"S" ;IS IT /S: ? (SET MAX RECORD SIZE)
	JZ	WASS
	CMP	AL,"C" ;COM buffer size option
	JZ	WASC
	CMP	AL,"F" ;FILES OPTION
	JZ	WASF
	CMP	AL,"M" ;MEMORY OPTION
	JZ	??L002
	JMP	SNERR ;Branch if couldn't recognize option
??L002:
	CALL	GETVAL ;[DX]=requested MEMSIZ
	MOV [MSWSIZ], DX ;Record memory request
	MOV	AL,0o377
	MOV byte [MSWFLG], AL ;Set /M: option flag
FOK:	DEC	BX ;RESCAN LAST CHAR
	CALL	CHRGTR ;BY CALLING CHRGET
	JZ	DONCMD ;END OF COMMAND
	CALL	SYNCHR
db SWTCHR ;SLASH SHOULD FOLLOW
	JMP	SCANS1 ;SCAN NEXT SWITCH
WASC:	MOV	AL,0o377
	MOV byte [CSWFLG], AL ;Set /C: option flag
	CALL	GETVAL ;Get COM request to D,E
	MOV [CSWSIZ], DX ;Record for future memory map calc.
	JMP	FOK
WASS: ;GIO has dynamic record size
WASF: ;GIO has dynamic number of files
	CALL	GETVAL ;Get value
	JMP	FOK ;Any value OK (and ignored)
GETVAL:	CALL	CHRGTR ;skip M,F or S
	CALL	SYNCHR
db ":" ;MAKE SURE COLON FOLLOWS
	JMP	CNSGET ;[DE]=VALUE FOLLOWING COLON
extern TEMP8 ;POINTER TO BASIC LOAD FILE
ERRCMD:
DONCMD:
	; Flat ROM CARD build keeps the startup data map in place.
;Now copy the command line file name (if there is one) to BUF
;Move required since DS: segment header will be overwritten when the
;DS: is coppied to the new DS: location.
	MOV BX, [TEMP8] ;Load address of command line file name
	MOV	DX,BUF ;Destination address
	MOV [TEMP8], DX ;New command line buffer address
NXTBYT:	MOV	AL,byte [BX] ;File name character
	XCHG	BX,DX
	MOV	byte [BX],AL ;Store at BUF
	INC	BX
	XCHG	BX,DX
	INC	BX
	OR	AL,AL ;Test for zero byte terminator
	JNZ	NXTBYT ;Get next file name character
; SUBTTL Allocate Space for Disk Buffers
; Disk Initialization Routine
; setup  file info blocks
; the number of each and information for
; getting to pointers to each is stored. no locations are
; initialized, this is done by nodsks, first closing all files.
; the number of files is the file pointer table
;
	MOV BX, [MEMSIZ] ;get size of memory
	DEC	BX ;always leave top byte unused because
;val(string) makes byte in memory
;beyond last char of string=0
	MOV [MEMSIZ], BX ;save in real memory size
	DEC	BX ;one lower is stktop
	PUSH	BX ;save it on stack
; SUBTTL INIT TXTAB, STKTOP, VARTAB, MEMSIZ, FRETOP, STREND
; Memory map for GW-BASIC:
;
;               [MAXMEM]--}     highest byte of physical memory in system
;                               user managed memory
;               [TOPMEM]--}     highest byte available to BASIC
;                               basic stack
;               [STKLOW]--}     lowest byte available for STACK
;                           +--}FDB---}[STKEND] {end of chain}
;                           +---FDB{--+
;               [FILTAB]-------}FDB---+ (FILTAB points to lowest byte of lowest FDB)
;                               0 (1 byte string space terminator for VAL)
;               [MEMSIZ]--}     highest byte of IN-USE string space
;               [FRETOP]--}     highest byte of FREE string space
;               [STREND]--}     lowest  byte of FREE string space
;               [ARYTAB]--}     lowest  byte of Array Table
;               [VARTAB]--}     lowest  byte of Variable Table
;               [TXTTAB]--}     lowest  byte of BASIC Program Text
;
; note:  when [FILTAB] = [STKLOW], no FDB's are allocated.
;        when [FRETOP] = [MEMSIZ], IN-USE string space is empty.
;        when [SP] = [STKLOW], STACK is full.
; At this point, MEMSIZ-1 is on stack, [HL]=TXTTAB-1
;
	MOV	BX,LSTVAR ;LSTVAR resides in last linked module with DS:
	MOV [TXTTAB], BX ;save bottom of memory
	POP	DX ;GET CURRENT MEMSIZ
	MOV	AL,DL ;WANT AN EVEN STACK PTR. FOR 8086
	AND	AL,254 ;SO WE'LL CLEAR LOW BIT
	MOV	DL,AL ;OF THE STACK PTR.
	MOV	AL,DL ;CALC TOTAL FREE/8
	SUB	AL,BL
	MOV	BL,AL
	MOV	AL,DH
	SBB	AL,BH
	MOV	BH,AL
	JAE	??L003
	JMP	OMERRR
??L003:
	MOV	CL,3 ;SHIFT RIGHT THREE BITS (DIVIDE BY 8)
db 0o323, 0o353 ;SHR BX,CL
	MOV	AL,BH ;SEE HOW MUCH
	CMP	AL,2 ;IF LESS THAN 512 USE 1 EIGHTH
	JB	SMLSTK
	MOV	BX,512
SMLSTK:	MOV	AL,DL ;SUBTRACT STACK SIZE FROM TOP MEM
	SUB	AL,BL
	MOV	BL,AL
	MOV	AL,DH
	SBB	AL,BH
	MOV	BH,AL
	JAE	??L004
	JMP	OMERRR
??L004:
	MOV [STKLOW], BX ;Save lowest legal value for [SP]
	MOV [FILTAB], BX ;Initially there are no FDB's
	DEC	BX
	MOV	byte [BX],0 ;String space should be terminated by 0 for VAL
	DEC	BX
	MOV [MEMSIZ], BX ;Save highest byte to be used by strings
	XCHG	BX,DX
	MOV [TOPMEM], BX
	MOV [FRETOP], BX ;REASON USES THIS...
	MOV	SP,BX ;SET UP NEW STACK
	MOV [SAVSTK], BX
	MOV BX, [TXTTAB]
	XCHG	BX,DX
	CALL	REASON
extern FREFLG ;Print free bytes flag
	XOR	AL,AL
	MOV byte [FREFLG], AL ;Clear to print free bytes message
extern GETHED ;OEM heading retrieval routine
extern KEYSW ;Function key on flag
	MOV	AL,255 ;if heading is printed, display Fn keys also
	MOV byte [KEYSW], AL
	CALL	GETHED ;Get OEM specific portion of the heading
	JNZ	PRNTIT ;Always print the heading option
	PUSH	BX ;Print heading if no program option
	MOV BX, [TEMP8] ;Get pointer to file or 0
	MOV	AL,byte [BX] ;Test for file on command line
	POP	BX ;Retrieve OEM heading pointer
	OR	AL,AL
	JZ	PRNTIT ;No program - go print heading
	MOV byte [FREFLG], AL ;Set to inhibit free bytes message
	XOR	AL,AL ;Turn keys off if there is a program
	MOV byte [KEYSW], AL ; otherwise allow OEM default
	JMP	PRNTND ;Skip heading
PRNTIT:
	CALL	STROUT ;Print it
	MOV	BX,HEDING ;GET HEADING ("BASIC VERSION...")
	CALL	STROUT ;PRINT IT
PRNTND:
extern SKEYON
	MOV AL, byte [KEYSW] ;Get function key display switch
	OR	AL,AL ;Keys need to be turned on?
	JNZ	??L005
	JMP	KEYSOF ;Leave keys off
??L005:
	XOR	AL,AL
	MOV byte [KEYSW], AL ;Show current status of keys
	CALL	SKEYON ;Set function key display on
KEYSOF:	MOV	AL,0o377
	MOV byte [INITFG], AL ;Set the initialization complete flag
;indicating errors no longer result in an exit
;to the OS
	JMP	INITSA
;CMDERR This routine is called when an error is detected before the
;       completion of initialization (before INITFG is set to non-zero).
;       CMDERR performs the following:
;               1. Write the heading
;               2. Write an error message implicating the command line.
;               3. Exit to the operating system through SYSTME
extern INITFG
extern SYSTME
extern CERMSG
global CMDERR
CMDERR:	MOV	BX,HEDING ;Get heading ("BASIC VERSION...")
	CALL	STROUT ;Print it
	MOV	BX,CERMSG ;Get command error message
	CALL	STROUT ;Print it
	JMP	SYSTME ;Exit to the OS
global DOL_LAST
DOL_LAST equ $
global LASTWR
LASTWR equ $
