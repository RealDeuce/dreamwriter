; Auto-converted mechanically from gw-basic/giodsk.asm
; Edit the converter or the generated source deliberately; do not hand-wave syntax changes.

; [ This translation created 10-Feb-83 by Version 4.3 ]
; .RADIX  8
%include "dwoem.inc"
; SUBTTL  GLOBAL TEMPS and DEFS
; TITLE   GIODSK - BASIC-86 Generalized I/O Disk Driver
; COMMENT *
; 
; --------- --- ---- -- ---------
; COPYRIGHT (C) 1982 BY MICROSOFT
; --------- --- ---- -- ---------
; 
;         T. Corbett      Microsoft   for BASIC-86 Generalized I/O
;                         Based on code written for BASCOM-86
%include "gio86u.inc"
%define CPM86 0
%include "msdosu.inc"
; .RADIX	10
extern CHRGTR
extern SYNCHR
extern OUTDO
extern DERNMF
extern DERBFM
extern DERBRN
extern DERFAO
extern FCERR
extern DERTMF
extern DERFAE
extern DERFNF
extern DERIOE
extern DERDFL
extern DERFOV
extern CONIA
extern MAKINT
extern MOVE1
extern DOL_NORMD
extern DEVBOT
extern DFACLO
extern FAC
extern VALTYP
extern RECRD
extern LBUFF
extern PBUFF
extern FILNAM
extern FILNA2
%define ASCCR 13 ;Ascii carriage return
%define ASCCTZ 26 ;END OF FILE CHARACTER
;Disk Dispatch Table
;
global DSKDSP
DSKDSP:
dw (DSKEOF) ;test EOF for file opened to this device
dw (DSKLOC) ;LOC - sequential records / last random record
dw (DSKLOF) ;LOF - file size
dw (DSKCLS) ;perform special CLOSE functions for this device
dw (FCERR) ;set device width
dw (DSKRND) ;GET/PUT random record from/to this device
dw (DSKOPN) ;perform special OPEN functions for this device
dw (DSKSIN) ;input 1 byte from file opened on this device
dw (DSKSOT) ;output 1 byte to file opened on this device
dw (DSKGPS) ;POS
dw (DSKGWD) ;get device width
dw (DSKSCW) ;set device comma width
dw (DSKGCW) ;get device comma width
dw (DFSTLD) ;block input from file opened on this device
dw (DEVBOT) ;block output to file opened on this device
; SUBTTL  Misc. Disk Routines
;DSKEOF - test for End-Of-File on device.
; Entry - SI points to File-Data-Block.
; Exit  - [BX] = -1 if EOF, 0 if not EOF
;
DSKEOF:
	CMP	byte [F_MODE+SI],MD_SQO ;EOF( ) is Illegal
	JE	ER_BFM ; for Sequential Output
ORNCHK:
	XOR	AL,AL
	CMP	byte [F_ORCT+SI],AL ;zero if End of File
	JE	WASEOF ;Brif EOF
	CMP	byte [F_MODE+SI],MD_RND ;If mode is Random
	JZ	NOTEOF ; then don't return true EOF
	CMP	byte [F_BREM+SI],AL ;Any bytes left in buffer?
	JNZ	CHKCTZ ;Yes, look for Control-Z
	CALL	DOL_READS ;Fill the Buffer
	JMP	ORNCHK ; and try again...
CHKCTZ:
	MOV	BX,DATPSC
	SUB	BL,byte [F_BREM+SI] ;[BX] = char offset
	CMP	byte [DATOFS][BX+SI],ASCCTZ ;check for EOF
	JNZ	NOTEOF ;Brif next char not EOF
WASEOF:
	MOV	BX,-1 ; -1 if EOF
	RET
NOTEOF:
	XOR	BX,BX ;0 = not EOF
	RET
ER_BFM:	JMP	DERBFM ;"Bad File mode"
;DSKLOC - Number of Bytes in input buffer.
; Entry - SI points to File-Data-Block.
; Exit  - [BX] = result.
;
DSKLOC:
	CMP	byte [F_MODE+SI],MD_RND
	MOV	BX,word [F_CLOC+SI] ;Use current for Sequential
	JNE	LOC1
	MOV	BX,word [FD_LOG+SI] ;Use logical for Random
LOC1:	RET
;DSKLOF - return file size in bytes.
; Entry - SI points to File-Data-Block.
; Exit  - [Floating-Point-Accumulator] = result.
;
DSKLOF:
	LEA	DX,dword [FCB_FS+SI] ;[DX] points to file size
	MOV	BX,DFACLO-1 ;[BX] Target
	MOV	byte [BX+0],0 ;zero overflow byte
	INC	BX
	MOV	CH,4
	CALL	MOVE1 ;Move file length to FAC
	MOV	byte [FAC+1],CH ;zero sign
	MOV	word [BX+0],CX ;zero high bytes of FAC
	MOV	word [BX+2],((128+56)*256) ;Initialize Exponent
	MOV	byte [VALTYP],8 ;Dbl prec value
	JMP	DOL_NORMD ;Normalize value
;DSKGPS - return current file position.
; Entry - SI points to File-Data-Block.
; Exit  - [AH] = current file column. (0-relative)
;         All other registers preserved
;
DSKGPS:	MOV	AH,byte [F_POS+SI] ;[AH]=current column
	RET
;DSKGWD - get device width
; Exit  - [AH] = device width as set by xxxSWD
;         All other registers preserved
;
DSKGWD:	MOV	AH,255 ;disk files always have infinite width
	RET
