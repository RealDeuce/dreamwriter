; Auto-converted mechanically from ../gw-basic/scnedt.asm
; Edit the converter or the generated source deliberately; do not hand-wave syntax changes.

; [ This translation created 10-Feb-83 by Version 4.3 ]
; .RADIX  8
%include "dwoem.inc"
; TITLE   SCNEDT  Screen Oriented Editor for GW-BASIC
; SUBTTL  DATA DEFINITIONS
; COMMENT *
;         --------- --- ---- -- ---------
;         COPYRIGHT (C) 1982 BY MICROSOFT
;         --------- --- ---- -- ---------
%include "gio86u.inc"
; .RADIX	8
;OEM IFNDEF'S:
%define MELCO 0o0
%define HAL 0o0
;GENERIC IFNDEF'S:
%define TERMSW 0o0
%define HLPTRP 0o0
%define STPTRP 0o0
%define HLPEDT 0o0
%define SCRKEY 0o0
%define NMPAGE 0o0
%define IBMCSR IBMLIK
;INTERNAL ROUTINES:
global PINLIN ; Program line input
;on exit:       BX=addr of input -1
global INLIN ; BASIC INPUT Statements line input
;on exit:       BX=addr of input -1
global SINLIN ; BASIC INPUT Statements redo line input
;on exit:       BX=addr of input -1
global QINLIN ; BASIC INPUT Statements with output of "?" first
;on exit:       BX=addr of input -1
global SCNSEM ; BASIC INPUT statement scan for semicolon
;on exit:       SEMFLG flag set
global EDTBRK ; BASIC received break, reinitialize routine
global ERREDT ; BASIC Syntax error auto-edit on ERRLIN
;on exit:       Removes return and jumps to MAIN after
;               listing ERRLIN and positioning cursor at
;               start of line.
global EDIT ; EDIT Statement
;on exit:       Same as ERREDT, except takes line number
;               to list as argument.
;       INTERN  EDITRT          ; AUTO Program line input processing
;on exit:       BX=addr of input(BUF)
;               it also puts PSW on stack with carry
;               set and jumps to EDENT for exit
;EXTERNAL ROUTINES:
extern OUTDO ; Character output(GIO86)
extern KEYIN ; Key input(expands any string keys-GIOKYB)
extern SCNMRK ; Mark current posn as start of line(SCNDRV)
extern SCNRDL ; Read current logical line(SCNDRV)
extern CRDO ; BASIC new line routine
extern CHRGTR ; BASIC character scan routine
;DATA (DEFINED IN RAM MODULE)
extern F_EDPG ; Flag - =^O377 indicates program statement edit
extern SEMFLG ; Flag - zero indicates INPUT; statement(no crlf
;       at end of input line)
extern F_INST ; Flag - =^O377 indicates insert mode
extern BUF ; Buffer where line of data is returned
;   NOTE: assumes non-blank at BUF-1
extern F_EDIT ; Flag - non-zero indicates INLIN active
extern AUTFLG ; AUTO mode flag
extern CSRX ; Cursor column (1..n)
extern CSRY ; Cursor line (1..n)
;LITERALS NEEDED ELSEWHERE
global CHRLNF ; Line feed character
global CHRRET ; Carriage return character
;CHARACTER DEFINITIONS
;
;
%define CHREDT 0o1 ; EDiT
%define CHRBKW 0o2 ; BacK Word
%define CHRCAN 0o3 ; CANcel
%define CHRHCN 0o4 ; Hard CaNcel
%define CHRCLE 0o5 ; CLear to End of line
%define CHRFDW 0o6 ; ForwarD Word
%define CHRBEL 0o7 ; BELl
%assign CHRBAK 8 ; BAcKspace
%assign CHRTAB 9 ; TAB
%assign CHRLNF 10 ; LiNeFeed
%assign CHRHOM 11 ; HOMe
%assign CHRERA 12 ; ERAse
%assign CHRRET 13 ; RETurn
%assign CHRAPP 14 ; APPend
%assign CHRINS 18 ; INSert
%assign CHRLDL 21 ; Line DeLete
%assign CHRADV 28 ; cursor RiGhT
%assign CHRREG 29 ; cursor LeFT
%assign CHRUP 30 ; cursor UP
%assign CHRDWN 31 ; cursor DoWN
%assign CHRDEL 127 ; DELete
; SUBTTL  Entry points for editing
;ENTRY: PINLIN, QINLIN, INLIN, SINLIN
;
;PROGRAM STATEMENT INPUT
global PINLIN
PINLIN:	CALL	DSKCHI ; Don't return if Loading ASCII File
	STC ; Indicate program statement input
	JMP	INLIN0
