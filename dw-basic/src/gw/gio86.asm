; Auto-converted mechanically from ../gw-basic/gio86.asm
; Edit the converter or the generated source deliberately; do not hand-wave syntax changes.

; [ This translation created 10-Feb-83 by Version 4.3 ]
; .RADIX  8
%include "dwoem.inc"
; TITLE   GIO86   - BASIC-86 Interpreter Device Independent I/O Module
; COMMENT *
;
; --------- --- ---- -- ---------
; COPYRIGHT (C) 1982 BY MICROSOFT
; --------- --- ---- -- ---------
;
;         T. Corbett      Microsoft Inc.
;
%include "gio86u.inc"
%define CPM86 0o0
%define IBMCSR IBMLIK ;IBM Compatible Cursor Handling
%include "msdosu.inc"
extern DEVPTR
extern DEVTBL
extern DEVINI
extern DEVTRM
extern NLONLY
extern RUNFLG
extern FILMOD
extern FILDEV
extern FILNM
extern FILEXT
extern PTRFIL
extern FILTAB
extern STKLOW
extern SNERR
extern FCERR
extern FRESTR
extern GETYPR
extern DERBFM
extern DERBFN
extern DERFAO
extern DERFNO
extern DERIFN
extern DERDNA
extern DERFDR
; SUBTTL OPEN statement
global OPEN
extern GETBYT
extern GWWID
; OPEN Statement
; Syntax:
;  OPEN filespec FOR mode AS fnum [LEN=random-record-length]
;  OPEN mode,fnum,filespec[,random-record-length]
;
OPEN:	CALL	FRMEVL ;read the file mode or filename
	MOV	AL,byte [BX+0o0] ;get terminator
	CMP	AL,0o54 ;followed by comma? (then
; non-spcdsk open...)
	JNZ	NOTNSO ;nope, must be SPCDSK form
	PUSH	BX ;save the text pointer
	CALL	FRESTR ;free string temp & check string
	MOV	AL,byte [BX+0o0] ;make sure its not a null string
	OR	AL,AL
	JZ	ERBFM0 ;if so, "bad file mode"
	INC	BX
	MOV	BX,word [BX+0o0] ;[BX] points at mode character
	MOV	AL,byte [BX+0o0] ;[A]=mode character
	AND	AL,-0o1-" " ;force to upper case
	MOV	DH,MD_SQO ;assume its "O"
	CMP	AL,"O" ;is it?
	JZ	HAVMOD ;[D] has correct mode
	MOV	DH,MD_SQI ;assume sequential
	CMP	AL,"I" ;is it?
	JZ	HAVMOD ;[D] says sequential input
	MOV	DH,MD_APP ;append?
	CMP	AL,"A" ;test
	JZ	HAVMOD ;allow it
	MOV	DH,MD_RND ;must be random
	CMP	AL,"R"
	JNZ	ERBFM0 ;if not, no match so "bad file mode"
HAVMOD:	MOV byte [FILMOD], DH ;set file mode
	POP	BX ;get back the text pointer
	CALL	SYNCHR
db 0o54 ;skip comma before file number
HAVMD1:	CALL	POFNUM ;[AL]=the file number
	PUSH	AX ;save file number
	CALL	SYNCHR
db 0o54 ;skip comma before name
	CALL	NAMSCN ;parse filename setting FILDEV, FILNM, FILEXT
	CALL	PORLEN ;parse reclen parm
	JMP	OPEN1 ;branch to common code (with Fnum on stack)
ERBFM0:	JMP	DERBFM ;bad file mode error
NOTNSO:	CALL	NAMSC1 ;parse filename setting FILDEV, FILNM, FILEXT
	MOV	DH,MD_RND ;Assume there is no FOR, in which
;case the default mode is random.
	MOV	AL,byte [BX+0o0]
	CMP	AL,TOK_FOR ;Is there a 'FOR'?
	JNZ	GOTMOD ;No, better see 'AS'
	CALL	CHRGTR
	CMP	AL,TOK_INPUT ;Input mode?
	MOV	DH,MD_SQI ;Assume it is
	JZ	GOTMD1 ;Yes, have file mode
	CMP	AL,"A" ;test
	JNE	NTAPP ;branch if not append (might be OUTPUT)
	CALL	SYNCHR
db "A"
	CALL	SYNCHR
db "P"
	CALL	SYNCHR
db "P"
	CALL	SYNCHR
db "E"
	CALL	SYNCHR
db "N"
	CALL	SYNCHR
db "D"
	MOV	DH,MD_APP ;append file mode
	JMP	GOTMOD ;allow it
NTAPP:
	CALL	SYNCHR
db "O" ;it must be OUTPUT
	CALL	SYNCHR
db "U"
	CALL	SYNCHR
db "T"
	CALL	SYNCHR
db "P"
	CALL	SYNCHR
db "U"
	CALL	SYNCHR
db "T"
	MOV	DH,MD_SQO
	JMP	GOTMOD
GOTMD1:	CALL	CHRGTR
GOTMOD:	MOV byte [FILMOD], DH ;set file mode
	CALL	SYNCHR
db "A"
	CALL	SYNCHR
db "S" ;Must have 'AS'
	CALL	POFNUM ;[AL]=file #
	PUSH	AX ;save file#
	CALL	PNRLEN ;parse new reclen parameter
OPEN1:	DEC	BX
	CALL	CHRGTR
	JNZ	SNERR1 ;error if not end-of-statement
	POP	AX ;[AL]=file number
	CALL	OPNFIL ;branch to general file-open code
	JMP	FINPRT ;reset PTRFIL to 0 (keyboard/crt)
;PORLEN - parse old variable record length field
; Entry - [FILMOD]=file mode
; Exit  - [CX]=reclen if reclen parm included, else 0
;
PORLEN:	CALL	PRLENC
	JZ	PRLENX
	CALL	SYNCHR
db 0o54
	JMP	VARECS
;PNRLEN - parse new variable record length field
; Entry - [FILMOD]=file mode
; Exit  - [CX]=reclen if reclen parm included, else 0
;
PNRLEN:	CALL	PRLENC
	JZ	PRLENX
	CALL	SYNCHR
db 0o377 ;else parse "LEN=record-length"
	CALL	SYNCHR
db TOK_LEN ;LEN is a 2-byte token
	CALL	SYNCHR
db EQULTK
extern INTID2
VARECS:	CALL	INTID2 ;[DX]=record size (0..32767)
	MOV	CX,DX ;return it in CX
	OR	CX,CX
	JZ	FCERR1 ;0 is illegal value
PRLENX:	RET
;PRLENC - see if reclen parm is expected
;
PRLENC:
	MOV	CX,0o0 ;indicates reclen parm not included
	MOV AL, byte [FILMOD] ;[AL]=requested file mode
	CMP	AL,MD_RND
	JNZ	NOLEN ;branch if file mode is not RANDOM
	DEC	BX ;decrement text pointer
	CALL	CHRGTR ;re-get last character parsed
	JZ	NOLEN ;branch if end-of-statement
	MOV	CL,0o1 ;indicates reclen parm included
NOLEN:	OR	CX,CX ;set NZ if reclen parm included
	RET