;DSKSCW - set device comma width
; Entry - [BX] = new device comma width
; Exit  - SI, DI can be changed.
;         All other registers preserved
;
DSKSCW:
;DSKGCW - get device comma width
; Exit  - [BX] = device comma width as set by xxxSCW
;         All other registers preserved
;
DSKGCW:	RET
; SUBTTL  OPEN hook for Disk and all Directory handling
extern INIFDB
extern FILMOD
extern FREFDB
;DSKOPN - perform any device dependent open functions.
; Entry - [AL] = FILDEV = device id
;                0 if default device,
;                1..n for Disk A:, B:, ...
;                -1..-n for non-disk devices
;         [BX] = file number (0..n)
;         [CX] = random record size if [FILMOD] = random
;                (if [CX] = 0, use default record size)
;         [DI] = device offset (2=DSKD, 4=SCRN, etc.)
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
DSKOPN: ;note: save [AL]=device ID till INIFDB
	CMP	byte [FILMOD],MD_RND
	JNZ	DSKOP2 ;branch if not OPEN RANDOM
	OR	CX,CX
	JNZ	DSKOP2 ;branch if user requested Record-Size
	MOV	CX,DATPSC ;default to Bytes per Sector
DSKOP2:	PUSH	CX ;save user requested Random-Record-Size
	ADD	CX,FD_DAT-FDBSIZ ;add standard Disk FDB requirements
	MOV	AH,255 ;all file-modes are legal for Disk
	MOV	DX,255 ;[DH]=initial file column position
;[DL]=initial file width
	CALL	INIFDB ;SI points to new file's FDB
	MOV	word [FREFDB],SI ;save pointer to FDB so FINPRT will
;release it if error occurs before file
;gets completely opened.
	PUSH	SI ;save FDB pointer
	LEA	DI,dword [FCB_DV+SI] ;DI points to filename field within FDB
	MOV	SI,FILNAM
	MOV	CX,FNAML+1 ;Moving drive,name,ext
	CLD ;Set Post-Increment mode
 REP	MOVSB ; to FDB's FCB
	MOV	byte [DI+0],CL ;Make sure ext field is zero
	ADD	DI,FCB_NR-FCB_EX ;Advance to NR field
	MOV	AX,CX ;[AX]=0
	CLD ;Set Post-Increment mode
	STOSW
	STOSW
	STOSB ;zero random record fields
	POP	SI ;SI points to new FDB
	POP	AX ;[AX]=random record size
	MOV	word [FD_SIZ+SI],AX ;save in FDB
	CALL	SETBUF ;Set Buffer addr
	MOV	AL,byte [FILMOD] ;[AL]=file mode
	CMP	AL,MD_APP
	JNZ	NTOAPP ;Brif not open append
	CALL	CHKFOP ;check for file already open
NTOAPP:
	LEA	DX,dword [F_FCB+SI] ;[DX] = FCB for DOS calls
	CMP	AL,MD_SQO
	JNZ	OPNFIL ;Brif not sequential output
	CALL	CHKFOP ;must be unique
mov ah, C_DELE
int 33 ;Delete file if exists
MAKFIL:
mov ah, C_MAKE
int 33 ;Create file
	INC	AL ;Too many files?
	JNZ	OPNSET ;No, continue
	JMP	DERTMF ;"Too many files"
OPNFIL:
mov ah, C_OPEN
int 33 ;Try OPEN
	INC	AL
	JNZ	OPNSET ;Brif found
	MOV	AL,byte [FILMOD] ;Mode
	CMP	AL,MD_APP
	JNZ	NTAPNF ;Brif not append
	MOV	AL,MD_SQO ; else change to seq output
	JMP	MAKFIL
NTAPNF:
	CMP	AL,MD_RND ;If not Random
	JNZ	ER_FNF ; then File not found error
	JMP	MAKFIL ;and create new
ER_FNF:
	JMP	DERFNF ;"File not found"
OPNSET:
	MOV	word [FCB_RC+SI],128 ;Record len = 128
	XOR	CX,CX
	MOV	word [F_CLOC+SI],CX ;Clear curloc
	MOV	word [F_CLOC]+[SI+2],CX ;Clear numloc
	MOV	AL,byte [FILMOD]
	CMP	AL,MD_RND
	JZ	RNDFIN ;Brif finish random open
	CMP	AL,MD_APP
	JZ	APPFIN ;Brif finish append open
	CMP	AL,MD_SQI
	JNZ	OPNFIN ;If not input get text pointer/exit
	CALL	DOL_READS ;Read 1st data block into buffer
OPNFIN:	MOV	word [FREFDB],0 ;file is completely open.
;FINPRT won't release FDB.
	RET
RNDFIN:
	LEA	DI,dword [FD_PHY+SI] ;zero FD.PHY, FD.LOG, FD.OPS, sector buffer
	MOV	CX,(FD_DAT-FD_PHY) ;number of bytes to be cleared
	XOR	AX,AX ;zeros
	CLD ;Set Post-Increment mode
 REP	STOSB ;zero data buffer and variable cells
	JMP	OPNFIN
; Append - Seek to eof, read a sector, find byte eof,
;          correct no. of bytes remaining, finish up
;          by changing file mode to sequential output.
APPFIN:
	CMP	word [FCB_FS+SI],CX ;Test for empty file
	JNZ	NTZRF1 ;Brif file not empty
	CMP	word [FCB_FS]+[SI+2],CX
	JNZ	NTZRF1
	MOV	byte [F_MODE+SI],MD_SQO ;Change mode to Seq output
	JMP	OPNFIN ; and exit
NTZRF1:
	LEA	DI,dword [FCB_RN+SI] ;DI points to random record# field
	PUSH	SI ;Save FDB pointer
	ADD	SI,FCB_FS ;Move to File Size
	TEST	byte [SI+0],127 ;See if multiple of 128
	CLD ;Set Post-Inc mode for next 10 lines
	PUSHF ;and remember
	LODSB ;Get low order of size
	ADD	AL,AL ;Rotate hi bit into carry
	LODSW ;Get middle word
	ADC	AX,AX ;carry in, hi bit out
	STOSW ;Save low word of rec no.
	LODSB ;Get high byte
	MOV	AH,0 ;Clear hi byte of rec no.
	ADC	AX,AX ;consider carry
	STOSW ;Store hi word of rec no.
	POPF ;get record flag
	POP	SI
	JNZ	NOMTRC ;Brif record not empty
	CALL	BAKURN ; else backup so can align