;PRINT "?" BEFORE GETTING INPUT
global QINLIN
QINLIN:	MOV	AL,"?"
	CALL	OUTDO ; Output a "?"
	MOV	AL," "
	CALL	OUTDO ; Followed by a space
;INPUT STATEMENT
global INLIN
INLIN:
;INPUT STATEMENT REDO
global SINLIN
SINLIN:	OR	AL,AL ; Indicate INPUT statement line input
INLIN0:
	SBB	AL,AL ; If INPUT statement AL=0, else AL=-1
	MOV byte [F_EDPG], AL ; Save flag
	MOV AL, byte [F_EDIT] ; Get old value of F.EDIT(in case of EDIT statement)
	MOV byte [F_EDIT], 0o377 ; Indicate executing INLIN
	CALL	SCNMRK ; Set up for edit
;   If AL=1 then move cursor to start of logical
;       line which preceeds current.
;   Else if ZF=1 then set up FSTPOS, LSTPOS
;        if ZF=0 then FSTPOS=0,0; LSTPOS=max,max
; SUBTTL  MAIN loop of editor
;WHILE EOL.NE.TRUE BEGIN
;** GET A KEY
INLLOP:
extern STCTYP
	CLC ; Signal for insert or overwrite cursor
	CALL	STCTYP ; Set new cursor type
	CALL	KEYIN ; AX=key value
;At this point we can have three classes of characters:
;   CF=1 indicates 2 byte char with 2 sub classes:
;       AH=FF indicates editor control function
;       AH<>FF indicates 2 byte character to echo
;   CF=0 indicates 1 or 3 byte key
;       AL=FF indicates a 3 byte key with scan code in DX - these are ignored
;       AL<>FF indicates a 1 byte key to echo, except if char is CR.
	JB	INL2BY ; BRIF 2-byte character, check for editor controls
	CMP	AL,CHRRET
	JZ	INLRET ; BRIF CR, terminate line input
;** IF CURRENT_CHAR IS SPECIAL THREE BYTE CHAR
	CMP	AL,254 ; Test for 3-byte character
;** *** IGNORE THIS CHAR
	JZ	INLLOP ; BRIF to ignore 3-byte character
	JMP	INLOP0 ; Not 3-bytes, just echo single byte
INL2BY:
;** IF CURRENT_CHAR IS CONTROL_CHAR
	CMP	AH,255
	JNZ	INLOP0 ; BRIF not editor control character, echo char
	CMP	AL,0o177
	JZ	INLP0 ; BRIF is a control character
	CMP	AL," "
	JNB	INLOP0 ; BRIF is not a control character
INLP0:
;** IF CURRENT_CHAR IS <CR> RETURN CURRENT LOGICAL LINE
	CMP	AL,CHRRET
	JZ	INLRET ; BRIF is carriage return(EOL)
;** IF (CURRENT_CHAR=<HELP> AND INPUT_MODE=PROGRAM) DO EDIT ON KBUF
	CMP	AL,CHREDT
	JNZ	INLOP0
	JMP	INLHLP ; BRIF help char, do edit on KBUF
;Echo character in AX
INLOP0:
	OR	AH,AH
	JZ	INLOP3 ; Single byte character
	XCHG	AL,AH ; Output AH first
	CALL	OUTDO ; Output a char
	XCHG	AL,AH ; Restore AL
INLOP3:	CALL	OUTDO ; Output a char
	JMP	INLLOP
;** END
;SCAN FOR SEMICOLON
;
SCNSEM:	CMP	AL,";"
	JNZ	SCNSMR ; BRIF not semicolon, return
	MOV byte [SEMFLG], AL
	JMP	CHRGTR ; Skip semicolon and return
SCNSMR:	RET
; SUBTTL  Exit, return current logical line
;READ LOGICAL LINE INTO BUF
INLRET:	MOV	BX,BUF ; Put data into BUF
	MOV	CX,255 ; CX=Max number of bytes to move
	TEST byte [F_EDPG], 0o377 ; Set zero flag if program statement input
	PUSHF
	MOV DL, byte [CSRY] ; (DH,DL) = (CSRX,CSRY)
	MOV DH, byte [CSRX]
	CALL	SCNRDL ; Read the logical line into BUF
; BX=address of last char in BUF plus one
;IF PROGRAM_STATEMENT_INPUT BEGIN
	POPF
	JZ	INCRTX ; BRIF not statement input