FCERR1:	JMP	FCERR ;function call error
SNERR1:	JMP	SNERR ;syntax error
; SUBTTL CLOSE, WIDTH Statements
global CLOSE
; CLOSE Statement
;  Syntax: CLOSE [[#]n [,[#]n ...]]
;
CLOSE:	JNZ	CLOS1 ;branch if statement has parm
	JMP	CLSALL ;close all files if no parm given
CLOS1:	CMP	AL,"#"
	JNZ	NOLBS ;branch if no #
	CALL	CHRGTR ;skip #
NOLBS:
	CALL	GETBYT ;[AL]=file#
	CALL	CLSFIL ;close file [AL] and return
	DEC	BX
	CALL	CHRGTR
	CMP	AL,0o54 ;check for comma
	JNZ	RET6 ;branch if end of file list
	CALL	CHRGTR ;skip comma
	JMP	CLOS1 ;close next file in list
global WIDTHS
; WIDTH Y[,X]/[#fnum,]/[device,]   Statement
; Entry - (BX) = text pointer
;
WIDTHS:	CMP	AL,"#"
	JZ	FILWID ;Is files WIDTH specification
	CMP	AL,0o54
	JZ	CRTWD1 ;branch if Comma
	CMP	AL,TOK_LPRINT
	JNZ	NOTLPR ;branch if not WIDTH LPRINT
	CALL	CHRGTR ;skip LPRINT
	MOV	AL,DOL__LPT1
	JMP	ITSWLP
NOTLPR:
	PUSH	BX ;save Text Pointer in case CRT width
	CALL	FRMEVL ;evaluate string or number
	CALL	GETYPR
	JNZ	CRTWD ;brif not string argument. CRT width
	POP	SI ;discard old text pointer
	PUSH	BX ;save text pointer
	CALL	FRESTR ;release temporary string descriptor
;[BX] points to string descriptor
	MOV	CL,byte [BX+0o0]
	MOV	CH,0o0 ;[CX]=length of string
	MOV	SI,word [BX+0o1] ;SI points to start of string
	CALL	PARDEV ;AL=-(device number)
	POP	BX ;restore text pointer
	PUSH	AX ;save device id
	CALL	SYNCHR
db 0o54
	POP	AX ;[AL]=device id
ITSWLP:
	PUSH	AX ;save device id
	CALL	GETWDT ;[DL]=width
	POP	AX ;[AL]=device id
	CALL	CDEVID ;[DI]=device dispatch table offset
	JZ	ERIFN0 ;illegal file name if device=disk
	MOV	AH,G_SWD ;select set-width function
	JMP	TBLDSP ;dispatch function [AH] for device [DI]
FILWID:	CALL	PRFNUM ;[AL]=file number
	CALL	FDBPTR ;[SI] points to file-data-block
	JZ	ERFNO1 ;branch if file not opened
	PUSH	SI
	CALL	SYNCHR
db 0o54
	CALL	GETWDT ;[AL]=width (1..255)
	POP	SI ;SI points to file data block
	MOV	byte [F_WID+SI],AL ;save width in FDB
RET6:	RET
GETWDT:	CALL	GETBYT
	OR	AL,AL
	JZ	FCERR2 ;width of 0 is illegal
	RET ;return if width is between 1 and 255
CRTWD:	POP	BX ;restore text pointer
CRTWD1:	JMP	GWWID
FCERR2:	JMP	FCERR
ERIFN0:	JMP	DERIFN ;illegal file name error
ERFNO1:	JMP	DERFNO ;file not open error
ERDNA1:	JMP	DERDNA ;Device not available
; SUBTTL BSAVE, BLOAD Statements
global BLOAD
global BSAVE
extern GETBYT
extern SYNCHR
extern MAKINT
extern CHRGTR
extern SNERR
extern PRODIR
extern SAVLEN
extern SAVSEG
; BSAVE Statement - Save memory image to file
; Syntax: BSAVE name, start-adr, byte-count
;
BSAVE:	CALL	BPARMS ;parse parms
	INC	AL
	JNZ	SNERR2 ;Error if 1 or no parms.
	PUSH	BX ;save text pointer
	PUSH	CX ;SAVE start-adr
	MOV	AL,MD_SQO ;open file 0 for output
	CALL	NULOPM
	CALL	SCDBIN ;set file-code to binary
	MOV	AL,BSVFID ;output binary file ID
	CALL	OUTDO ;output to file
	MOV AX, word [SAVSEG] ;DX=Segment from DEF SEG statement
	CALL	OUT16 ;write segment adr to file
	POP	AX ;[AX]=start-adr
	PUSH	AX
	CALL	OUT16 ;output start adr
	MOV AX, word [SAVLEN] ;[DX]=number of bytes
	MOV	CX,AX ;[CX]=length
	CALL	OUT16 ;output end adr + 1
	POP	BX ;[BX]=start-adr
	MOV DX, word [SAVSEG] ;DX=Segment adr
	CALL	OUTBLK ;output binary
	JMP	LODEND ;exit
SNERR2:	JMP	SNERR
; BLOAD Statement - load memory image from disk
; Syntax: BLOAD name[, start-adr]
;
BLOAD:
	CALL	BPARMS ;Get Parms if any.
	OR	AL,AL
	JZ	BLODP ;Will set -1 if start-adr only given.
	INC	AL
	JZ	SNERR2 ;error if 2 parms given
BLODP:	DEC	AL ;AL=1: no start-adr parm, -1: start-adr parm
	PUSH	BX ;save text pointer
	PUSH	AX ;save Parm Switch
	PUSH	CX ;save start-adr parm
	MOV	AL,MD_SQI
	CALL	NULOPM ;Open File 0 for INPUT
	CALL	SCDBIN ;set file code to binary
	CALL	INCHR ;[A]=1st byte from file
	CMP	AL,BSVFID ;make sure this was created by BSAVE
	JNZ	ERBFM2 ;else BAD FILE MODE
	POP	CX ;[CX]=start-adr parm
	CALL	INP16 ;[AX]=next 16 bits from file
	MOV	DX,AX ;[DX]=default segment
	CALL	INP16 ;[AX]=next 16 bits from file
	MOV	BX,AX ;[BX]=default start-adr
	POP	AX ;AL=1: no start-adr parm, -1: start-adr parm
	DEC	AL
	JZ	DEFSAD ;branch if no start-adr parm given
	MOV DX, word [SAVSEG] ;[DX]=segment parm
	MOV	BX,CX ;[BX]=start-adr parm
DEFSAD:	CALL	INP16 ;[AX]=file length
	MOV	CX,AX ;[CX]=file length
	CALL	INPBLK ;do the load
LODEND:
	POP	BX ;restore text pointer
	JMP	FINPRT ;close file 0, reset PTRFIL
ERBFM2:	JMP	DERBFM ;bad file mode error
;BPARMS - Parse parms for BLOAD and BSAVE
; Exit  - [AL]=(1,0,-1) if 0,1,2 parameters parsed.
;         [BX] is preserved (text pointer)
;         [CX] = start-adr
;         [SAVLEN] = file size (if BSAVE)
;
BPARMS:
	CALL	PRODIR ;Don't allow in direct mode if protected
	CALL	NAMSCN ;scan file name and disk number
;setting FILDEV, FILNM, FILEXT
	JB	BNAMOK ;Extension supplied by user
	CALL	NAMBAS ;Supply ".BAS" default extension
BNAMOK:
	DEC	BX
	CALL	CHRGTR ;See if any parms
	JNZ	BPARM2 ;Brif parms follow
	MOV	AL,0o1 ;No Parms, use file header if BLOAD.
	RET ; else exit.
BPARM2:
	CALL	SYNCHR
db "," ;Must see comma first
	CALL	ADRGET ;get start-adr (0..65535)
	PUSH	DX ;save it
	DEC	BX
	CALL	CHRGTR
	JNZ	BPARM3 ;Brif 2nd Parm given.
	POP	CX ;[CX]=start adr
	XOR	AL,AL ;Set 0 if 1 parm only given.
	RET
BPARM3:
	CALL	SYNCHR
db ","
	CALL	ADRGET ;[DX]=number of bytes for bsave (0..65535)
	XCHG	BX,DX
	MOV word [SAVLEN], BX ;Save end ADDRESS+1(start+count)
	XCHG	BX,DX ;[BX]=text pointer
	DEC	BX
	CALL	CHRGTR
	JNZ	SNERR3 ;must be end of statement
	POP	CX ;[CX]=start-adr
	MOV	AL,0o377 ;Set -1 if 2 parms given.
	RET
SNERR3:	JMP	SNERR
; SUBTTL LPRINT, PRINT Statements
global LPRINT
global PRINT
extern PRINUS
extern IMOD
extern FOUT
extern STRLIT
extern STRPRT
extern FACLO
JPRINU:	JMP	PRINUS ;Print Using
PRINTX:	CALL	CRDO ;output terminating CR
PRNTX1:	POP	CX ;discard line width, last comma column
	JMP	FINPRT ;close file#0, reset PTRFIL to keyboard
LPRINT:	MOV word [PTRFIL], -0o1 ;future output will go to Line Printer
	JMP	PRINT1
PRINT:
	MOV	CL,MD_SQO ;setup output file
	CALL	FILGET
PRINT1:	CALL	PTRWDC ;[CH]=width, [CL]=last comma column
	PUSH	CX ;save on stack
NEWCHR:	DEC	BX
	CALL	CHRGTR ;get another character
	JZ	PRINTX ;print CR if end without punctuation
PRINTC:	JZ	PRNTX1 ;branch if end of statement
	POP	CX ;refresh [CH]=width, [CL]=last comma column
	CMP	AL,USINTK ;is it "print using" ?
	JZ	JPRINU ;IF SO, USE A SPECIAL HANDLER
	PUSH	CX ;save [CH]=width, [CL]=last comma column
	CMP	AL,TABTK
	JZ	TABERJ ;the TAB function?
	CMP	AL,SPCTK
	JZ	TABERJ ;the SPC function?
	PUSH	BX ;save the text pointer
	CMP	AL,44
	JZ	COMPRT ;Print Comma
	CMP	AL,59 ;is it a ";"
	JNZ	PRTS
	JMP	NOTABR
TABERJ:	JMP	TABER
PRTS:	POP	DX ;get rid of old text pointer
	CALL	FRMEVL ;evaluate the formula
	PUSH	BX ;save text pointer
	CALL	GETYPR ;see if we have a string
	JZ	STRDON ;if so, print special
	DEC	BX
	CALL	CHRGTR ;[BX]=addr of number terminator(non-blank)
	CMP	byte [BX+0o0],0o54
	PUSHF ;remember if value was comma terminated
	CALL	FOUT ;make a number into a string
	CALL	STRLIT ;make it a string
	MOV	byte [BX+0o0]," " ;put a space at the end
	POPF
	POP	BX
	POP	CX ;restore [CH]=width, [CL]=last comma column
	PUSH	CX
	PUSH	BX
	MOV BX, word [FACLO] ;[BX]=address of string descriptor
	JNZ	INCLEN ;BRIF not comma terminated(print the space too)
	CALL	PTRGPS ;[AL]=file's current position
	ADD	AL,byte [BX+0o0] ;add length of string we will output
;At this point we have [AL]=posn after number is printed(without space),
;  [CH]=device width, [CL]=last comma posn, [BX]=addr of string descriptor.
;IF number output stops at comma column minus one
;THEN don't append blank(This insures that another number will appear at the
;next comma column, instead of the second column posn after this string)
	CMP	CH,255 ;infinite width?
	JZ	MODCOM ;do modulus to determine next comma column
	CMP	AL,CL ;compare with last comma column
	JNB	INCLEN ;Will do CR after do output,
; make string include blank
;Determine if posn in [AL] is one less than a comma column
MODCOM:	INC	AL
MODCM1:	SUB	AL,CLMWID ;[AL]=modulus CLMWID
	JA	MODCM1
	JZ	STRDON ;BRIF at comma column, exclude trailing space
INCLEN:	INC	word [BX+0o0] ;increment the length to include the space
;NOTE:number is less than 255(can do INC)
STRDON:	POP	BX
	POP	CX
	PUSH	CX ;refresh [CH]=width, [CL]=last comma column
	PUSH	BX
	MOV BX, word [FACLO] ;BX points to string descriptor
	INC	CH
	JZ	LINCH2 ;branch if infinite (255) line width
	DEC	CH ;restore [CH]=device width
	CALL	PTRGPS ;[AL]=file's current column pos
	OR	AL,AL ;don't CR if string longer than line
	JZ	LINCH2 ;  length if position is 0
	ADD	AL,byte [BX+0o0] ;[AL]=column + string size
	CMC ;set nc if overflow on check
	JAE	LINCHK ;start on a new line if overflow
	DEC	AL
	CMP	AL,CH ;check for overlap
LINCHK:	JB	LINCH2 ;branch if still on current line
	CALL	CRDO ;else output CR
LINCH2:	CALL	STRPRT ;PRINT THE string/number
	POP	BX ;restore text pointer
	JMP	NEWCHR ;print some more
;PRINT comma (text pointer stacked)
;
COMPRT:	CALL	PTRGPS ;[AL]=file's current column position
	CMP	CH,255 ;infinite width?
	JZ	MORCOM ;do modulus
	CMP	AL,CL ;compare current with last comma column
CHKCOM:	JB	MORCOM ;branch if not beyond last comma col
	CALL	CRDO ;start new line
	JMP	NOTABR ;AND QUIT IF BEYOND LAST COMMA FIELD
MORCOM:	SUB	AL,CLMWID ;[AL]=MODULUS CLMWID
	JAE	MORCOM
	NEG	AL
	DEC	AL ;fill the print position out
;to an even CLMWID, so
;we print CLMWID-[AL] MOD CLMWID spaces
	JMP	ASPA2 ;go print [AL]+1 spaces
;PRINT TAB(N) & SPC(N)
;
TABER:	PUSH	AX ;remember IF [A]=SPCTK or TABTK
	CALL	CHRGTR
	CALL	ADRGET ;[DX]=parameter (0..65535)
	POP	AX ;see if its SPC or TAB
	PUSH	AX
	OR	DX,DX
	JG	TBNONG ;branch if greater than 0
	MOV	DX,0o0 ;map negative parms to 0
	JMP	SPCNDC
TBNONG:	CMP	AL,SPCTK ;if space leave alone
	JZ	SPCNDC
	DEC	DX ;offset TAB by 1
SPCNDC:	PUSH	BX ;save the text pointer
	MOV	BL,CH ;[BL]=file width
	MOV	AL,CH ;[AL]=file width
	INC	AL ;test for width of 255 (no folding)
	JZ	LNOMOD ;if so, don't mod
	MOV	BH,0o0 ;MOD out by line length
	CALL	IMOD ;[BX]=[DX] MOD filewidth
	XCHG	DX,BX ;set [DL] = position to go to
LNOMOD:	POP	BX ;get back the text pointer
	CALL	SYNCHR
db ")"
	DEC	BX
	POP	AX ;get back SPCTK or TABTK
	SUB	AL,SPCTK ;was it SPCTK?
	PUSH	BX ;save the text pointer
	JZ	DOSIZT ;value in [AL]
	CALL	PTRGPS ;[AL]=file position
DOSIZT:	NEG	AL ;print [E]-[A] spaces
	DEC	AL
	ADD	AL,DL
	JB	ASPA2 ;print if past current
	INC	AL
	JZ	NOTABR ;do nothing if at current
	CALL	CRDO ;go to a new line
	MOV	AL,DL ;get the position to go to
	DEC	AL
	JS	NOTABR
ASPA2:	INC	AL
ASPAC:	MOV	DL,AL ;[B]=number of spaces to print
	MOV	AL," " ;[A]=space
REPOUT:	CALL	OUTDO ;PRINT [AL]
	DEC	DL ;decrement the count
	JNZ	REPOUT
NOTABR:	POP	BX ;pick up text pointer
	CALL	CHRGTR ;and the next character
	JMP	PRINTC ;and since we just printed
;spaces, don't call crdo
;if it's the end of the line
; SUBTTL EOF, LOC, LOF  Functions
global EOF
global LOC
global LOF
extern CONINT
; EOF(n) Function - returns -1 if eof, else 0
; Entry - [FAC] = file number
; Exit  - [FAC] = -1 if EOF, else 0.
;
EOF:	CALL	FACFPT ;[SI] points to FDB for file [FAC]
	JZ	ERFNO4 ;error if file not opened
	XOR	BX,BX ;BX=0 (assume not at eof)
	TEST	byte [F_FLGS+SI],FL_BKC
	JNZ	GFUNX ;if character backed up, no eof
	DEC	BX ;[BX]=-1 (EOF true)
	CMP	byte [F_ORCT+SI],0o0
	JE	GFUNX ;branch if FDB EOF flag set
	MOV	AH,G_EOF ;End of file function
	CALL	SIDSP
	JMP	GFUNX ;return result in FAC
ERFNO4:	JMP	DERFNO ;file not open error
; LOC(n) Function
; Entry - [FAC] = file number
; Exit  - [FAC] = current record number
;
LOC:	MOV	AH,G_LOC ;LOC function
GENFUN:	CALL	FACDSP ;[BX]=EOF(file [FAC])
GFUNX:	JMP	MAKINT ;return result in FAC
; LOF(n) Function
; Entry - [FAC] = file number
; Exit  - [FAC] = length of file in bytes
;
LOF:	MOV	AH,G_LOF ;LOF Function
	JMP	FACDSP ;[FAC]=LOF(file [FAC])
; SUBTTL GET/PUT - Random disk I/O Statements
global DPUTG
;Syntax - GET fn [,recnum]   (if no recnum next relative record assumed)
;         PUT fn [,recnum]
; Entry - [BX] = text pointer
;         [CX] = 0 for GET, 1 for PUT
;
DPUTG:
	PUSH	CX ;save GET/PUT Flag
	CALL	POFNUM ;[AL]=file number
	CALL	FDBPTR ;[SI] points to File Data Block of file [AL]
	JZ	ERFNO3 ;branch if file not open
	CMP	byte [F_MODE+SI],MD_RND
	JNE	ERBFM1 ;Not random - bad file mode
	PUSH	SI ;save FDB pointer
	DEC	BX
	CALL	CHRGTR ;reget next character
	JZ	RELRND ;branch if end-of-statement (relative record)
	CALL	SYNCHR
db 0o54 ;parse required comma
	CALL	ADRGET ;[DX]=record number (0..65535)
	POP	SI ;restore FDB pointer
	POP	AX ;restore GET/PUT flag
	ADD	AX,0o2 ;[AX]=2 for GET [DX], 3 for PUT [DX]
	JMP	RELRN1
RELRND:	POP	SI ;restore FDB pointer
	POP	AX
RELRN1:	PUSH	BX ;save text pointer
;[AL]=0,1,2,3 for GET PUT GETrel PUTrel
	MOV	AH,G_RND ;select Random I/O function code
	CALL	SIDSP ;dispatch to routine for FDB SI
	POP	BX ;restore text pointer
	RET
ERBFM1:	JMP	DERBFM
; SUBTTL Misc. Parsing Routines
;POFNUM - Parse optional file number "[#]n"
; Entry - [BX] = text pointer
; Exit  - [BX] = updated text pointer, [AL]=file number
;         All other registers preserved
;
POFNUM:	CMP	byte [BX+0o0],"#" ;[AL]=current character
	JNZ	GETNZB ;branch if optional # not included
;PRFNUM - Parse required file number "#n"
; Entry - [BX] = text pointer
; Exit  - [BX] = updated text pointer, [AL]=file number
;         All other registers preserved
;
PRFNUM:	CALL	SYNCHR
db "#"
;GETNZB - Parse byte (1..255) expression, returning result in [AL]
; Entry - [BX] = text pointer
; Exit  - [BX] = updated text pointer, [AL]=byte parsed
;         All other registers preserved
;
GETNZB:	PUSH	DX
	PUSH	CX
	CALL	GETBYT ;[AL]=file number
	OR	AL,AL
	JZ	ERBFN1 ;bad file number if 0
	POP	CX
	POP	DX
RET9:	RET
ERBFN1:	JMP	DERBFN ;bad file number
global FILINP
global FILGET
global GETPTR
global FILSET
global FILSCN
FILINP:	MOV	CL,MD_SQI ;MUST BE SEQUENTIAL INPUT
FILGET:	CMP	AL,"#" ;NUMBER SIGN THERE?
	JNZ	RET9 ;NO, NOT FILE INPUT
	PUSH	CX ;SAVE EXPECTED MODE
	CALL	FILSCN ;READ AND GET POINTER
	JZ	ERFNO3 ;ERROR IF FILE NOT OPEN
	POP	DX ;[DL]=FILE MODE
	CMP	AL,DL ;IS IT RIGHT?
	JZ	GDFILM ;GOOD FILE MODE
	CMP	AL,MD_RND ;ALLOW STUFF WITH RANDOM FILES
	JNZ	ERBFM3 ;IF NOT, "BAD FILE MODE"
GDFILM:
	CALL	SYNCHR
db 0o54 ;GO PAST THE COMMA
FILSET:	MOV	DX,CX ;SETUP PTRFIL
	MOV word [PTRFIL], CX
	RET
ERBFM3:	JMP	DERBFM
ERFNO3:	JMP	DERFNO
;FILSCN - parse file number
; Entry - [BX]=text pointer
; Exit  - [DL]=file number, [SI], [CX] point to file data block for file [DL]
;         [AL]=file mode, FLAGS.Z is set if file is not open.
;         note - if file is not open, no FDB exists
;
FILSCN:	CALL	POFNUM ;[AL]=file number
FILIDX:	MOV	DL,AL ;return file number in [DL]
FILID2:	CALL	FDBPTR ;SI points to FDB for file [AL]
	JZ	NTOPEN ;branch if file is not open
	MOV	CX,SI ;CX  points to FDB
	MOV	AL,byte [F_MODE+SI] ;[AL]=file mode
	OR	AL,AL ;set non-zero (file is opened)
NTOPEN:	RET
;GETPTR IS CALLED FROM VARPTR(#<EXPRESSION>)
; Entry - [AL]=file number
; Exit  - [DX] points to random file buffer, or sector buffer of file
;
GETPTR:	CALL	FDBPTR ;SI points to File Data Block
	JZ	ERFNO3 ;error if file not open
	MOV	DX,F_MODE ;Return pointer to MODE
	ADD	DX,SI ;Return result in [DX]
	RET
;DIRDO is called to make sure direct statement is not found when loading file
; If device is keyboard, control transfers to GONE with AX used.
;
global DIRDO
DIRDO:	MOV AX, word [PTRFIL]
	OR	AX,AX
	JNZ	ERFDR ;if device not keyboard then
;   error(direct statement in file)
extern GONE
	JMP	GONE ;else OK
ERFDR:	JMP	DERFDR
;ADRGET - parse 16 bit expression
; Entry - [BX]=text pointer
; Exit  - [DX]=result (0..65535)
;         [BX]=updated text pointer
;         AX used, other registers preserved.
;
global ADRGET
ADRGET:	PUSH	CX
extern FRMEVL
	CALL	FRMEVL
	PUSH	BX
extern FRQINT
	CALL	FRQINT ;Make Unsigned 16 bits
	POP	DX
	XCHG	BX,DX ;Offset in [DX], text pointer in [BX]
	POP	CX
	RET
; SUBTTL Major I/O Routines
;PRGFIL is called to open file #0 (SAVE/LOAD/MERGE etc.)
; Entry - [BX]=text pointer, pointing at filename
;         [DH]=file mode
; Exit  - [PTRFIL] points to files FDB (directing all future I/O to file)
;         [BX]=[TEMP]=updated text pointer
;         SI may be destroyed.
;
global PRGFIL
extern TEMP
PRGFIL:	MOV byte [FILMOD], DH ;save file mode (MD.SQI / MD.SQO)
	CALL	NAMSCN ;scan filename
	MOV word [TEMP], BX ;PRGFIN restores text pointer when done
	JB	PRGFIX ;Exit - "." found in name
	CALL	NAMBAS ;Add ".BAS" extension to disk file names
PRGFIX:	JMP	NULOPN ;open file #0
;NAMBAS is called to add the ".BAS" extension to disk file names
;Entry - FILDEV points to device id
;Exit  - SI destroyed
;
NAMBAS:	MOV	SI,FILDEV ;SI points to device id
	TEST	byte [SI+0o0],0o377
	JS	NAMBAX ;Exit if device is not DISK
	ADD	SI,9 ;SI points to Extention
	CMP	byte [SI+0o0]," " ;if blank extention, default to ".BAS"
	JNE	NAMBAX ;Exit if device is not DISK
	MOV	word [SI+0o0],(0o400*"A")+"B"
	MOV	byte [SI+0o2],"S"
NAMBAX:	RET
;NULOPN opens File 0 with mode [AL].
; Exit  - [PTRFIL] points to files FDB (directing all future I/O to file)
;
global NULOPM
NULOPM:	MOV byte [FILMOD], AL ;FILMOD=file mode
NULOPN:	XOR	AL,AL ;[AL]=file number
	XOR	CX,CX ;random record length = 0
;fall into OPNFIL
;OPNFIL - general file-open routine
; Entry - [AL]=file number (0..n)
;         [CX]=record length (0=default)
;         [FILMOD]=mode (MD.SQI / MD.SQO / MD.RND / MD.APP)
;         [FILDEV]=device id
;         [FILNM]=filename
;         [FILEXT]=1..3 byte filename extension
; Exit  - [PTRFIL] points to files FDB (directing all future I/O to file)
;         all registers preserved
;
OPNFIL:	PUSHF
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	SI
	PUSH	DI
	MOV	BL,AL
	MOV	BH,0o0 ;[BX]=file number
	CALL	FDBPTR ;see if file is already open
	JNZ	ERFAO1 ;error if already open
	MOV AL, byte [FILDEV] ;[AL]=device id
	CALL	CDEVID ;[DI]=device dispatch table offset (AL)
	MOV	AH,G_OPN ;open function code (AL is still DEVICE ID)
	CALL	TBLDSP ;call device-dependent open routine
	POP	DI
	POP	SI
	POP	DX
	POP	CX
	POP	BX
	POP	AX
	POPF
	RET
FCERR3:	JMP	FCERR
ERFAO1:	JMP	DERFAO ;file already opened error
;CLSALL - close all opened files
; Entry - none
; Exit  - All registers preserved
;
global CLSALL
CLSALL:	PUSH	AX
	PUSH	SI
	MOV SI, word [FILTAB] ;Get address of next file block
CLSAL1:	CMP SI, word [STKLOW]
	JZ	CLSALX ;Branch if finished
	PUSH	word [F_NEXT+SI] ;save pointer to next entry in chain
	MOV	AL,byte [F_NUM+SI] ;[AL]=file number
	CALL	CLSFIL ;Close file [AL]
	POP	SI ;SI points to next FDB in chain
	JMP	CLSAL1 ;Keep looping till all files closed
CLSALX:	POP	SI
	POP	AX
	RET
;CLSFIL - close file [AL]
; Exit  - Flags, AX, SI used, all other registers are preserved
;
global CLSFIL
CLSFIL:	MOV AH, byte [NLONLY]
	TEST	AH,0o200 ;see if Chain All / Load, R in progress
	JNZ	RET22 ;branch if Dont-Close-Any-Files flag set
	TEST	AH,0o1 ;see if Load/Merge/Chain is in progress
	JZ	CLSFL1 ;branch if Dont-Close-File-0 flag not set
	OR	AL,AL
	JZ	RET22 ;branch if trying to close file 0
CLSFL1:	CALL	FDBPTR ;[SI] points to FDB [AL]
	JZ	RET22 ;branch if file already closed
	PUSH	BX
	PUSH	CX
	PUSH	DX
	MOV word [FREFDB], SI ;So FINPRT will force close file if low-level
;close routine gets I/O error
	MOV	AH,G_CLS
	CALL	SIDSP ;close FDB pointed to by [SI]
	MOV word [FREFDB], 0o0
	CALL	FFREE ;Deallocate FDB and remove from FDB Chain
	POP	DX
	POP	CX
	POP	BX
RET22:	RET
;INCHR - get next byte from file PTRFIL
; Exit  - [AL]=byte, [FLAGS], [AH] destroyed.
;         All other regs preserved
;         if END-OF-FILE then
;            if program load was in progress, file 0 closed etc.
;            else Read-Past-End error is generated
;
global INCHR
extern PRGFIN
extern KYBSIN
INCHR:
	PUSH	SI
	CALL	INCHRE ;[AL]=next byte from PTRFIL, carry if EOF
	JAE	INCHRX ;branch if not EOF
	CMP	byte [F_NUM+SI],0o0 ;EOF on ASCII file #0 = end of Load/Chain/Merge
	JE	FL0EOF ;branch if EOF reached for file #0
extern DERRPE
	JMP	DERRPE ;Input past end error
FL0EOF:	CMP	byte [F_CODE+SI],FC_BIN
	JNE	LDREOF ;branch if not binary file (must be ascii LOAD)
	STC ;else must be BLOAD/binary LOAD
	RET ;return EOF indication to caller
LDREOF:
extern CHNFLG
extern CHNRET
	CMP byte [CHNFLG], 0o0 ;chain in progress?
	JE	NOTCHN ;branch if not chaining
	JMP	CHNRET ;perform variable block transfer, etc.
; close all files
NOTCHN:
	PUSH	BX ;save all registers
	PUSH	CX
	PUSH	DX
	MOV AL, byte [NLONLY] ;get load flags
	AND	AL,0o200 ;leave others open, null gets closed
	MOV byte [NLONLY], AL ;allow other files to be closed
	CALL	PRGFIN ;close the file
	POP	DX
	POP	CX
	POP	BX
	MOV AL, byte [RUNFLG] ;run it or not?
	OR	AL,AL
	JZ	NORUNC ;dont run program
extern RUNC
	CALL	RUNC ;run it
extern NEWSTT
	JMP	NEWSTT
NORUNC:	PUSH	BX
	PUSH	CX
	PUSH	DX
extern REDDY
extern STROUT
	MOV	BX,REDDY ;print prompt "ok"
	CALL	STROUT
	POP	DX
	POP	CX
	POP	BX
	MOV	AL,13
INCHRX:	POP	SI
	RET
;INCHRE - get next byte from file PTRFIL.
; Exit  - Carry set if EOF, else [AL]=byte.
;         SI points to FDB
;         All other regs preserved
;
global INDSKC ;Referenced by DSKCOM
INDSKC:
INCHRE:	MOV SI, word [PTRFIL] ;SI points to current FDB
;fall into INCHSI
;INCHSI - get next byte from file SI (CTL Z = end-of-file)
; Exit  - Carry set if EOF, else [AL]=byte.
;         All other regs preserved
;
global INCHSI
INCHSI:	INC	SI
	JZ	ERBFM6 ;branch if Line Printer (can't input)
	DEC	SI
	JNZ	INGFDB ;branch if not Keyboard (got FDB)
extern INCHRI
	JMP	INCHRI
INGFDB:	CMP	byte [F_MODE+SI],MD_SQO
	JZ	ERBFM6
	CMP	byte [F_ORCT+SI],0o0
	JZ	INCEOF ;branch if EOF already reached
	TEST	byte [F_FLGS+SI],FL_BKC
	JNZ	GETBKC ;branch if char backed up
	MOV	AH,G_SIN
	CALL	SIDSP ;[AL]=next input from file
	JB	INCEOF ;branch if device detected EOF
	RET
INCEOF:	MOV	byte [F_ORCT+SI],0o0 ;indicates EOF on future calls
	MOV	byte [F_BREM+SI],0o0
	STC ;tells caller EOF reached
	RET
GETBKC:	AND	byte [F_FLGS+SI],255-FL_BKC ;clear Backup Present flag
	MOV	AL,byte [F_BAKC+SI] ;return Backed-up character
	RET ;with no carry (no-eof)
ERBFM6:	JMP	DERBFM ;bad file mode error
global CRFIN
global CRDONZ
global FININL
global CRDO
CRFIN:	XOR	AL,AL ;all references should be eliminated
	RET
;CRDONZ - output carriage return if file PTRFIL is not at left margin
;
CRDONZ:	CALL	PTRGPS ;[AH]=0-relative column for PTRFIL
	OR	AH,AH
	JNZ	CRDO ;if not at column 0, output CRLF
	RET
extern BUFMIN
FININL:	MOV	byte [BX+0o0],0o0
	MOV	BX,BUFMIN
;CRDO - output ascii carriage return to current file
;
CRDO:	MOV	AL,ASCCR
	CALL	OUTDO ;output Carriage Return
	MOV	AL,ASCLF ;output Line Feed
	CALL	OUTDO
	XOR	AL,AL ;must return with [AL]=0 and FLAGS.Z true
	RET
;OUTDO - output [AL] to current file (force CR if end-of-line)
; Exit - All registers preserved (including FLAGS)
;
global OUTDO
global FILOU3
FILOU3:
OUTDO:
	PUSHF
	PUSH	AX
	MOV	AH,G_SOT
	CALL	PTRDSP ;dispatch to function [DL] for PTRFIL
	POP	AX
	POPF
	RET
;OUT16 - output data [AX] to current file
;
OUT16:	PUSH	AX
	CALL	OUTDO ;output low-byte first
	XCHG	AH,AL
	CALL	OUTDO ;then output high-byte
	POP	AX
	RET
;INP16 reads the next 16 bits from file PTRFIL
; Exit  - [AX]=result. Carry set if EOF.
;         All other registers are preserved.
;
INP16:	PUSH	BX
	CALL	INCHR ;get low-byte first
	MOV	BL,AL
	CALL	INCHR ;then get high-byte
	MOV	BH,AL
	MOV	AX,BX
INP16X:	POP	BX
	RET
;BAKCHR - backup sequential input file
; Entry - [AL] = char to be backed up
;         [PTRFIL] points to FDB of file to be backed up
;
global BAKCHR
global BCHRSI
BAKCHR:	PUSH	SI
	MOV SI, word [PTRFIL]
	CALL	BCHRSI
	POP	SI
	RET
;BCHRSI - backup sequential input file
; Entry - [AL] = char to be backed up
;         [SI] points to FDB of file to be backed up
;
BCHRSI:	MOV	byte [F_BAKC+SI],AL
	OR	byte [F_FLGS+SI],FL_BKC ;set flag indicating char backed up
	RET
;BINSAV - Binary SAVE support.
;
global BINSAV
global BINPSV
extern TXTTAB
extern PROCHK
extern SCCPTR
BINSAV:	CALL	SCCPTR ;GET RID OF POINTERS BEFORE SAVING
	CALL	PROCHK ;DONT ALLOW BINARY SAVES OF PROTECTED PROGRAMS
	CALL	SCDBIN ;Set attribute CODE to BINARY (not ASCII)
	MOV	AL,255 ;ALWAYS START WITH 255
BINPSV:	CALL	FILOU3 ;SEND TO FILE
	MOV CX, word [VARTAB] ;GET STOP POINT
	MOV BX, word [TXTTAB] ;GET START POINT
	SUB	CX,BX ;Calculate bytes to SAVE
	JBE	BINSVX ;Nothing to SAVE
	MOV	DX,DS ;Get Segment for SAVE
	CALL	OUTBLK ;Write the block
BINSVX:	JMP	PRGFIN ;REGET TEXT POINTER AND CLOSE FILE 0
;DEVBIN - General device block input routine.  This routine is called by
;         device code for devices which have no block I/O capability.
; Entry - [BX] = Start adr
;         [CX] = number of bytes to read
;         [DX] = Segment adr
;         [SI] = address of FDB
;         [DI] = device offset (2=COMD, 4=SCRN, etc.)
; Exit  - [BX] = End+1
;         Carry set if reached end of data before CX bytes read
;         SI, CX, AX used.
;
global DEVBIN
DEVBIN:	OR	CX,CX
	JZ	RET27 ;Until end.
	MOV	AH,G_SIN ;sequential input function
	CALL	PTRDSP ;[AL]=next byte from file PTRFIL
	JB	RET27 ;branch if tried to read past end-of-file
	PUSH	DS
	PUSH	DX
	POP	DS ;[DS]=[DX]
	MOV	byte [BX+0o0],AL ;Store Byte
	POP	DS
	INC	BX ;bump destination pointer
	DEC	CX ;decrement byte count
	JMP	DEVBIN
;DEVBOT - General device block output routine.  This routine is called by
;         device code for devices which have no block I/O capability.
; Entry - [BX] = Start adr
;         [CX] = number of bytes to write
;         [DX] = segment adr
;         [SI] = address of FDB
;         [DI] = device offset (2=COMD, 4=SCRN, etc.)
; Exit  - [BX] = End + 1
;
global DEVBOT
DEVBOT:	OR	CX,CX
	JZ	RET27 ;Until Len=0.
	PUSH	DS ;save BASIC's Data Segment
	PUSH	DX
	POP	DS ;DS=DX
	MOV	AL,byte [BX+0o0]
	POP	DS ;restore BASIC's Data Segment
	CALL	OUTDO ;Write Byte from Memory.
	INC	BX
	DEC	CX
	JMP	DEVBOT
RET27:	RET
;OUTBLK - Write Block of memory to current file
; Entry - [BX] = Start adr
;         [CX] = number of bytes to write
;         [DX] = segment adr
; Exit  - [BX] = End + 1
;
OUTBLK:	MOV SI, word [PTRFIL]
	MOV	AH,G_BOT ;Block output function
	CALL	PTRDSP
	RET
; INPBLK - Read block of memory from current file
; Entry - [BX] = Start adr
;         [CX] = number of bytes to read
;         [DX] = Segment adr
; Exit  - [BX] = End+1
;         Carry set if reached end of data before CX bytes read
;         SI, CX, AX used.
;
extern DFSTLD
INPBLK:	MOV SI, word [PTRFIL]
	MOV	AH,G_BIN ;block input function
	CALL	PTRDSP ;[AL]=next byte from file PTRFIL
	RET
;FSTLOD - load Binary BASIC program (Called from DSKCOM after LOAD statement)
; Entry - BX points to destination of program
;         [FRETOP] - [BX] - ^D86 = maximum legal size of program
;         [PTRFIL] points to FDB of file to be loaded
;         (note: 1st byte of file has already been read and was ^D254)
;
global FSTLOD
extern OUTLOD
FSTLOD:
	MOV CX, word [FRETOP] ;Bottom of string space
	SUB	CX,86 ;leave a little breathing room
	SUB	CX,BX ;[CX]=maximum legal size of program
	CALL	SCDBIN ;set CODE attribute to Binary
	PUSH	DS
	POP	DX ;[DX]=segment to be used
	CALL	INPBLK ;read block from device to disk
	JB	RET27 ;branch if file fits in memory
	JMP	OUTLOD ;ERROR AND WIPE OUT PARTIAL GARBAGE
;PTRGPS - get column position for file PTRFIL
;
; Exit  - [AH] = [AL] = column position
;         FLAGS.Z is true if at column 0
;         All other registers are preserved
;
global PTRGPS
PTRGPS:	MOV	AH,G_GPS ;Get column position request-code
	CALL	PTRDSP ;[AH]=position
	MOV	AL,AH ;[AL]=position
	OR	AL,AL
	RET
;PTRWDC - get line width and last comma column for file PTRFIL
; Exit  - [CH] = line width
;         [AH] = [CL] = last comma column
;         All other registers are preserved
;
PTRWDC:	CALL	PTRWID ;[AH]=file PTRFIL's line width
	MOV	CH,AH ;[CH]=file width
PTRWDL:	SUB	AH,14 ;T.B.S. eventually, use G.GCW
	JAE	PTRWDL
	ADD	AH,28
	NEG	AH
	ADD	AH,CH
	MOV	CL,AH ;[CL]=last comma column
	RET
;PTRWID - get line width for file PTRFIL
; Exit  - [AH] = line width
;         All other registers are preserved
;
global PTRWID
PTRWID:	PUSH	SI ;save caller's SI
	MOV SI, word [PTRFIL]
	INC	SI
	JZ	PTRWD1 ;if LPT Pseudo FDB, use Device width
	DEC	SI
	JZ	PTRWD1 ;if KYBD Pseudo FDB, use Device width
	MOV	AH,byte [F_WID+SI] ;else use FDB width
	POP	SI ;restore caller's SI
	RET
PTRWD1:	POP	SI ;restore caller's SI
	MOV	AH,G_GWD ;Get file width function code
	JMP	PTRDSP ;return with [AH]=device width
; SUBTTL General routines useful to low-level device drivers
global XTABCR
global EXPTAB
global CRIFEL
global UPDPOS
;XTABCR is called by Device Driver Output routines to Expand Tabs to Spaces
;         and Force a carriage return if end-of-line.
; Entry - [AL]=char to be output
;         [DH]=current column position
;         [DL]=line width
;         BX points to raw-output routine
; Exit  - [DH] is new column position
;         FLAGS are used, All other registers are preserved.
;
XTABCR:	PUSH	CX
	MOV	CX,CRIFEL ;EXPTAB will call CRIFEL which will
	CALL	EXPTAB ;call raw-output routine [BX]
	POP	CX
	RET
;EXPTAB is called by Device Driver Output routines to Expand Tabs to Spaces
; Entry - [AL]=char to be output
;         [DH]=current column position
;         CX points to raw-output routine
; Exit  - [DH] is new column position
;         FLAGS are used, All other registers are preserved.
;
EXPTAB:
	CMP	AL,ASCTAB
	JNE	NOTTAB ;branch if not tab
	CMP	DL,9
	JB	EXTABX ;branch if width is less than 9
	MOV	AL,ASCSPC ;output spaces till next tab stop
EXTABL:	CALL	CX ;output space (update position)
	TEST	DH,0o7
	JNZ	EXTABL ;branch if not at MOD 8 column position
	MOV	AL,ASCTAB ;restore AL
EXTABX:	RET
NOTTAB:	JMP	CX ;output char and update position
;CRIFEL - Force a carriage return if end-of-line (Called by device out routines)
; Entry - [AL]=char to be output
;         [DH]=current column position
;         [DL]=line width
;         BX points to raw-output routine
; Exit  - [DH] is new column position
;         FLAGS are used, All other registers are preserved.
;
CRIFEL:	CMP	AL,32
	JB	NOCR ;branch if non-printable
	CMP	DL,255
	JZ	NOCR ;branch if infinite width (255)
	CMP	DH,DL ;compare Column with Width
	JB	NOCR ;branch if still room on current line
	PUSH	AX
	MOV	AL,ASCCR
	CALL	BX ;output Carriage Return
	MOV	AL,ASCLF ;output Line Feed
	CALL	BX
	POP	AX ;restore char to be output
NOCR:	JMP	BX ;output char, update position
;UPDPOS - update column position (called by device out routines)
; Entry - [DH] = current 0-relative column position
;         [AL] = byte to be output
; Exit  - [DH] = new column position.  All other registers preserved
;
UPDPOS:	CMP	AL,32
	JB	NPRINT ;branch if not printable (CTL CHR)
	INC	DH ;bump column position
	RET
NPRINT:	CMP	AL,ASCCR
	JNE	NOTCR ;branch if not carriage return
ZERPOS:	MOV	DH,0o0 ;reset to left margin
	RET
NOTCR:	CMP	AL,ASCBS
	JNE	UPPOSX ;branch if not backspace
	OR	DH,DH
	JE	UPPOSX ;don't decrement below 0
	DEC	DH ;decrement position
UPPOSX:	RET
; SUBTTL File Dispatch Routines
extern IOJUMP
ERBFN2:	JMP	DERBFN ;bad file number error
;FACDSP - Dispatch to I/O routine for file number [FAC]
; Entry - [AH]=function code (G.OPN, G.CLS, etc.)
;         [FAC]=file number (note: file must be opened) (0 is illegal)
; Exit  - DX, AL are used.
;         All other registers preserved except those changed by device driver
;
FACDSP:	CALL	CONINT ;[DX]=integer equivalent of FAC (file#)
	OR	DX,DX
	JZ	ERBFN2 ;file #0 is unavailable to user (bad file num.)
;FILDSP - Dispatch to I/O routine for file number [DH]
; Entry - [AH]=function code (G.OPN, G.CLS, etc.)
;         [DX]=file number (note: file must be opened)
; Exit  - All registers preserved except those changed by device driver
;
FILDSP:	PUSH	SI
	PUSH	AX
	OR	DH,DH
	JNZ	FCERR9 ;error if file# greater than 255
	MOV	AL,DL ;[AL]=file number
	CALL	FDBPTR ;(SI) = file data block pointer
	JZ	ERFNO2 ;Error - bad file number
	POP	AX ;restore caller's [AX]
	CALL	SIDSP
	POP	SI
	RET
FCERR9:	JMP	FCERR ;Function Call Error
;PTRDSP - Dispatch to I/O routine for file with FDB=[PTRFIL]
; Entry - [AH]=function code (G.OPN, G.CLS, etc.)
;         [PTRFIL]=points to file's FDB
; Exit  - All registers preserved except those changed by device driver
;
global PTRDSP
PTRDSP:	PUSH	SI
	MOV SI, word [PTRFIL]
	CALL	SIDSP
	POP	SI
	RET
;SIDSP - Dispatch to I/O routine for file with FDB=[SI]
; Entry - [AH]=function code (G.OPN, G.CLS, etc.)
;         [SI]=points to file's FDB
; Exit  - All registers preserved except those changed by device driver
;
SIDSP:	PUSH	DI
	PUSH	SI
	PUSH	AX
	PUSHF
	INC	SI
	JZ	LPDSP ;branch if Line Printer Pseudo FDB
	DEC	SI
	JNZ	SIDSP1 ;branch if not Keyboard/CRT Pseudo FDB
;        MOVI    DI,$CODE+2*<^O400-$.KYBD>
	MOV	DI,DOL__KYBD
	NEG	DI ; Change neg. dev. # to 0 based offset
	AND	DI,0o377
	SHL	DI,0o1 ; ASM86 cann't multiply externals by 2
	JMP	SIDSP2
LPDSP:
;        MOVI    DI,$CODE+2*<^O400-$.LPT1>   ;SI=0
	MOV	DI,DOL__LPT1
	NEG	DI ; Change neg. dev. # to 0 based offset
	AND	DI,0o377
	SHL	DI,0o1 ; ASM86 cann't multiply externals by 2
	JMP	SIDSP2
SIDSP1:	MOV	AL,byte [F_DEV+SI] ;(AL) = device number
	CALL	CDEVID ;[DI]=device dispatch table offset
SIDSP2:	POPF
	POP	AX ;restore caller's [AX]
	CALL	TBLDSP ;function [AH] on device [DI]
	POP	SI
	POP	DI
	RET
;TBLDSP - Dispatch to I/O routine for device-table [DI]
; Entry - [AH]=function code (G.OPN, G.CLS, etc.)
;         DI = -2 * device id (0=disk, 2=keyboard etc.)
; Exit  - All registers preserved except those changed by device driver
;
TBLDSP:	PUSH	DI
	PUSHF
	PUSH	AX
	MOV AX, word [DEVPTR] ;AX points to 1st entry in dispatch table
	ADD	DI,AX ;DI points to dispatch table pointer for device
	MOV	DI,word [CS:DI+0o0] ;DI points to dispatch table for device
	OR	DI,DI ;If entry is 0, then
	JZ	ERDNA2 ;  Error - device not available
	POP	AX ;restore function code
	PUSH	AX
	XCHG	AH,AL
	CBW ;[AX]=function code
	ADD	DI,AX ;Add function code offset to dispatch
	MOV	AX,word [CS:DI+0o0] ;Get address of routine
	MOV word [IOJUMP], AX
	POP	AX
	POPF
	POP	DI
	JMP	 word [IOJUMP] ;jump to routine at address [IOJUMP]
;CDEVID - convert device id to dispatch table address
; Entry - [AL]=device id (0..n for disk, -1..-n for non-disk devices)
; Exit  - [DI]=DEVPTR offset for device (0 for disk, 2 for KYBD, etc.)
;         FLAGS.Z is true if device=disk
;         All other registers are preserved.
;
CDEVID:	PUSH	AX
	OR	AL,AL
	JS	CDEV1 ;must be a special device
	XOR	AL,AL ;(AL) = 0 for disks
	JMP	CDEV2
CDEV1:	NEG	AL ;(AL) = - device number for special
CDEV2:	PUSHF ;save Z=disk
	CBW ;[AX]=device number
	ADD	AX,AX ; * 2
	MOV	DI,AX
	POPF ;restore Z=disk
	POP	AX
	RET
ERFNO2:	JMP	DERFNO ;file not opened error
ERDNA2:	JMP	DERDNA ;device not available error
; SUBTTL NAMSCN, PARDEV - Device/Filename scanning routines
extern FOPTSZ
extern FILOPT
;T.B.S. - FOPTSZ should eventually be used instead of CMPI CX,^D64, but
; the DEC-Macros don't permit this.
;NAMSCN - parse file-specification [dev:]filename[.extension]
; Entry - [BX] = text pointer
; Exit  - [FILDEV] = 0 if default device,
;                    (1..n) if device=(A:, B:, ...)
;                    (-1..-n) for DEVTBL entry (1..n)
;         [FILNM] = filename
;         [FILEXT] = extention
;         [BX] = updated text pointer
;         [AL]=next character
;         FLAGS.CARRY is set if "." scanned
;         DX is used.
;         All other registers preserved
;
global NAMSCN
NAMSCN:	CALL	FRMEVL
NAMSC1:	PUSH	BX ;save text pointer
	CALL	FRESTR ;release string descriptor
;[BX] points to string descriptor
	MOV	CL,byte [BX+0o0]
	MOV	CH,0o0 ;[CX]=length of string
	MOV	SI,word [BX+0o1] ;SI points to start of string
	CALL	PARDEV ;(AL) = device #
	MOV byte [FILDEV], AL ;Save device #
	OR	AL,AL
	JS	NOTDSK ;branch if special device
	XOR	AL,AL ;(AL) = 0 for disks
NOTDSK:	PUSH	AX
	PUSH	DX
	PUSH	DI
	OR	AL,AL
	PUSHF ;save NC - indicates "." not scanned
	MOV	DI,FILNM
	MOV	DX,FNAML ;filename length
	JNS	SCAN1 ;If disk device, put name in FILNM
; This code copies Device Dependent Options to FILOPT which is a
; buffer scanned by device drivers at device open time.
;
	MOV	DI,FILOPT
	JCXZ	SCOM1 ;Will copy 1 to
	CMP	CX,64 ;compare with option buffer size
	JAE	ERIFN1 ;"Bad File Name" if too long
	CLD ;set Post-Increment mode
;Copy string to FILNM
 REP	MOVSB
SCOM1:
	MOV	byte [DI+0o0],CL ;Terminate option string with 0
	JMP	SCNAM3
SCAN1:	JCXZ	FILSPC ;End of string
	DEC	CX
	CLD ;set Post-Increment mode
	LODSB ;Get filename character
	CMP	AL,"*" ;filename can't have wildcard chars
	JE	ERIFN1
	CMP	AL,"?"
	JE	ERIFN1
	CMP	AL," "
	JAE	SCNAM2
ERIFN1:	JMP	DERIFN ;Illegal file name error
SCNAM2:	CMP	AL,"."
	JE	FILLNM
	CLD ;set Post-Increment mode
	STOSB ;Store character
	DEC	DX
	JNZ	SCAN1 ;Keep looking for characters
SCNAM3:	POPF
	POP	DI
	POP	DX
	POP	AX
	POP	BX ;restore updated text pointer
	RET
FILLNM:	POPF
	STC ;set carry indicating "." scanned
	PUSHF
FILNM0:	CMP	DX,FNAML ;file name length
	JE	ERIFN1 ;Error - extension only !
	CMP	DX,0o3
	JB	ERIFN1 ;Error - 2nd dot
	JE	SCAN1 ;Scan extension like filename
	MOV	AL," "
	CLD ;set Post-Increment mode
	STOSB ;Fill with blank
	DEC	DX
	JMP	FILNM0 ;Keep filling
FILSPC:	MOV	AL," " ;Fill short name with spaces
	CLD ;set Post-Increment mode
	STOSB
	DEC	DX
	JNZ	FILSPC ;Keep filling
	JMP	SCNAM3 ;Done with name
;PARDEV - Parse device name from string
; Entry - (CX) = length of string
;         (SI) = string address
; EXIT  - (AL) = device # (0 = default , - = special)
;         (CX) = remaining count
;         (SI) = address of remaining string
PARDEV:
	PUSH	DX
	PUSH	DI
	PUSH	SI
	MOV	DX,CX ;(DX) = original length
	OR	DX,DX ;test for zero length
	JZ	NODVNM ;If length = 0 , no device name
DEVSCN:	CLD ;set Post-Increment mode
	LODSB ;Get character
	CMP	AL,":"
	JE	DEVNM ;Found possible name
	LOOP	DEVSCN
NODVNM:	MOV	CX,DX ;No device name - restore everything
	POP	SI
	POP	DI
	POP	DX
	XOR	AL,AL ;Default device to 0
	RET
DEVNM:	POP	DI ;Restore old string pointer
	XCHG	SI,DI
	PUSH	DI ;Save new string pointer
	SUB	DX,CX ;(DX) = device name length
	JZ	ERIFN2 ;Length = 0 - illegal file name
	DEC	CX ;Count off :
	CMP	DX,0o1
	JE	DSKNAM ;Length = 1 - must be disk name
	MOV DI, word [DEVTBL]
	DEC	DI
DEVSRC:	PUSH	SI
	PUSH	DX
DEVLOP:	INC	DI
	CLD ;set Post-Increment mode
	LODSB
	CALL	UPCASE ;Convert to upper case
	TEST	byte [CS:DI+0o0],0o200 ;Check to see if at device (long name)
	JNZ	NMTCH2
	CMP	byte [CS:DI+0o0],AL
	JNE	NOMTCH
	DEC	DX
	JNZ	DEVLOP
FNDDEV:	INC	DI
	MOV	AL,byte [CS:DI+0o0] ;Get device #
	OR	AL,AL
	JNS	NOMTCH ;Not a device #
	POP	SI
	POP	SI
DEVRET:	POP	SI ;(SI) = pointer after :
	POP	DI
	POP	DX
	RET ;(CX) = chars left , (AL) = device #
NMTCH1:	INC	DI
NOMTCH:
	TEST	byte [CS:DI+0o0],0o200 ;Check for device #
	JZ	NMTCH1 ;  No
NMTCH2:	POP	DX
	POP	SI
	CMP	byte [CS:DI+0o1],0o0 ;End of table?
	JNE	DEVSRC ;  No - check next entry
ERIFN2:	JMP	DERIFN ;Error - bad filename (device name)
DSKNAM:
	CLD ;set Post-Increment mode
	LODSB ;Refetch character
	CALL	UPCASE
	SUB	AL,"A"-0o1 ;Convert letter to 1-26 (let @ be 0)
	JB	ERIFN2 ;  Less than @
	CMP	AL,"Z" & 0o37
	JAE	ERIFN2 ;  Greater than Z
	JMP	DEVRET
UPCASE:	CMP	AL,"a" ;Convert (AL) to upper case
	JB	UPRET
	CMP	AL,"z"
	JA	UPRET
	AND	AL,255-" "
UPRET:	RET
; SUBTTL File Data Block Management Routines
extern VARTAB
extern ARYTAB
extern MEMSIZ
extern FRETOP
extern SAVFRE
extern FILTAB
extern STREND
extern ERROR
extern SKPNAM
extern GARBA2
;INIFDB - Special device open common routine
; Allocates, initializes and links new FDB into FDB Chain.
; Entry - (AL) = file device
;         (AH) = valid file modes
;         (CX) = buffer size (not including basic FDB size)
;         (DL) = file width
;         (DH) = initial file position
;         (BX) = file number
; Exit -  SI points to new File Data Block
;         [PTRFIL] points to new FDB
;         All other registers preserved.
;
global INIFDB
INIFDB:	PUSH	CX
	PUSH	DI
	TEST byte [FILMOD], AH ;Check for valid file mode
	JZ	ERBFM4 ;  Bad file mode
	ADD	CX,FDBSIZ ;(CX) = size of block to allocate
	CALL	FALLOC ;SI points to Allocated block
	MOV word [PTRFIL], SI
	MOV	byte [F_NUM+SI],BL ;Set file number
	MOV	byte [F_DEV+SI],AL ;Set file device
	MOV	byte [F_FLGS+SI],0o0
	MOV	byte [F_CODE+SI],FC_ASC ;default file-code to ASCII
	MOV CL, byte [FILMOD]
	MOV	byte [F_MODE+SI],CL ;Set file mode
	MOV	byte [F_WID+SI],DL ;Set file width
	MOV	byte [F_POS+SI],DH ;Set file position
	MOV	byte [F_ORCT+SI],0o1 ;indicates not at EOF
	POP	DI
	POP	CX
	RET
ERBFM4:	JMP	DERBFM ;Bad file mode
;SCDASC - Set file-attribute CODE for file PTRFIL to ASCII
; Exit  - all registers preserved.
;
global SCDASC
SCDASC:	PUSH	SI
	MOV SI, word [PTRFIL]
	MOV	byte [F_CODE+SI],FC_ASC
	POP	SI
	RET
;SCDBIN - Set file-attribute CODE for file PTRFIL to binary
; Exit  - all registers preserved.
;
global SCDBIN
SCDBIN:	PUSH	SI
	MOV SI, word [PTRFIL]
	MOV	byte [F_CODE+SI],FC_BIN
	POP	SI
	RET
;FDBPTR - Transform file number into File-Data-Block pointer
; Entry - [FAC] = file number (0..n)
; Exit  - if File-Data-Block is allocated,
;            SI points to 1st byte of File-Data-Block
;         else FLAGS.Z is true
;         DX, AX are used
;
FACFPT:	CALL	CONINT ;[AL] = file number
;fall into FDBPTR
;FDBPTR - Transform file number into File-Data-Block pointer
; Entry - [AL] = file number (0..n)
; Exit  - if File-Data-Block is allocated,
;            SI points to 1st byte of File-Data-Block
;         else FLAGS.Z is true
;         All other registers are preserved
;
FDBPTR:	MOV SI, word [FILTAB] ;[SI] points to 1st file-data-block
GPTRL:	CMP SI, word [STKLOW] ;compare with nil FDB pointer
	JZ	GPTRX ;branch if at end of FDB chain
	CMP	AL,byte [F_NUM+SI]
	JZ	GPTRF ;branch if found FDB
	MOV	SI,word [F_NEXT+SI] ;advance to next FDB in chain
	JMP	GPTRL
GPTRF:	OR	SI,SI ;set NZ - indicates FDB found
GPTRX:	RET
;FALLOC(nbytes) {allocate file-data-block and link into chain}
; Entry - CX=size of FDB
; Exit  - SI points to new FDB (which is already linked into FDB chain)
;         SI, DI used.
;
;  if FRETOP-STREND .LEQ. nbytes then
;    perform major string garbage collection
;    if FRETOP-STREND is still .LEQ. nbytes then deverr(Out-of-memory)
;  temp = FILTAB;
;  xfrstr(FILTAB,-nbytes); {move string space down nbytes}
;  FILTAB.F.NEXT := temp; {link new FDB into chain}
;  return FILTAB;
;
FALLOC:	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSHF
	MOV	AX,CX ;[AX]=size of new FDB
	MOV	DL,0o1 ;Indicates 1st attempt to find space
FALC1:	MOV BX, word [FRETOP] ;BX points to top of free string space
	SUB BX, word [STREND] ;BX=number of bytes free - 1
	CMP	AX,BX ;compare with requested amount
	JB	FALCOK ;branch if its available
	DEC	DL
	JZ	FAPAS1 ;branch if 1st attempt
	MOV	DL,ERRC_ERROM ;else give Out of Memory error
	JMP	ERROR
FAPAS1:	PUSH	AX
	PUSH	DX
	CALL	GARBA2 ;perform major garbage collection
	POP	DX
	POP	AX
	JMP	FALC1 ;now that its compressed, try again
FALCOK:	NEG	AX ;indicates moving strings down
	MOV SI, word [FILTAB] ;SI points to lowest FDB in chain
	PUSH	SI ;save for link
	CALL	XFRSTR ;move string space
	POP	BX
	MOV SI, word [FILTAB] ;SI points to new FDB
	MOV	word [F_NEXT+SI],BX ;link FDB into chain
global PDCBAX
global PCBAX
global PBAX ;generally useful routines
PFDCBA:	POPF
PDCBAX:	POP	DX
PCBAX:	POP	CX
PBAX:	POP	BX
	POP	AX
	RET
;FFREE(fdbptr) {free file data block}
;              {ffree is called by clsfil only}
; Entry - SI points to FDB to be freed
; Exit  - SI, DI Used
;
;  fdbptr points to low byte of freed file-data-block
;  remove fdbptr from chain of file-data-blocks (FILTAB)
;  nbytes := size of freed file-data-block.
;  xfrstr(fdbptr, nbytes); {move string space and lower-FDB's up nbytes}
;
FFREE:	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSHF
	MOV	AX,word [F_NEXT+SI] ;AX points to next FDB in chain
	SUB	AX,SI ;AX = size of FDB being freed
	MOV BX, word [FILTAB] ;BX points to 1st FDB in chain
FFNDL:	CMP	BX,SI ;see if this is the one being freed
	JE	FFOUND ;branch if it is
	JB	STILOK ;branch if still less than expected
BADFDB:	JMP	BADFDB ;better to halt than destroy other data
STILOK:
	MOV	CX,word [F_NEXT+BX] ;CX points to next FDB in chain
	ADD	word [F_NEXT+BX],AX ;update next-ptr to reflect block move
	MOV	BX,CX
	JMP	FFNDL ;continue quest
FFOUND:
	CALL	XFRSTR ;move strings and lower FDB's up
	JMP	PFDCBA ;restore registers and exit
;XFRSTR(top, nbytes) {transfer string space}
; Entry - SI points 1 byte above block to be moved
;         AX = direction and number of bytes to be moved {nbytes}
;              (if AX .GT. 0 then strings are moved to a higher adr (UP))
;         FRETOP points 1 byte below bottom of block to be moved
; Exit  - FLAGS, AX, BX, CX, DX used (Others preserved)
;
;  if moving string space down, nbytes .LS. 0, top=FILTAB
;  if moving string space up, top=pointer to FDB being released,
;  perform block move
;  for each string descriptor in VARTAB, ARYTAB, temporaries do
;    if str.adr .LSS. top then
;      str.adr := str.adr + nbytes {update string descriptor}
;    else if str.adr .LSS. top+nbytes then
;      str.len := 0 {reset field variables in released FDB}
;    end; {for each string...}
;  FILTAB := FILTAB + nbytes;
;  MEMSIZ := MEMSIZ + nbytes;
;  FRETOP := FRETOP + nbytes;
;  SAVFRE := SAVFRE + nbytes; (so CHAIN will work)
;  PTRFIL := PTRFIL + nbytes; (if it was pointing to a moved FDB)
;
XFRSTR:	PUSH	SI
	PUSH	DI
	DEC	SI ;SI points to top of block to be moved
	MOV	DI,SI ;DI points to top of block to be moved
	MOV	DX,AX ;DX=byte-count adjustment for block move
	ADD	DI,AX ;DI points to top of dest of block move
	MOV	CX,SI
	SUB CX, word [FRETOP] ;CX = number of bytes to transfer
	JZ	XFRSTX ;return if string space is empty
	PUSH	SI
	PUSH	DI
	STD ;set Post-Decrement mode
	OR	AX,AX
	JNS	XFRSUP ;brif moving strings up in memory
	CLD ;set Post-Increment mode
	SUB	SI,CX
	SUB	DI,CX ;start transfer from bottom
	INC	SI ;SI points to bottom of SRC block
	INC	DI ;DI points to bottom of DST block
XFRSUP:
 REP	MOVSB ;execute block move
	POP	DI ;restore DI points to TOP of DST block
	POP	SI ;restore SI points to TOP of SRC block
;Update all string descriptors in VARTAB
; SI points to top of source of block move
; DI points to top of destination of block move
; DX = byte count adjustment for block move
;
	MOV BX, word [VARTAB] ;Look at simple strings
CSVAR:	CMP BX, word [ARYTAB] ;Done if we have reached array table
	JZ	CAYVAR ;Yes
	CALL	SKPNAM ;Skip name, returns Z if was a string
	JNZ	CSKPVA ;Skip this var, not string
	CALL	UPDSTD ;Update this string descriptor
	XOR	AL,AL ;UPDSTD has already incremented [BX]
CSKPVA:
	MOV	AH,0o0
	ADD	BX,AX ;Add length of VALTYP
	JMP	CSVAR
;Update all string descriptors in ARYTAB
;
CAYVA2:	MOV	BX,AX ;BX points to next string descriptor
CAYVAR:	CMP BX, word [STREND] ;New limit of search
	JZ	XFRSTX ;branch if done searching arrays
	CALL	SKPNAM ;Skip over name
	PUSHF ;save string-name indicator
	MOV	AX,word [BX+0o0] ;Get length of array
	INC	BX
	INC	BX
	ADD	AX,BX ;AX points to next entry in ARYTAB
	POPF ;String array?
	JNZ	CAYVA2 ;No, look at next one
	PUSH	AX ;save pointer to end of array
	MOV	AL,byte [BX+0o0] ;Pick up number of DIMs
	MOV	AH,0o0 ;Make double with high zero
	ADD	BX,AX ;Go past DIMS
	ADD	BX,AX
	INC	BX ;One more to account for # of DIMs
CAYSTR:	POP	AX ;AX points to end of array
	CMP	BX,AX ;Are we done with this array?
	JZ	CAYVAR ;Get next array
	PUSH	AX
	CALL	UPDSTD ;Update string descriptor
	JMP	CAYSTR
XFRSTX:	MOV CX, word [PTRFIL]
	CMP CX, word [FRETOP]
	JB	XFSTX1 ;brif PTRFIL pointed below moved block
	CMP	CX,SI
	JAE	XFSTX1 ;brif PTRFIL pointed above moved block
	ADD word [PTRFIL], DX ;Adjust PTRFIL for block move
XFSTX1:	ADD word [FRETOP], DX ;Adjust FRETOP for block move
	ADD word [SAVFRE], DX ;Adjust SAVFRE for block move
	ADD word [FILTAB], DX ;Adjust FILTAB for block move
	ADD word [MEMSIZ], DX ;Adjust MEMSIZ for block move
	POP	DI
	POP	SI
	RET
;Update String Descriptor pointed to by BX.
; Entry - BX points to string descriptor
;         SI points to top of source for block move
;         DI points to top of destination for block move
;         DX = size and direction of block move
; Exit  - BX points 1 byte beyond string descriptor
;         if string descriptor pointed inside buffer being released, len=0
;         if descriptor points within block-move, its pointer is adjusted.
;         CX used.  All other registers preserved.
;
UPDSTD:
	MOV	CX,word [BX+0o1] ;CX points to string data
	CMP CX, word [FRETOP]
	JBE	UPDSTX ;brif string data is below string space
	CMP	CX,SI
	JBE	UPDSTU ;brif string data was block moved
	CMP	CX,DI
	JA	UPDSTX ;brif string not in buffer being freed
	MOV	byte [BX+0o0],0o0 ;set string len to 0 (reset field buf)
UPDSTU:
	ADD	word [BX+0o1],DX ;adjust pointer for block move
UPDSTX:
	ADD	BX,0o3 ;BX points 1 byte beyond string desc
	RET
; SUBTTL General Queue support routines
global INITQ
global PUTQ
global GETQ
global NUMQ
global LFTQ
;These routines are all called with SI pointing to an 8-byte queue descriptor
; which is organized (invisibly to the caller) as follows:
;
%define Q_PUT 0o0 ;points to the next empty byte in the queue
%define Q_GET 0o2 ;points to the next byte to be fetched (oldest data)
%define Q_BUF 0o4 ;points to the 1st byte of the physical buffer
%define Q_END 0o6 ;points 1 byte beyond the end of the physical buffer
;   Note: if Q.PUT(SI)=Q.GET(.SI), the queue is empty
;         Size of queue buffer is Q.END - Q.BUF
;         Maximum data in queue at any time is Q.END - Q.BUF - 1
;INITQ - initialize queue descriptor for empty queue
; Entry - SI points to 8 byte queue descriptor
;         BX points to 1st byte of queue buffer
;         [AX] = size of queue buffer
; Exit  - AX is used
;
INITQ:	MOV	word [Q_PUT+SI],BX
	MOV	word [Q_GET+SI],BX
	MOV	word [Q_BUF+SI],BX
	ADD	AX,BX
	MOV	word [Q_END+SI],AX
	RET
;PUTQ - append data to back of queue
; Entry - SI points to 8 byte queue descriptor
;         [AL]=data to be put in queue
; Exit  - FLAGS.Z is true if queue is full
;
PUTQ:	MOV	BX,word [Q_PUT+SI]
	MOV	byte [BX+0o0],AL
	CALL	BUMPQP ;advance PUT-POINTER BX
	CMP	BX,word [Q_GET+SI]
	JE	PQFULL ;brif queue is full (ignore new data)
	MOV	word [Q_PUT+SI],BX ;save new PUT-POINTER
PQFULL:	RET
;GETQ - get next byte from front of queue
; Entry - SI points to 8 byte queue descriptor
; Exit  - FLAGS.Z is true if queue is empty
;         otherwise, [AL]=data to be put in queue
;         AX is used
;
GETQ:	MOV	BX,word [Q_GET+SI]
	CMP	BX,word [Q_PUT+SI]
	JE	GQEMTY ;branch if queue is empty
	MOV	AL,byte [BX+0o0] ;get next byte from queue
	CALL	BUMPQP ;advance queue pointer BX
	MOV	word [Q_GET+SI],BX ;save new GET-POINTER
	OR	BX,BX ;set NZ so caller knows AL has data
GQEMTY:	RET
BUMPQP:	INC	BX
	CMP	BX,word [Q_END+SI]
	JB	BUMPQX ;branch if no need to Wrap-Around
	MOV	BX,word [Q_BUF+SI] ;reset pointer to start of buf
BUMPQX:	RET
;LFTQ - How many times can PUTQ be successfully called for queue SI
; Entry - SI points to 8 byte queue descriptor
; Exit  - [AX] = number of bytes free in queue (0..QueueSize - 1)
;
LFTQ:	MOV	AX,word [Q_GET+SI]
	DEC	AX
	SUB	AX,word [Q_PUT+SI]
	JMP	NUMQ1
;NUMQ - How many times can GETQ be successfully called for queue SI
; Entry - SI points to 8 byte queue descriptor
; Exit  - [AX] = number of bytes of data in queue (0..QueueSize - 1)
;
NUMQ:	MOV	AX,word [Q_PUT+SI]
	SUB	AX,word [Q_GET+SI]
NUMQ1:	JAE	NUMQX ;brif PUT-POINTER exceeds GET-POINTER
	ADD	AX,word [Q_END+SI]
	SUB	AX,word [Q_BUF+SI]
NUMQX:	RET
; SUBTTL I/O Initialization Called by INIT
global GIOINI
global GIOTRM
GIOINI:
	CALL	MSISET ;Init MSDOS interrupts &H23 & &H24
	XOR	AX,AX
	MOV word [STKLOW], AX
	MOV word [FILTAB], 0o0 ;so FDBPTR will work during initialization
	MOV byte [NLONLY], AL
	MOV BX, word [DEVINI] ;DI points to array of init routines
	CALL	DOALDV
	JMP	FINPRT ;reset PTRFIL to Keyboard
GIOTRM:	MOV BX, word [DEVTRM] ;DI points to array of terminate routines
	CALL	DOALDV
	CALL	MSIRST ;Replace MSDOS int vectors &H23 & &H24
	RET
DOALDV:	MOV	AL,DOL__NDEV
	CBW ;[CX]=number of devices in system
	ADD	AX,AX
	JZ	DOALLX ;branch if no non-disk devices
	MOV	DI,AX ;[DI]=2*number of non-disk devices
DOALLP:	PUSH	BX
	PUSH	DI
	CALL	 word [CS:BX+DI-0o2] ;Call initialization/termination routine
	POP	DI
	POP	BX
	DEC	DI
	DEC	DI
	JNZ	DOALLP ;Loop until Device ID = 0 (disk)
DOALLX:
	RET
;FINLPT forces a carriage return on LPT1 if it is not already at left margin.
; It then falls into FINPRT.
; Exit  - AX, SI, DI, FLAGS used, all other registers preserved.
;
FINLPT:	PUSH	AX
	MOV	AH,G_GPS ;Get column position request-code
;        MOVI    DI,$CODE+2*<^O400-$.LPT1>
	MOV	DI,DOL__LPT1
	NEG	DI ; Change neg. dev. # to 0 based offset
	AND	DI,0o377
	SHL	DI,0o1 ; ASM86 cann't multiply externals by 2
	PUSH	DI ;save Device Code
	CALL	TBLDSP ;function [AH] on device [DI] (LPT1)
	POP	DI
	OR	AH,AH ;test LPT1 current column position
	JZ	FINLPX ;branch if at column 0
	MOV	AX,(0o400*G_SOT)+13
	PUSH	DI ;save Device Code
	XOR	SI,SI ;SI=pseudo LPT FDB
	CALL	TBLDSP ;Send CR to LPT
	POP	DI
	MOV	AX,(0o400*G_SOT)+10
	XOR	SI,SI ;SI=pseudo LPT FDB
	CALL	TBLDSP ;Send LF to LPT
FINLPX:	POP	AX
;Fall into FINPRT
;FINPRT is called at the end of every BASIC statement and after ERROR.
; It resets the current file to be Keyboard/Crt.
; It also frees the File-Data-Block pointed to by FREFDB if it is non-zero.
; This is useful for Device-Open routines (xxxOPN).  After calling
; INIFDB to allocate an FDB, they can set FREFDB to point to allocated FDB.
; When the file gets completely opened, they can reset FREFDB to 0.
; Then if some error occurs in between, FINPRT will release the FDB.
; Exit  - AX, SI, DI, FLAGS used, all other registers preserved.
;
global FINPRT
global FINLPT
extern FREFDB
FINPRT:
extern SETCSR
extern CSRY
extern CSRX
extern CSRTYP
	PUSH	DX
	MOV DL, byte [CSRY]
	MOV DH, byte [CSRX] ;DX=current posn
	MOV byte [CSRTYP], 3 ;Set to user cursor
	CALL	SETCSR ;Display the cursor
	POP	DX
	MOV SI, word [FREFDB]
	OR	SI,SI
	JZ	NFRFDB ;branch if no FDB needs to be released
	CALL	FFREE
NFRFDB:	XOR	AX,AX
	MOV word [FREFDB], AX ;reset FREE-FDB flag
	CALL	CLSFIL ;close file #0 (if NLONLY=0)
	XOR	AX,AX
	TEST byte [NLONLY], 0o1
	JNZ	RET45 ;don't clear PTRFIL if loading program
	MOV word [PTRFIL], AX ;future I/O will use Keyboard/CRT
RET45:	RET
; SUBTTL  MSDOS   Abort/Initialization/Termination Processing
extern DINTAD
extern CTLCAD ;MSDOS Ctl-C and disk error vector
extern MSDCCF ;MSDOS control C flag
extern ERROR
;I/O Error numbers
global SAVVEC
global SETVEC
;DSKERR - Processing for MSDOS interrupt &H23
;         Exit is made through ERROR.  No IRET is executed.
;
DSKERR:	STI
	MOV	AX,DI ;[AX]= Error code
	ADD	SP,20 ;Adjust stack
	POP	DS ;Get BASIC data segment
	POP	ES ;Get BASIC extra segment
	MOV	DL,ERRC_ERRDWP
	OR	AL,AL ;Test for "Disk write protect"
	JZ	DSKERX ;Disk write protect
	MOV	DL,ERRC_ERRDNR
	CMP	AL,2 ;Test for "Disk not ready"
	JZ	DSKERX ;Disk not ready
	MOV	DL,ERRC_ERRDME ;Else "Disk media error
DSKERX:	JMP	ERROR ;Go report the error and return
;Extra stuff on stack is removed by ERROR
;MSCTLC - Processing for MSDOS interrupt &H23
;
MSCTLC:	MOV byte [MSDCCF], 0o377 ;Record control-C event for POLKEY
	IRET
;MSISET - Set MSDOS termination and Ctl-C processing addresses.
;         The current addresses are saved for restoration upon termination
;         All registers preserved.
;
MSISET:
; ROM CARD build has no DOS vector API. The original routine installs Ctrl-C
; and critical-error vectors through INT 21h, which is not a valid contract
; here. Preserve the caller-visible all-registers-preserved behavior by
; returning directly.
	RET
MSIRST:
	RET
;SAVVEC - Get and store an interrupt vector
;ENTRY  - AX = interrupt
;         BX = CS relative address of vector storage area
;EXIT   - all registers preserved
;
SAVVEC:	PUSH	DX
	PUSH	ES
	CALL	GETVEC
	MOV	word [BX+0o0],DX ;Save address portion
	MOV	DX,ES
	MOV	word [BX+0o2],DX ;Save paragraph portion
	POP	ES
	POP	DX
	RET
;SETVEC - Set an interrupt vector
;ENTRY  - AX    = interrupt number
;         ES:DX = new interrupt vector
;EXIT   - All registers preserved
;
SETVEC:	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	CALL	XCESDS ;Swap ES and DS
mov ah, 37
int 33 ;Set interrupt
	CALL	XCESDS ;Swap ES and ES back
	JMP	PDCBAX ;POP DX,CX,BX,AX and RET
XCESDS:	PUSH	ES
	PUSH	DS
	POP	ES
	POP	DS
	RET
;GETVEC - Get current interrupt vector
;ENTRY  - AX    = interrupt number
;EXIT   - ES:DX = interrupt vector
;         All other registers preserved
;
GETVEC:	PUSH	AX
	PUSH	BX
	PUSH	DS
	SHL	AX,0o1
	SHL	AX,0o1 ;Calculate interrupt address
	MOV	BX,AX
	XOR	AX,AX
	MOV	DS,AX ;Get interrupt paragraph
	LES DX, [BX+0o0] ;Get interrupt vector
	POP	DS
	POP	BX
	POP	AX
	RET