NOMTRC:
	CALL	DOL_READS ;read a sector
	CALL	BAKURN ;back up 1 record
	XOR	DX,DX ;clear count of chars in buff
REDEOF:
	CALL	DSKINP ;read until EOF
	JB	SETSQM ;Brif physical EOF
	CMP	AL,ASCCTZ ;check for logical eof (ctl Z)
	JZ	SETSQO ;Brif found eof
	INC	DX
	JMP	REDEOF
SETSQM:
	XOR	DX,DX ;zero count since next sector
	CALL	BAKURN ;backup since read to far
SETSQO:
	MOV	byte [F_MODE+SI],MD_SQO ;now we're Seq output
	LEA	DI,dword [F_CLOC+SI]
	XOR	AX,AX
	CLD ;Set Post-Increment mode
	STOSW ;zero curloc since empty
	MOV	byte [DI+0],DL ;store no. of bytes left
	MOV	byte [F_POS+SI],AL ;zero print position
	JMP	OPNFIN
BAKURN:
	SUB	word [FCB_RN+SI],1 ;Random rec no. -1
	JAE	BAKRET ;Brif no underflow
	DEC	word [FCB_RN]+[SI+2] ;hi word -1
BAKRET:	RET
; SUBTTL  CLOSE (CLSFIL) hook for Disk files
;DSKCLS - perform any device dependent close functions.
; Entry - SI points to File-Data-Block.
; Exit  - All registers used.
;         This routine is called before BASIC releases the
;         file-data-block associated with this file.
;
DSKCLS:
	CMP	byte [F_MODE+SI],MD_SQO
	JNE	NOFORC ;Don't dump buffer unless Seq Output
	MOV	AL,ASCCTZ
	CALL	FILOU4 ;Write EOF char
	CMP	byte [F_ORCT+SI],0
	JE	NOFORC ;Brif buffer flushed
	CALL	DOL_WRITS ;Flush the buffer
NOFORC:
	CALL	SETBUF ;Set DMA addr
	LEA	DX,dword [F_FCB+SI] ;[DX] = FCB
mov ah, C_CLOS
int 33 ;Close the file
	RET
; SUBTTL Disk Sequential Input
;DSKSIN - Sequential Input.
; Entry - SI points to File-Data-Block.
; Exit  - [AL] = next byte from file,
;         carry set if EOF.
;         All other registers preserved
;
DSKSIN:	CALL	DSKINP ;get next byte from file
	JB	DSYEOF ;branch if End-Of-File
	CMP	AL,ASCCTZ ;check for CTL-Z
	JNE	DSNEOF ;branch if not
	CMP	byte [F_CODE+SI],FC_BIN
	JE	DSNEOF ;CTL-Z is not EOF for Binary files
DSYEOF:	STC ;set carry indicating EOF
	RET
DSNEOF:	OR	AL,AL ;clear carry (no eof)
	RET
;DSKINP - get next byte from file [SI]
; Exit  - Carry set if EOF, else [AL]=next byte from file
;         All other registers preserved
;
DSKINP:
	CMP	byte [F_MODE+SI],MD_RND
	JNE	SINP1 ;Brif not Random
	JMP	SINP50 ;Do Serial input from random
SINP1:
	CMP	byte [F_MODE+SI],MD_SQO ;If trying input on output file
	JE	FILLS1 ; then give "Input past end"
	CMP	byte [F_BREM+SI],0
	JE	FILLSQ ;If buffer empty, get another
	PUSH	BX
	XOR	BX,BX
	MOV	BL,byte [F_ORCT+SI]
	SUB	BL,byte [F_BREM+SI]
	DEC	byte [F_BREM+SI] ;number left -1
	MOV	AL,byte [DATOFS][BX+SI] ;Get the character
	POP	BX
	OR	AL,AL ;Clear carry
	RET
FILLSQ:
	CMP	byte [F_ORCT+SI],0
	JE	FILLS1 ;Brif EOF
	CALL	DOL_READS ;read next sector
	JNE	SINP1 ;If not EOF try again
FILLS1:
	STC ;Return with carry
	MOV	AL,ASCCTZ ; and EOF character
	RET
SINP50: ;Serial Input from Random File
	PUSH	BX
	CALL	FOVCHK ;Field overflow check
	MOV	AL,byte [FD_DAT]-[BX+SI+1] ;Get character
	CLC
	POP	BX
	RET
FOVCHK:
	MOV	BX,word [FD_OPS+SI] ;Get current posn
	CMP	BX,word [FD_SIZ+SI] ;check for end of field
	JE	ER_FOV ;Brif field overflow
	INC	BX ;posn +1
	MOV	word [FD_OPS+SI],BX ;store new posn
	RET
ER_FOV:
	JMP	DERFOV ;"Field Overflow"
; SUBTTL Disk Sequential Output
;DSKSOT - Sequential Output.
; Entry - SI points to File-Data-Block.
;         [AL] = byte to be output.
; Exit  - All registers preserved.
;
DSKSOT:
	CMP	byte [F_MODE+SI],MD_SQI ;If input then must be echoing
	JZ	FILOUX ; or "Extra ignored", so toss it
	CMP	byte [F_MODE+SI],MD_RND
	JNZ	FILOU4 ;branch if sequential access
	PUSH	BX ;Do Serial output to random
	CALL	FOVCHK ;check for FIELD overflow
	MOV	byte [FD_DAT]-[BX+SI+1],AL ;store character
	POP	BX
	JMP	SOUTPS ;Update posn and exit
FILOU4:
	CMP	byte [F_ORCT+SI],DATPSC
	JNE	SOUT2 ;Brif not at end of sector
	CALL	DOL_WRITS ;Write previous sector
SOUT2:
	PUSH	BX
	XOR	BX,BX
	MOV	BL,byte [F_ORCT+SI] ;[BX] = Buffer offset
	MOV	byte [DATOFS][BX+SI],AL ;store char
	POP	BX
	INC	byte [F_ORCT+SI]