;** WHILE POSN.NE.BEGIN_OF_LINE AND [POSN].NE.BLANK AND [POSN].NE.LF BEGIN
	MOV	CX,BX
	SUB	CX,BUF ; CX=count of chars in BUF
	JZ	INCRTX ; BUF is empty
	PUSH	DI
	MOV	DI,BX
	DEC	DI ; Start scan at last valid data
INLOT0:	MOV	AL," "
;** *** POSN=POSN-1
INLOT1:	STD ; Scan backwards
 REPE	SCASB ; This works for blank line("," at BUF-1)
	INC	DI ; [DI] = last valid data
	MOV	AL," "
	CMP	byte [DI+0o0],AL
	JZ	INLOT2 ; BRIF more trailing blanks
	MOV	AL,CHRLNF
	CMP	AL,byte [DI+0o0]
	JNZ	INLOT3 ; BRIF not more trailing linefeeds
INLOT2:	OR	CL,CL
	JNZ	INLOT1 ; BRIF not at beginning of buffer
;** *** END
;** END
INLOT3:	MOV	BX,DI
	POP	DI
	INC	BX
INCRTX:	MOV	byte [BX+0o0],0o0 ; Terminate BUF
;** UPDATE CURSOR POSN, RETURN
	TEST byte [SEMFLG], 0o377
	JNZ	INCRTF ; BRIF if INPUT<semicolon> statement
	MOV	AX,CHRAPP
	CALL	OUTDO ; Move to end of logical
	MOV byte [F_EDIT], 0o0
	CALL	CRDO ; Move to first posn beyond this logical
INCRTF:	MOV	BX,BUF-0o1 ; Return BUF - 1
	PUSHF
	CALL	CLRFLG ; Clear miscellaneous status flags
	POPF
	RET
;SUBROUTINE EDTBRK              ; Routine which initializes when break detected
;**                             ; This is called by the STOP code
;**
EDTBRK:
extern SETCSR
extern CSRTYP
	MOV byte [CSRTYP], 0 ; Indicate cursor off
	CALL	SETCSR
	CALL	CLRFLG ; Clear editor flags
	PUSH	AX
	MOV	AL,CHRAPP
	MOV byte [F_EDIT], AL
	CALL	OUTDO ; Move cursor to end of logical line
	MOV byte [F_EDIT], 0o0 ; Reset edit mode
	CALL	CRDO ; Move cursor to next physical line
	POP	AX
	MOV byte [AUTFLG], 0o0 ; Reset AUTO mode
	RET
;** END SUBROUTINE EDTBRK
;SUBROUTINE CLRFLG              ; Routine which clears flags
;**
CLRFLG:	MOV byte [F_EDIT], 0o0 ; No longer in INLIN
	MOV byte [F_EDPG], 0o0 ; Not program edit
	MOV byte [F_INST], 0o0 ; Not insert mode
	MOV byte [SEMFLG], 0o0 ; Not INPUT; statement
	RET
;** END SUBROUTINE CLRFLG
; SUBTTL  EDIT code
extern MAIN
extern LINSPC
extern FNDLIN
extern DEPTR
extern LISPRT
extern LINPRT
extern FCERR
extern USERR
extern BUFLIN
extern DOT
extern ERRFLG
extern ERRLIN
;EDIT COMMAND
;
global EDIT
EDIT:	CALL	LINSPC ; LINE NUMBER IN DE
	JNZ	EFCERR ; STATEMENT MUST HAVE ENDED
EREDIT:	POP	BX ; REMOVE NEWSTT(OR CALL FROM MAIN)RETURN
	MOV word [DOT], DX
	CALL	FNDLIN ; FIND LINE
	JNB	EUSERR ; LINE DOES NOT EXIST
	MOV	BX,CX ; CX=LINE PTR
ERED2:	INC	BX
	INC	BX
	MOV	DX,word [BX+0o0] ; DE=LINE NUMBER
	INC	BX
	INC	BX
ERED3:	PUSH	BX
	MOV byte [F_EDIT], 0o1 ; SET FLAG INDICATING IN EDIT MODE
; (FORCES OPEN LINES DURING LIST)
; (AND TELLS INLIN TO START AT BEGIN OF LOGICAL)
	XCHG	BX,DX
ERED4:	CALL	LINPRT ; PRINT THE LINE NUMBER
	POP	BX
	CMP	byte [BX+0o0],9 ; LINE START WITH TAB?
	JZ	ERED5
	MOV	AL," "
	CALL	OUTDO ; NO, PUT SPACE OUT
;ENTRY FOR EDIT ON KBUF IS HERE
ERED5:
	MOV byte [F_EDIT], 0o1 ; SET FLAG INDICATING IN EDIT MODE