SOUTPS:
	CMP	AL,ASCCR
	JNE	SOUT3
	MOV	byte [F_POS+SI],0 ;reset posn on CR
FILOUX:
	RET
SOUT3:
	CMP	AL," "
	CMC
	ADC	byte [F_POS+SI],0 ;posn +1  if printable char
	RET
; SUBTTL GET and PUT for Disk Files
%define PGFLAG 1 ;On = PUT, Off = GET
%define RELFLG 2 ;On = Relative, Off = Sequential
%define DIRFLG 4 ;On = Write, Off = Read
ER_BRN:	JMP	DERBRN ;bad record number error
ER_FC:	JMP	FCERR ;function call error
;DSKRND - perform random I/O.
; Entry  - [AL] = function to be performed:
;                 0: get next record
;                 1: put next record
;                 2: get record [DX] (1-relative)
;                 3: put record [DX] (1-relative)
;          [SI] points to File-Data-Block
; Exit   - All registers are used.
;
DSKRND:
	TEST	AL,RELFLG
	JNZ	RAND1 ;Brif not relative I/O
	MOV	DX,word [FD_LOG+SI] ;[DX] = current logical record
	INC	DX ;Logical +1
	JMP	RAND2
RAND1:
	OR	DX,DX ;See if ok
	JLE	ER_BRN ;Error if record number .LEQ. 0
RAND2:
	MOV	word [FD_LOG+SI],DX ;Store next logical
	DEC	DX ;[DX] = current logical
	MOV	word [FD_OPS+SI],0 ;Clear output posn
	MOV	BX,word [FD_SIZ+SI] ;[BX] = logical record length
	PUSH	BX
	CMP	BX,DATPSC ;Logical = Physical?
	JE	RAND3 ;Brif so
	XCHG	AX,BX ;Save flags
	MUL	DX ;Logical * physical (byte off)
	XCHG	AX,BX ;[DX,BX] = result
	ADD	BX,BX ;Offset *2 (for /128)
	ADC	DX,DX ;consider overflow
	OR	DH,DH
	JNZ	ER_FC ;Brif too big
	MOV	DH,DL
	MOV	DL,BH ;[DX] = physical record no.
	SHR	BL,1
	XOR	BH,BH ;[BX] = offset into physical rec
	JMP	RAND4
RAND3:
	XOR	BX,BX ;[BX] (offset = 0)
; [DX] = physical record number
; [BX] = offset into physical record
RAND4:
	MOV	word [RECRD],DX ;Save record no.
	LEA	CX,dword [FD_DAT+SI] ;[CX] = Field buffer addr
	MOV	word [LBUFF],CX ;Save Logical buffer addr
	POP	DX ;Get record length
; [DX] = bytes left to transfer (initially record length)
; [BX] = offset into current record
NXTOPD:
	LEA	CX,dword [DATOFS+SI] ;[CX] = Physical buffer addr
	ADD	CX,BX ;       + offset
	MOV	word [PBUFF],CX ;Save physical offset
	MOV	CX,DATPSC
	SUB	CX,BX ;[CX] = bytes left in buffer
	CMP	CX,DX ;want smaller of bufl, recl
	JB	DATMOF ;[CX] = left in buffer
	MOV	CX,DX ;[CX] = left in record
DATMOF:
	TEST	AL,PGFLAG
	JZ	FIVDRD ;Brif read (GET)
	CMP	CX,DATPSC
	JAE	NOFVRD ;Brif writing entire sector
	CALL	GETSUB ; else read current sector
NOFVRD:
	PUSH	SI
	PUSH	CX
	MOV	SI,word [LBUFF]
	MOV	DI,word [PBUFF]
	SHR	CX,1
	CLD ;Set Post-Increment mode
 REP	MOVSW
	JNB	EVENLP
	MOVSB
EVENLP:
	POP	CX
	POP	SI
	CALL	PUTSUB ;Write thru to current sector
	JMP	NXFVBF
FIVDRD:
	CALL	GETSUB ;Read current record
	PUSH	SI
	PUSH	CX
	MOV	SI,word [PBUFF]
	MOV	DI,word [LBUFF]
	SHR	CX,1
	CLD ;Set Post-Increment mode
 REP	MOVSW
	JNB	EVENPL
	MOVSB
EVENPL:
	POP	CX
	POP	SI
NXFVBF:
	INC	word [RECRD] ;current record +1
	ADD	word [LBUFF],CX ;logical offset +length
	SUB	DX,CX ;offset - bytes transfered
	XOR	BX,BX ;zero buffer offset
	OR	DX,DX ;More to transfer?
	JNZ	NXTOPD ; then continue
	RET
; Sector I/O routines for Random
PUTSUB:
	OR	AL,DIRFLG ;Set write flag
	JMP	PGSUB1
GETSUB:
	AND	AL,255-DIRFLG ;Clear write flag (read)
PGSUB1:
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	MOV	BX,word [RECRD] ;Get record no.
	INC	BX
	CMP	BX,word [FD_PHY+SI] ;current record in buffer?
	JNE	NTREDS ;Brif not
	TEST	AL,DIRFLG ;Was it read?
	JZ	PGRET ; then got it
NTREDS:
	DEC	BX
	MOV	word [F_CLOC+SI],BX ;Set CURLOC to physical rec.
	MOV	byte [F_ORCT+SI],DATPSC
	MOV	byte [F_BREM+SI],DATPSC
	MOV	word [FCB_RN+SI],BX ;Set record number
	MOV	word [FCB_RN]+[SI+2],0
	TEST	AL,DIRFLG
	JZ	GET1 ;Brif read
	CALL	DOL_WRITS ; else Write it
	JMP	PGRET
GET1:
	CALL	DOL_READS ;Read it
PGRET:	POP	DX
	POP	CX
	POP	BX
	POP	AX
	RET
; SUBTTL Primitive Disk sector I/O routines
;$READS - Read sector from file
; Entry - SI points to FDB
; Exit  - [AL] = 0 if no error.  FLAGS used.
;         All other registers are preserved
;
DOL_READS:
	PUSH	CX
	PUSH	DI
	INC	word [F_CLOC+SI] ;Logical record +1
	MOV	CX,DATPSC/2
	XOR	AX,AX
	LEA	DI,dword [DATOFS+SI]
	CLD ;Set Post-Increment mode
 REP	STOSW ;zero physical buffer
	CALL	SETBUF ;Set DMA
	MOV	AH,C_RNDR
	CALL	ACCFIL ;Read random
	OR	AL,AL
	MOV	AL,0 ;Len = 0 for EOF
	JNZ	READ1
	MOV	AL,DATPSC ; else len = sector size
READ1:
	MOV	byte [F_ORCT+SI],AL ;Clear offset into buffer
	MOV	byte [F_BREM+SI],AL ;Set number of bytes left
	OR	AL,AL ;zero if EOF
	POP	DI
	POP	CX
	RET
;$WRITS - Write sector to file
; Entry - SI points to FDB
; Exit  - All registers preserved
;
DOL_WRITS:
	PUSH	AX
	MOV	byte [F_ORCT+SI],0 ;Clear buffer offset
	CALL	SETBUF ;Set DMA
	MOV	AH,C_RNDW
	CALL	ACCFIL ;Write Random
	CMP	AL,255
	JZ	ER_TMF ;Brif "Too many Files"
	DEC	AL
	JZ	ER_IOE ;Brif error extending file
	DEC	AL
	JNZ	WRITE1
	MOV	byte [F_MODE+SI],MD_SQI ;So CLOSE won't give same error
;when it tries to output CTL-Z EOF
	JMP	DERDFL ;"Disk Full"
WRITE1:
	INC	word [F_CLOC+SI] ;Logical record +1
	POP	AX
	RET
ER_TMF:	JMP	DERTMF ;"Too many Files"
ER_IOE:	JMP	DERIOE ;"Device I/O error"
;Set OS I/O buffer address to DATOFS(.SI)
;
SETBUF:
	PUSH	DX
	LEA	DX,dword [DATOFS+SI] ;[DX] = Data buffer addr
mov ah, C_BUFF
int 33
	POP	DX
	RET
ACCFIL:
	PUSH	DX
	LEA	DX,dword [F_FCB+SI] ;[DX] = FCB
int 33 ;Do OS I/O Op
	INC	word [FCB_RN+SI] ;Record no. +1
	JNZ	ACCFL1
	INC	word [FCB_RN]+[SI+2] ;High order +1
ACCFL1:
	CMP	AH,C_RNDW ;Was it Random Write?
	JNE	ACCFL2 ;Brif not
	OR	AL,AL ; else map into 1.4 errors
	JZ	ACCRET ;Brif no errors
	CMP	AL,5
	JE	ER_TMF ;5 - Too many files
	CMP	AL,3
	MOV	AL,1 ;Map 5 to 1
	JE	ACCRET
	INC	AL ; else Disk full
	JMP	ACCRET
ACCFL2:
	CMP	AL,3 ;Partial sector read?
	JNE	ACCRET ;Brif not
	XOR	AL,AL ;Map 3 to 0 (no error)
ACCRET:
	POP	DX
	RET
; SUBTTL CHKFOP - Check for file already OPEN
extern FILTAB
extern STKLOW
; Entry: SI points to FDB in question
; Exit:  Control returns to DERFAO if file is open
; Uses:  CX,DI
;
CHKFOP:
	PUSH	AX
	CMP	byte [FCB_DV+SI],0 ;Default Drive?
	JNE	NTCRDV
mov ah, C_GDRV
int 33
	INC	AL ;Convert A: to 1.. etc.
	MOV	byte [FCB_DV+SI],AL ;Store real drive no.
NTCRDV:
	MOV	DI,word [FILTAB] ;Start with first FDB in chain
CHKNFL:
	CMP	DI,word [STKLOW]
	JE	CHKFLX ;branch if at end of FDB chain
	CMP	SI,DI
	JE	IGNTFL ;branch if same as FDB in question
	PUSH	SI
	PUSH	DI
	ADD	SI,F_FCB
	ADD	DI,F_FCB
	MOV	CX,FNAML+1
;compare filenames, mapping lower case to upper case
CMPLOP:
	MOV	AL,byte [SI+0] ;get char from filename1
	CALL	MAKUPC ;[AL]=uppercase([AL])
	MOV	AH,AL
	MOV	AL,byte [DI+0] ;get char from filename2
	CALL	MAKUPC ;[AL]=uppercase([AL])
	CMP	AL,AH
	JNE	NTSAME ;branch if not the same filename
	INC	SI ;bump filename1 pointer
	INC	DI ;bump filename2 pointer
	LOOP	CMPLOP ;compare all characters in filenames
	JMP	DERFAO ;error, file already open
NTSAME:	POP	DI
	POP	SI
IGNTFL:
	MOV	DI,word [F_NEXT+DI] ;get next FDB in chain
	JMP	CHKNFL
CHKFLX:
	POP	AX
	RET
MAKUPC:
	CMP	AL,"a"
	JB	NOTLC ;branch if not a..z
	CMP	AL,"z"+1
	JNB	NOTLC ;branch if not a..z
	AND	AL,0o337 ;map a..z to A..Z
NOTLC:
	RET
; SUBTTL  DFSTLD - Fast Binary Program Load (from DISK)
global DFSTLD
extern OUTLOD
extern FRETOP
extern PTRFIL
;DFSTLD - read block of memory from Disk
; Entry - [BX] = offset of destination
;         [CX] = maximum number of bytes to read
;         [DX] = data segment of destinanation
;         PTRFIL points to FDB of file to be loaded
; Exit  - BX points 1 byte beyond last byte read
;         Carry set reached end-of-file before CX bytes were read
;
DFSTLD:
	PUSH	BX ;save start adr
	PUSH	CX ;save max byte count
	PUSH	DS ;save BASIC's Data Segment adr
	PUSH	BX ;save start adr
	PUSH	DX ;save block read Data Segment adr
	MOV	SI,word [PTRFIL] ;SI points to current FDB
	MOV	AL,byte [F_ORCT+SI]
	SUB	AL,byte [F_BREM+SI] ;[AL]=# bytes read so far
	MOV	byte [FCB_RN+SI],AL ;set next rec #
	MOV	word [FCB_RC+SI],1 ;Set File logical record size = 1 byte
	POP	DS ;[DS]=segment adr of block read
	POP	DX ;[DX]=start adr