; (FORCES OPEN LINES DURING LIST)
; (AND TELLS INLIN TO START AT BEGIN OF LOGICAL)
	CALL	BUFLIN ; PUT LINE IN BUF AND SET UP HLPBFA
	MOV	BX,BUF
	CALL	LISPRT ; PRINT THE LINE AND SET UP HLPCSR
	MOV BL, byte [CSRY]
	MOV BH, byte [CSRX]
	JMP	MAIN
EFCERR:	JMP	FCERR ; Indirect jump to FCERR
EUSERR:	JMP	USERR ; Indirect jump to USERR
;Help key edit
;
INLHLP:	TEST byte [F_EDPG], 0o377
	JNZ	INLHL0 ; BRIF do help edit on program statement
;Help during input statement
	JMP	INLOP3 ; Just output char
;DO EDIT ON DOT
INLHL0:	POP	AX ; Remove call to this routine
;See if edit on error line number
	MOV DX, word [ERRLIN]
	CALL	ERRED2 ; If exists,do edit on error line number
;See if edit on current line number
	MOV DX, word [CURLIN]
	CALL	ERRED2 ; If exists,do edit on current line number
;ERRLIN AND CURLIN ARE DIRECT, DO EDIT ON KBUF
extern KBUF
extern CURLIN
extern SCNEXT
extern DEPTR
	CALL	DEPTR ; Remove line pointers from program
	MOV	BX,KBUF
	PUSH	BX
	DEC	BX
	CALL	SCNEXT ; Remove any line pointers from KBUF
	POP	BX
	JMP	ERED5
;AUTOMATIC EDIT FOR ERRORS
;
global ERREDT
ERREDT:	MOV byte [ERRFLG], AL ; Reset the flag to call edit
	MOV DX, word [ERRLIN] ; Get the line number
ERRED2:	CMP	DX,0o177777 ; See if it was direct
	JZ	ERRED3 ; Go back if direct
	OR	DX,DX
	JZ	ERRED3 ; Go back if zero
	JMP	EREDIT
ERRED3:	RET
; SUBTTL  ASCII LOAD and SAVE line handler
;LOAD ASCII:
;  PROGRAM LINE INPUT FROM DISK
;
extern ISFLIO
extern OUTDO
extern INCHR
extern LBOERR
DSKCHI:
	CALL	ISFLIO ; Set FLAGS.NZ if PTRFIL points to active file
	JNZ	ISLOAD ; BRIF LOAD statement
	RET ; If so use special screen io
ISLOAD:	POP	AX ; Discard Return Address
	MOV	CL,BUFLEN ; Setup the maximum character count
	MOV	BX,BUF ; Place we are going to stoer the line
LOPBUF:	CALL	INCHR ; Get a character from the file
; (will call indskc and handle eof)
	MOV	byte [BX+0o0],AL ; Store the character
	CMP	AL,13 ; Is it the end (a CR)
	JNZ	INOTCR ; Not a [CR]
	CMP	byte [BX-0o1],10 ; Preceeded by a line feed?
	JZ	LOPBUF ; Yes, ignore the [CR]
	JMP	FINLIN ; No, this is the end of a line
INOTCR:
	OR	CL,CL
	JE	LTLONG ; Branch if line is too long to fit in BUF
	CMP	AL,10 ; LEADING LINE FEEDS MUST BE IGNORED
	JNZ	INOTLF
	CMP	CL,BUFLEN ; CL=BUFLEN if this is the 1st char on the line
	JZ	LOPBUF ; Branch if this was a leading line-feed
INOTLF:	INC	BX ; ADVANCE THE POINTER
	DEC	CL
	JMP	LOPBUF ; DO NEXT CHAR
	DEC	CL
FINLIN:
	MOV	byte [BX+0o0],0o0
	MOV	BX,BUF-0o1 ; POINT AT BUFMIN
	RET
LTLONG:	JMP	LBOERR ; Report LINE BUFFER OVERFLOW error
; (This program wasn't created by BASIC)
;SAVE ASCII:
;   PROGRAM LISTING CHAR OUTPUT TO DISK(CONVERT <LF> TO <LF><CR>)
;
global OUTCH1
OUTCH1:	CMP	AL,CHRLNF
	JZ	OUTCH0 ; IS LF
	JMP	OUTDO
OUTCH0:
extern ISFLIO
	CALL	ISFLIO
	JNZ	OUTCH2 ; branch if outputting to file
	CALL	OUTDO
	RET
OUTCH2:	CALL	OUTDO
	MOV	AL,CHRRET
	CALL	OUTDO
	MOV	AL,CHRLNF
	RET