mov ah, C_BUFF
int 33 ;Set DMA to TXTTAB
	POP	DS ;restore BASIC's data segment adr
	LEA	DX,dword [F_FCB+SI] ;FCB
	POP	CX ;[CX]=max number of bytes to read
mov ah, C_RBR
int 33 ;Load the Program!
	POP	BX ;BX points to start of load
	ADD	BX,CX ;BX points 1 byte beyond last byte read
	CMP	AL,1
	CMC ;set carry if [AL] exceeds 1 (EOF)
	RET
; SUBTTL  PROSAV - Protected SAVE
global PROSAV
global CMPFBC
extern SCCPTR
extern GTMPRT
extern BINPSV
extern DOL_EXPCN
extern DOL_LOGP
extern TXTTAB
extern VARTAB
extern CURLIN
extern PROFLG
extern TEMP
PROSAV:	CALL	CHRGTR ;skip "P"
	MOV	word [TEMP],BX ;Save text pointer
	CALL	SCCPTR ;Get rid of GOTO pointers
	CALL	PENCOD ;Encode binary
	MOV	AL,254 ;ID byte for Protected files
	CALL	BINPSV ;Do the SAVE
	CALL	PDECOD ;Decode binary
	JMP	GTMPRT ;return to NEWSTT
GETFSZ:	MOV	BX,FD_SIZ ;Point to record size
	JMP	GETFP1 ;Continue
GETFPS:	MOV	BX,FD_OPS ;Point to output position
GETFP1:	ADD	BX,CX ;Add offset into buffer
	MOV	DX,word [BX+0] ;Get value
	RET
CMPFBC:	MOV	CX,BX ;Copy file data block into [CX]
CMPFPS:	CALL	GETFPS ;Get present posit
	PUSH	DX ;Save it
	CALL	GETFSZ ;Get file size
	MOV	BX,DX ;into [BX]
	POP	DX ;Get back posit
	CMP	BX,DX ;See if were at end
RET12:	RET
%define N1 11 ;Number of bytes to use from ATNCON
%define N2 13 ;Number of bytes to use from SINCON
global PENCOD
PENCOD:	MOV	CX,N1+N2*256 ;Initialize both counters
	MOV	BX,word [TXTTAB] ;Starting point
	MOV	DX,BX ;Into [DX]
ENCDBL:	MOV	BX,word [VARTAB] ;At end?
	CMP	BX,DX ;Test
	JZ	RET12 ;Yes
	MOV	BX,DOL_EXPCN
	MOV	AL,CL ;Use [CL] to index into it
	CBW
	ADD	BX,AX
	MOV	SI,DX
	CLD ;Set Post-Increment mode
	LODSB ;[AL]=byte from program
	SUB	AL,CH ;Subtract counter for no reason
	XOR	AL,byte [CS:BX+0] ;XOR entry
	PUSH	AX ;Save result
	MOV	BX,DOL_LOGP
	MOV	AL,CH
	CBW
	ADD	BX,AX
	POP	AX ;Get back current byte
	XOR	AL,byte [CS:BX+0] ;XOR on this one too
	ADD	AL,CL ;Add counter for randomness
	MOV	DI,DX
	CLD ;Set Post-Increment mode
	STOSB ;store back in program
	INC	DX ;Incrment pointer
	DEC	CL ;decrment first table index
	JNZ	CNTZER ;Still non-Zero
	MOV	CL,N1 ;Re-initialize counter 1
CNTZER:	DEC	CH ;dedecrement counter-2
	JNZ	ENCDBL ;Still non-zero, go for more
	MOV	CH,N2 ;Re-initialize counter 2
	JMP	ENCDBL ;Keep going until done
global PROLOD
PROLOD:
PDECOD:	MOV	CX,N1+N2*256 ;Initialize both counters
	MOV	BX,word [TXTTAB] ;Starting point
	MOV	DX,BX ;Into [D,E]
DECDBL:	MOV	BX,word [VARTAB] ;At end?
	CMP	BX,DX ;Test
	JZ	RET12 ;Yes
	MOV	BX,DOL_LOGP
	MOV	AL,CH
	CBW
	ADD	BX,AX
	MOV	SI,DX
	CLD ;Set Post-Increment mode
	LODSB ;[AL]=byte from program
	SUB	AL,CL ;Subtract counter for randomness
	XOR	AL,byte [CS:BX+0] ;XOR on this one too
	PUSH	AX ;Save result
	MOV	BX,DOL_EXPCN
	MOV	AL,CL ;Use [CL] to index into it
	CBW
	ADD	BX,AX
	POP	AX ;Get back current byte
	XOR	AL,byte [CS:BX+0] ;XOR entry
	ADD	AL,CH ;Add counter for no reason
	MOV	DI,DX
	CLD ;Set Post-Increment mode
	STOSB ;store [AL] back in program
	INC	DX ;Increment pointer
	DEC	CL ;decrment first table index
	JNZ	CNTZR2 ;Still non-Zero
	MOV	CL,N1 ;Re-initialize counter 1
CNTZR2:	DEC	CH
	JNZ	DECDBL ;Decrement counter-2, Still non-zero, go for more
	MOV	CH,N2 ;Re-initialize counter 2
	JMP	DECDBL ;Keep going until done
global PROCHK
global PRODIR
PRODIR:	PUSH	BX ;Save [H,L]
	MOV	BX,word [CURLIN] ;Get current line #
	INC	BX ;Direct? (if BX=0, direct)
	POP	BX ;Restore [H,L]
	JZ	PROCHK
	RET
PROCHK:	PUSHF ;Save flags
	MOV	AL,byte [PROFLG] ;Is this a protected file?
	OR	AL,AL ;Set CC's
	JNZ	FCERRA ;Yes, give error
	POPF ;Restore flags
	RET
FCERRA:	JMP	FCERR
; SUBTTL  KILL, FILES, NAME commands
global FILES
global KILL
global NAME
extern FRMEVL
extern FRESTR
extern CRDO
extern POLKEY
extern LINLEN
extern BUF
;Assumptions:
; FILNAM and FILNA2 are 33 byte buffers (for temp FCBs)
;FILES [ filename ]
; FILES command [List the Directory]
; If filename is omitted, all files on the logged
; disk are listed.
; If supplied, all files matching filename or wildcards
; are listed.
;
FILES:
	JE	NOARG ;Brif no filename argument given
	CALL	NAMFIL ;[SI] points to 1st byte of filename
;[CX] = number of bytes in filename
	CMP	CL,2
	JNE	GOTNAM ;branch if not "<drive>:"
	MOV	AX,word [SI+0] ;[AX]=filename
	CMP	AH,":"
	JNE	GOTNAM ;branch if not "<drive>:"
	MOV	SI,FILNA2+2 ;[SI] points to buffer for building filename
	MOV	word [FILNA2],AX ;Store <drive>: in filename buffer
	JMP	ALFILS ;append "*.*" to name
NOARG:
	MOV	SI,FILNA2 ;[SI] points to buffer for building filename
	XOR	CX,CX
ALFILS:
	MOV	word [SI+0],(0o400*".")+"*"
	MOV	word [SI+2],"*"
	ADD	CX,3 ;[CX] = number of bytes in filename
	MOV	SI,FILNA2 ;[SI] points to filename
GOTNAM:
	CALL	FILFCB ;FILNAM=un-opened FCB for filename
	MOV	DX,FILNA2 ;tells OS to put FCB for matching directory
mov ah, C_BUFF
int 33 ; entries in FILNA2
	MOV	DX,DI ;[DX] = search FCB (FILNAM)
mov ah, C_SEAR
int 33 ;Search 1st
	INC	AL
	JNZ	FILNXT ;Brif found
	JMP	DERFNF ; else complain
FILNXT:
	CALL	POLKEY ;Allow CTL-C, CTL-S between every filename
	MOV	SI,FILNA2+1 ;Point at name
	MOV	CX,FNAML ;Characters in name
MORNAM:
	CLD ;Set Post-Increment mode
	LODSB ;Get character
	CALL	OUTDO ;Output it
	CMP	CX,4
	JNE	NOTEXT ;Not at extension break
	MOV	AL,byte [SI+0] ;Get 1st char of extension
	CMP	AL," "
	JE	PRISPA ;Blank extension - print space
	MOV	AL,"." ;Print .
PRISPA:
	CALL	OUTDO ;Print blank or dot
NOTEXT:
	LOOP	MORNAM ;Loop until 11 characters
extern PTRWID
	CALL	PTRWID ;[AH]=line width
	MOV	CH,AH ;[CH]=line width
extern PTRGPS
	CALL	PTRGPS ;[AL]=current column
	ADD	AL,14 ;Position after next file name
	CMP	AL,CH
	JAE	NWFILN ;Force CR/LF
	MOV	AL," "
	CALL	OUTDO
	JMP	NEXTFL
NWFILN:
	CALL	CRDO ;Type CR/LF
NEXTFL:
	MOV	DX,FILNAM ;[DX] points to search template
	XOR	AL,AL
mov ah, C_SEAR+1
int 33 ;Search next
	CMP	AL,255
	JNE	FILNXT ;branch if still more
extern CRDONZ
	JMP	CRDONZ ;carriage return if not in column 0
;KILL filename
; Entry - [BX] = text pointer
; Exit -  [BX] = text pointer
;
KILL:
	CALL	NAMFIL ;[SI] points to 1st byte of filename
;[CX] = number of bytes in filename
	CALL	FILFCB ;FILNAM=un-opened FCB for filename
	PUSH	BX ;save text pointer
	MOV	DX,FILNAM
	PUSH	DX ;Save FCB pointer
mov ah, C_OPEN
int 33 ;Open file
	INC	AL
	JNZ	KILL2 ;Brif file found
	JMP	DERFNF ;File not found
KILL2:	POP	DX ;DX points to FCB
	PUSH	DX
mov ah, C_CLOS
int 33 ;Close file
	MOV	SI,FILNAM-F_FCB ;Pretend we are FDB
	CALL	CHKFOP ;Check for conflict with open files
;jumps to error if file is now opened
	POP	DX ;DX points to FCB
mov ah, C_DELE
int 33 ;Delete file
	POP	BX ;text pointer
	RET
;NAME oldname AS newname
; Entry - [BX] = text pointer
; Exit  - [BX] = text pointer
;
NAME:
	CALL	NAMFIL ;[SI] points to 1st byte of old filename
;[CX] = number of bytes in filename
	PUSH	BX ;save text pointer
	CALL	FILFCB ;FILNAM=un-opened FCB for old filename
	MOV	DX,FILNA2 ;tells OS to put FCB for matching directory
mov ah, C_BUFF
int 33 ; entries in FILNA2
	MOV	DX,DI ;[DX] = search FCB (FILNAM)
mov ah, C_SEAR
int 33 ;Search 1st
	INC	AL
	JZ	NA_FNF ;File not found
	MOV	SI,FILNAM-F_FCB ;Pretend we are FDB
	CALL	CHKFOP ;Check for conflict with open files
;jumps to error if file is now opened
	MOV	SI,FILNAM ;save old filename in FILNA2
	MOV	DI,FILNA2
	MOV	CX,FNAML+1 ;+1 for drive
	CLD ;Set Post-Increment mode
 REP	MOVSB ;Move drive,name,ext from FILNAM to FILNA2
	POP	BX ;text pointer
	CALL	SYNCHR
db "A" ; must see "AS"
	CALL	SYNCHR
db "S"
	CALL	NAMFIL ;[SI] points to 1st byte of newfilename
;[CX] = number of bytes in filename
	PUSH	BX ;text pointer
	CALL	FILFCB ;FILNAM=un-opened FCB for new filename
	MOV	AL,byte [FILNAM] ;[AL]=drive for New filename
	OR	AL,AL ;test drive id of New filename
	JZ	SAMDRV ;branch if default drive
	CMP	AL,byte [FILNA2] ;Compare with drive of original name
	JZ	SAMDRV ;branch if both drives are the same
extern DERRAD
	JMP	DERRAD ;Rename Across Disks Error
SAMDRV:
	MOV	SI,FILNAM+1 ;move new filename,ext to FILNA2+17
	MOV	DI,FILNA2+17 ;[DI] = dest for new file name
	MOV	CX,FNAML ;No drive code
	CLD ;Set Post-Increment mode
 REP	MOVSB ;Move name
	MOV	DX,FILNA2 ;Point to FCB which contains both filenames
mov ah, C_RENA
int 33 ;Rename file
	INC	AL ;error if attempted to create file which
	JE	NA_FAE ; already existed
	POP	BX ;text pointer
	RET
NA_FNF:	JMP	DERFNF ;file not found
NA_FAE:	JMP	DERFAE ;file already exists
;NAMFIL - Scan a file name for NAME, KILL, or FILES command
; Entry - [BX] = text pointer
; Exit  - [BX] = text pointer
;         [SI] points to 1st byte of filename
;         [CX] = number of bytes in filename string
; Uses  - [AX]
;
NAMFIL:
	CALL	FRMEVL ;Evaluate string
	PUSH	BX ;save text pointer
	CALL	FRESTR ;Free the temp
	MOV	CL,byte [BX+0]
	XOR	CH,CH ;[CX] = String len
	JCXZ	ER_NMF ;If null then bad name
	MOV	SI,word [BX+1] ;[SI] = Filename string
	POP	BX
	RET
ER_NMF:	JMP	DERNMF ;"Bad file name"
;FILFCB - Given filename "d:name:ext", create an un-opened FCB
; Entry - [SI] = points 1st byte of filename
;         [CX] = number of bytes in filename string
; Exit  - FILNAM is un-opened FCB equivalent for filename
;         [DI] points to 1st byte of FCB FILNAM
;         [AL] = FF if illegal drive or filename,
;                 1 if filename contained any "?" or "*" characters
;                 0 otherwise
; Uses  - BUF
;
FILFCB:
	MOV	DI,BUF ;move filename to BUF buffer
	CLD ;Set Post-Increment mode
STRTNM:	XOR	AH,AH ;Count of chars in name portion:=0.
NAMORE:	OR	CX,CX ;Anything left?
	JE	TRMSTR ;No, go terminate the string in BUF.
	MOV	AL,byte [SI+0] ;Yes, AL:=get next char of string.
	MOVSB ;Copy it to BUF.
	DEC	CX ;Decrement the length.
	CMP	AL,":" ;Colon indicating we were looking at a
;device name?
	JE	STRTNM ;Yes, restart the count since we are now
;looking at the filename.
	CMP	AL,"." ;No, dot indicating start of extension?
	JE	FINNAM ;Yes, end of name.
	CMP	AL,"*" ;The asterisk wild card also terminates the
	JE	FINNAM ;name for our purposes.
	CMP	AH,8 ;Have we already seen 8 name characters?
	JAE	LNGNAM ;Yes, the excess chars become the extension.
	INC	AH ;No, increment the name character count.
	JMP	NAMORE ;Go look at the next char.
LNGNAM:	MOV	byte -[DI+1],"." ;Put in the dot so the extra chars look
	MOV	byte [DI+0],AL ;like an extension.
	INC	DI
FINNAM:	OR	CX,CX ;Anything left?
	JE	TRMSTR ;No, terminate the string.  (Avoid REP with
;a zero count.)
 REP	MOVSB ;Copy the remainder of the string to BUF.
TRMSTR:	MOV	byte [DI+0],0 ;store string terminator
	MOV	SI,BUF ;parse 0 terminated filename in BUF
	MOV	DI,FILNAM ; filling FDB FILNAM
	XOR	AL,AL ; don't skip any separators
mov ah, C_PARS
int 33
	OR	AL,AL ;test for legal filename
	JNE	FLFCBX ;branch if error or non-empty filename
	CMP	byte [FILNAM+1]," " ;test 1st byte of filename
	JNE	FLFCBX ;branch if non-empty filename
	DEC	AL ;[AL] = FF (illegal filename)
FLFCBX:
	RET
; SUBTTL  RESET and SYSTEM statements
;
; Entry/exit:   [BX] = text pointer
global RESET
extern CLSALL
extern TKEYOF
RESET:
	JNZ	RESETX ;if wasn't EOS
	PUSH	BX ;text pointer
	CALL	CLSALL ;Close all files
mov ah, C_GDRV
int 33 ;Get drive number
	PUSH	AX
mov ah, C_REST
int 33 ;Restore
	POP	AX
	MOV	DL,AL
mov ah, C_SDRV
int 33 ;Set drive number
	POP	BX ;text pointer
RESETX:
	RET
; SYSTEM - Exit BASIC
global SYSTEM
global SYSTME
extern GWTERM
SYSTEM:
	JNZ	RESETX ;If wasn't EOS
	CALL	CLSALL ;Close all files
SYSTME:
extern GIOTRM
	CALL	GIOTRM ;call device termination routines
	CALL	GWTERM ;Do OEM specific termination processing
extern CPMEXT ;MSDOS exit jump vector.
;translator can't handle JMPI ,adr yet
	PUSH	word [CPMEXT+2] ;put segment adr on stack
	PUSH	word [CPMEXT] ;put offset on stack
dumy  PROC    FAR
	RET ;intra-segment return
dumy  ENDP
