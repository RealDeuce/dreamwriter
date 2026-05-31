; Auto-converted mechanically from ../gw-basic/scndrv.asm
; Edit the converter or the generated source deliberately; do not hand-wave syntax changes.

; [ This translation created 10-Feb-83 by Version 4.3 ]
; .RADIX  8
%include "dwoem.inc"
; TITLE   SCNDRV  This is the OS independent Screen Driver for GW BASIC
; SUBTTL  DATA DEFINITIONS - Miscellaneous
; COMMENT *
; 	--------- --- ---- -- ---------
; 	COPYRIGHT (C) 1982 BY MICROSOFT
; 	--------- --- ---- -- ---------
;
; 	PROGRAMMER: MARC WILSON
;
%include "gio86u.inc"
; .RADIX	8
;OEM IFNDEFs
%define MELCO 0o0
%define CANON 0o0
;GENERIC IFNDEF'S:
%define TERMSW 0o0
%define HLPEDT 0o0
%define NMPAGE 0o1 ;Number of pages
%define NEWCHP 0o1 ;New change page routine
%define IBMEOL IBMLIK ;Clear to EOL for COMPATIBILITY
%define IBMCSR IBMLIK ;IBM COMPATIBILITY for cursor
;Definition of scroll types
; Choice of scroll type is by switch SCROLT.
; Switches defined here are used to implement a specific SCROLT type.
; If other scroll types are needed then additional SCROLT types should be
;   defined here.
%define INVLIN SCROLT ;Invisible (function key) Line
%define FKFSRL (SCROLT-0o1) & 0o1 ;Clear fkeys/full scroll/rewrite fkeys
;OTHER GENERIC SWITCHES(OEM SPECIFIC)
%define TXTWDO 0o0 ;list of OEM's which have window setting capability
; SUBTTL  DATA DEFINITIONS - Internal routines(with usage description)
;Entry points
global SCNSWI ; Set CRT physical line width
;on entry:  AL=width, CL=height
global SCNCLR ; Clear CRT, Refresh Function Key Display,
; Home Graphics and Text Cursors
;on entry:  none
global SCNLOC ; Locate cursor on physical screen(1,1 = HOME)
;on entry:  AH=column(x), AL=line(y)
global SCNOUT ; Character output at current position
;on entry:  AX=character
global SCNRDL ; Read a physical line at current position
;on entry:  DI=address of where to put string, CX=max count
;on exit:   CX=CX-number of characters read
;           DI=DI+number of characters read
global SCNPOS ; Return current cursor location
;on exit:   DL=cursor line, DH=cursor column
global SCNRDT ; Read terminator for physical line
;on entry:  DL=line number
;on exit:   AH= terminator column, AL=terminator value
;           Flags indicate terminator value:
;           CF=EOL, ZF=Linefeed
global SCNGWI ; Read logical width of lines
;on exit:   AH=logical width of lines
global SCNMRK ; Mark position as current FSTPOS, LSTPOS
;on entry:  ZF set indicates use WDOLFT as column
;           ZF clear indicates use CSRX as column
global SCNIPL ; Initialize - called during IPL
global SCNBRK ; Initialize - called when BREAK received by POLKEY
; SUBTTL  DATA DEFINITIONS - External routines and data
;EXTERNAL ROUTINES
extern SCROLL ; OEM supplied SCROLL routine
extern SCROUT ; OEM supplied character output
extern SCRINP ; OEM supplied screen input(read character)
extern CLREOL ; OEM supplied screen clear to end of line
;THE FOLLOWING IS DATA UNIQUE TO THE SCNDRV MODULE
;       ALL DATA IS ONE BYTE LONG UNLESS STATED OTHERWISE
extern LINCNT ; Number of lines
extern CRTWID ; Characters per line
extern WDOTOP ; Top line in window(1-[LINCNT])
extern WDOBOT ; Bottom line in window([WDOTOP]-[LINCNT])
extern WDOLFT ; Leftmost column in window(1-[CRTWID])
extern WDORGT ; Rightmost column plus one([WDOLFT]-[LINCNT])
extern LINLEN ; Line max width(1 to CRTWID)
extern LINTTB ; Line terminator table((# lines * 2) bytes long)
; Two items per entry:
;   Terminator, last column
extern TRMCUR ; Address of current terminator entry(2 bytes)
extern FSTLIN ; Line number saved by SCNSTM call
extern FSTCOL ; Column saved as above and decreases to WDOLFT
extern LSTLIN ; Line number saved by SCNSTM and grows as the
;   logical line grows.
extern LSTCOL ; Column saved as above which grows as the logical
;   line grows(always reflects last col on LSTLIN).
extern F_CRET ; Zero indicates last character output was CR
extern CSRY ; Current line(1-[LINCNT])
extern CSRX ; Current column(1-[CRTWID])
extern KEYSW ; ^O377=Function Keys displayed on bottom line
;THE FOLLOWING DATA IS ACCESSED BY SCNDRV BUT SET ELSEWHERE
extern F_EDIT ; Set to non-zero by INLIN when editing
extern F_INST ; Set to non-zero by INLIN for insert mode
; SUBTTL  DATA DEFINITIONS - Literals
;CHARACTER DEFINITIONS
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
%assign CHRFKD 20 ; Function Key Display key
%assign CHRLDL 21 ; Line DeLete
%assign CHRADV 28 ; cursor RiGhT
%assign CHRREG 29 ; cursor LeFT
%assign CHRUP 30 ; cursor UP
%assign CHRDWN 31 ; cursor DoWN
%assign CHRDEL 127 ; DELete
;TERMINATOR TABLE LITERALS
global TRMLNF
%assign TRMLNF 10 ; LINEFEED terminator
global TRMEOL
%define TRMEOL 0o177 ; EOL terminator
global TRMWRP
%define TRMWRP 0o0 ; WRAP terminator
global TRMNWP
%define TRMNWP 0o1 ; NULL WRAP terminator
global TRMNUL
%define TRMNUL 0o200 ; Sign bit indicates initialize line
;DEFAULT SCREEN SIZE
global SCNSIZ
%define SCNSIZ 20+(40*0o400) ; Height = 20, Width = 40
; SUBTTL  SCNIPL, SCNSWI AND SCNWDO   The parameter setting routines
;SUBROUTINE SCNIPL():           ; Initialize
;**
SCNIPL:
extern ESCFLG
	MOV byte [ESCFLG], 0o0
	RET
;** END SUBROUTINE SCNIPL
;BREAK - reset flags etc. when ^C typed.
;
SCNBRK:	MOV byte [FSTLIN], 0o0
	MOV byte [LSTLIN], 0o377 ; Set FSTPOS, LSTPOS to impossible values
	MOV byte [F_CRET], 0o377 ; Clear "last char was CR" flag
	RET
;SUBROUTINE SCNSWI(WIDTH,HEIGHT):       ; Set screen width(logical/physical) and height
;**                     on entry:   AL=width, CL=height
;**
SCNSWI:	MOV byte [CRTWID], AL ; Save physical width
	MOV byte [LINLEN], AL ; Set logical line length
	MOV byte [LINCNT], CL ; Save physical height
	MOV byte [WDOTOP], 0o1 ; Init window top
	PUSH	CX
	DEC	CL ; Reserve status line
	MOV byte [WDOBOT], CL ; Set window bottom
	POP	CX
	MOV byte [WDOLFT], 0o1 ; Set window left
	MOV byte [WDORGT], AL ; Set window right
	RET
;** *** END
;** END SUBROUTINE SCNSWI
;SUBROUTINE SCNWDO(POSN,COUNT): ; Set text window
;**
;**                             on entry:   AH=column posn, AL=line posn
;**                                         CH=width, CL=height
;**                             on exit:    AX,CX=values actually set
;**                                         CF indicates posn outside screen
;**
;**                             NOTE: This routine truncates width and height.
;**
;** IF POSN IS CONTAINED WITHIN PHYSICAL SCREEN BEGIN
; SUBTTL CURSOR READ/WRITE
;SUBROUTINE SCNLOC(X,Y):        ; Locate cursor on physical screen
;**                         on entry:   AH=column, AL=line(1,1 is home)
;**
SCNLOC:	MOV byte [CSRX], AH
	MOV byte [CSRY], AL
	RET
;** END SUBROUTINE SCNLOC
;SUBROUTINE SCNCLR(X,Y):        ; Clear Screen, Home Text & Graphics Cursor,
;                               ; Refresh Function Key Display
;**                         on entry:
;
extern KEYDSP
extern GRPINI
SCNCLR:
	CALL	TTBINI ;Clear the terminator table
	CALL	GRPINI ;Home the graphics cursor
	CALL	WHOME ;DX=cursor home
	MOV	AX,DX
	CALL	SCNLOC ;set cursor position
	JMP	KEYDSP ;Conditionally display softkeys and return
;** END SUBROUTINE SCNCLR
;SUBROUTINE SCNPOS              ; Read current cursor location
SCNPOS:	MOV DH, byte [CSRX]
	MOV DL, byte [CSRY]
	PUSHF
	CMP DH, byte [LINLEN]
	JBE	SCNPS1 ;BRIF not beyond edge of screen
	MOV DH, byte [LINLEN] ;Force posn within screen
SCNPS1:	POPF
	RET
;** END SUBROUTINE SCNPOS
;SUBROUTINE SCNGWI              ; Read current logical width
;**                         on exit:    AH=width
;**
SCNGWI:	MOV AH, byte [LINLEN]
	RET
;** END SUBROUTINE SCNGWI
; SUBTTL  TERMINATOR TABLE READ/WRITE/INITIALIZE
;SUBROUTINE SCNRDT(Y):          ; Read terminator value and column
;**                         on entry:   DL=line number
;**                         on exit:    AH=terminator posn, AL=terminator value
;**                                     If CF=1; EOL
;**                                     If CF=0 and ZF=1; LF terminated
;**
SCNRDT:	PUSH	BX
	MOV	BL,DL ; BX = Displacement into table
	ADD	BL,BL
	MOV	BH,0o0
	MOV word [TRMCUR], BX ; Save address of terminator reading(for set term)
	MOV	AH,byte [LINTTB+BX-0o2] ; Get terminator posn
	MOV	AL,byte [LINTTB+BX-0o1] ; Get terminator value
	AND	AL,0o377-TRMNUL ; Get rid of initialize line status bit
	CMP	AL,TRMEOL
	STC
	JZ	SCNRTX ; BRIF EOL terminator(CF=1)
	CMP	AL,TRMLNF ; CF=0, set ZF if linefeed terminated
	JNB	SCNRTX ; BRIF carry not set
	CMC ; clear carry
SCNRTX:	POP	BX
	RET
;** END SUBROUTINE SCNRDT
;SUBROUTINE SCNWTT(TERM)        ; Set new value for terminator last read
;**                     on entry:   AH=column where physical line ends
;**                                 AL=terminator type(one of: TRMEOL, TRMLNF
;**                                     TRMWRP, TRMNWP)
;**
SCNWTT:	PUSH	BX
	MOV BX, word [TRMCUR] ; Get address of terminator last read
	MOV	byte [LINTTB+BX-0o2],AH
	AND	byte [LINTTB+BX-0o1],TRMNUL
	OR	byte [LINTTB+BX-0o1],AL ; Write new terminator, leaving NULL bit
	POP	BX
	RET
;** END SUBROUTINE SCNWTT
;TERMINATOR TABLE INIT
;
TTBINI:	MOV	CX,NMLINE+0o1 ; CX=count of line term table entries
	MOV	BX,LINTTB ; BX=addr of line term table
TTBIN0:	MOV	byte [BX+0o0],0o0 ; Clear column number
	MOV	byte [BX+0o1],TRMEOL ; Set terminator to <CR>
	INC	BX
	INC	BX
	LOOP	TTBIN0 ; Init entire line terminator table
	RET
; SUBTTL  CHARACTER OUTPUT
;SUBROUTINE SCNOUT(CHAR):       ; Output character
;**                         on entry:   AX= character
;**
SCNOUT:	PUSH	DX
	PUSH	CX
	PUSH	BX
	CALL	CTLDSP ; If control char or ESC sequence, do operation
	JB	SCNOTX ; No char to output
	CALL	CHWRAP ; Do wrap for char in AX, return DX=posn for output
extern SETCSR
extern CSRTYP
	MOV byte [CSRTYP], 0 ; Set next cursor type to off
	CALL	SETCSR ; Insure that the cursor is off
	CALL	SCROUT ; Send char in AX to BIOS at DX posn
	MOV byte [F_CRET], 0o377 ; Clear last char was Carriage return flag
SCNOTX:	POP	BX
	POP	CX
	POP	DX
	RET
;** END SUBROUTINE SCNOUT
;SUBROUTINE MKRMCI              ; Open up sapce for char if insert mode
;
MKRMCI:	PUSHF
	TEST byte [F_INST], 0o377
	JZ	MKRCIX ; BRIF not insert mode(do nothing)
	POPF
	MOV	CH,AL
	INC	CH ; CH=space needed
	CALL	MKRMCH ; Open up space at (DH,DL) for count of CH
	CALL	SCNRDX ; Put terminator table values in CX
	RET
MKRCIX:	POPF
	RET
SCNRDX:	XCHG	AX,CX
	CALL	SCNRDT
	XCHG	AX,CX
	RET
; SUBTTL  LINE WRAP LOGIC - Character wrap
;THE LINE WRAP LOGIC IS USED PRIOR TO OUTPUTTING CHARACTERS OR STRINGS
;   IT WILL RESERVE THE NECESSARY NUMBER OF CHARACTERS ON THE CURRENT
;   LOGICAL LINE OR WILL RETURN CARRY SET AND DX=POSN WHERE CHARACTER
;   CAN BE OUTPUT(I.E. IT RETURNS A POSN LESS THAN CURRENT POSN)
;SUBROUTINE CHWRAP(CHAR):       ; Do single character wrap
;**                     on entry:   AX=character
;**                                 DH=CSRX, DL=CSRY
;**                     on exit:    if cannot wrap, CF=1
;**                                 DX=posn where character can be output
;**                                 cursor posn and terminator table are updated
;**                     NOTE: if CF=1 then DX may be set to a previous posn
;**                         where there is enough room to EOL.
;**
CHWRAP:	PUSH	AX
	XOR	CH,CH
	OR	AH,AH
	JZ	CHWRP0 ; BRIF Single byte character
	MOV	CH,0o1 ; It's two byte character
CHWRP0:	MOV	CL,CH
	ADD	CH,DH ; CH=column after char is output
	CALL	SCNRDT ; Read terminator
	XCHG	CX,AX
;** IF POSN .LT. EOL BEGIN
;** AT THIS POINT AH=POSN(WHERE GOING TO), DX=CURRENT POSN,
;** AL=LENGTH OF CHARACTER, CX=CURRENT TERMINATORS
	PUSHF
	CMP AH, byte [LINLEN]
	JA	CHWRP1 ; BRIF not space before end of physical line
	POPF
	CALL	MKRMCI ; If insert mode, open up space for character
;** *** IF NOT(LINEFEED .EQ. TERMINATOR(CURRENT_LINE) AND POSN .EQ. LINLEN)
;** *** *** RETURN, OUTPUT IS AT CURRENT POSN
	JB	CHWPXI ; EOL terminated, output at current posn
	JZ	CHWPLF ; BRIF LF terminated
	CMP	CL,TRMWRP
	JZ	CHWPXI ; BRIF WRAP(always room)
	CMP AH, byte [LINLEN]
	JB	CHWPXI ; BRIF NUL_WRAP and not overwriting NULL
	MOV	CL,TRMWRP
CHWPXI:	JMP	CHWRPX ; Overwriting NULL_WRAP, set to WRAP
CHWPLF:	CMP AH, byte [LINLEN]
	JAE	CHWPL1 ; LF terminated and no room for LF
	INC	AH ; Need to terminate at one past posn printing at
	XCHG	AX,CX
	CMP	AH,CH
	MOV	AH,CH
	JA	CHWPL0 ; BRIF current posn below terinator posn
	CALL	SCNWTT ; Terminate line at one more than print posn
CHWPL0:	CLC
	XCHG	AX,CX
	PUSHF
	DEC	AH ; Restore column actually printing at
	JMP	CHWRP9 ; Update LSTPOS, FSTPOS, cursor posn, exit
;** *** *** ELSE MOVE LINEFEED TO NEXT LINE
CHWPL1:	CALL	WRAPLF ; Move linefeed to next line
	JB	CHWRNI ; Error, output at posn-(char length)
	CLC
	PUSHF
	MOV	AH,CH
	JMP	CHWRP9 ; Exit without updating terminator
CHWRNI:	JMP	CHWRNO
;** *** END
;** *** DO CASE TERMINATOR(CURRENT_LINE) OF
;** *** There is not enough room on current line for character
CHWRP1:	POPF
	JB	CHWREL ; BRIF EOL terminated
	JZ	CHWRLF ; BRIF LF terminated
;** *** CASE: WRAP; NULL_WRAP; BEGIN
;** *** *** *** SET WRAP TERMINATOR
CHWRWP:	MOV	CL,TRMWRP
	MOV CH, byte [LINLEN]
	XCHG	AX,CX
	CALL	SCNWTT ; Set wrap terminator at last column
	CMP DL, byte [LSTLIN]
	JNZ	CHWRN0 ; BRIF not on last line
	INC	byte [LSTLIN] ; Wrap LSTLIN
	MOV byte [LSTCOL], 0o0 ; Force update of LSTCOL at CHWRPZ
CHWRN0:	INC	DL ; Next line
	CALL	SCNRDT ; Set up for write at new line
	MOV DH, byte [WDOLFT] ; First column is output posn
	MOV	CH,DH
	ADD	CH,CL ; CH=POSN going to
	XCHG	AX,CX
	CALL	MKRMCI ; If insert mode, open up space for character
	CMP	CL,TRMLNF
	JNZ	CHWRPX ; BRIF not linefeed terminated
	XCHG	AX,CX ; CH=POSN, AX=current terminators
	INC	CH ; Need terminator one beyond actual output
	CMP	AH,CH
	MOV	AH,CH
	JA	CHWRN2 ; BRIF Current terminator beyond posn for output
	CALL	SCNWTT ; Set current terminator to new max posn
CHWRN2:	DEC	CH ; Restore POSN going to
	XCHG	AX,CX
CHWRPX:	CLC
	JMP	CHWRPZ ; All done
;** *** *** *** END
;** *** *** END
;** *** CASE: EOL
CHWREL:	CALL	MKRMNL ; Make room on next line(make it EOL term'd)
	JB	CHWRP3 ; If error, make room for char on this line
	CALL	SCNRDX ; Reread terminator for this line
	JMP	CHWRWP ; Wrap to next line
;** *** CASE: LF
CHWRLF:	XCHG	AX,CX
	CALL	WRAPLF ; First wrap LF to next line
	MOV	AL,TRMNWP ; Set to temporary NULL_WRAP at last column
	MOV AH, byte [LINLEN]
	CALL	SCNWTT
	XCHG	AX,CX
	JNB	CHWRWP ; Go do wrap for char
;No room, abort
CHWRP3:	MOV AH, byte [LINLEN] ; AH=POSN going to
CHWRNO:	MOV	DH,AH
	SUB	DH,AL ; DH=POSN-(char len)
	STC ; Error return
;** *** END CASE TERMINATOR(CURRENT_LINE)
;** EXIT
CHWRPZ:	PUSHF
	XCHG	AX,CX ; CH=POSN, AX=current terminators
	CMP	AH,CH
	MOV	AH,CH
	JA	CHWRP9 ; BRIF Current terminator beyond posn for output
	PUSH	AX
	CALL	SCNRDT
	POP	AX
	CALL	SCNWTT ; Set current terminator to new max posn
CHWRP9:	MOV byte [CSRY], DL
	CMP DL, byte [LSTLIN]
	JNZ	CHWNTL ; BRIF not on last logical line
	CMP AH, byte [LSTCOL]
	JB	CHWNTL ; BRIF not new last position
	MOV byte [LSTCOL], AH ; Set new last posn
CHWNTL:	CMP DL, byte [FSTLIN]
	JNZ	CHWNTF ; BRIF not on first logical line
	CMP DH, byte [FSTCOL]
	JAE	CHWNTF ; BRIF not new first position
	MOV byte [FSTCOL], DH
CHWNTF:	INC	AH
	MOV byte [CSRX], AH ; Set new posn(one past last posn printed at)
	CMP byte [LINLEN], AH
	JAE	CHWNTG ; BRIF does not go beyond end of physical line
	CALL	SCNRDT
	JB	CHWNTG ; BRIF line does not continue
	INC	byte [CSRY] ;   Logical line continues, put cursor at
	MOV AH, byte [WDOLFT] ;       start of next physical line
	MOV byte [CSRX], AH
CHWNTG:	POPF
	POP	AX
	RET
;Wrap linefeed on end of line to next line
WRAPLF:	PUSH	word [TRMCUR]
	PUSH	CX
	PUSH	DX
	MOV DH, byte [LINLEN]
	MOV	CH,0o1
	CALL	MKRMCH ; Insert one space before LF
	POP	CX
	MOV	CL,DL
	POP	DX
	XCHG	CX,DX
	POP	word [TRMCUR]
	RET
; SUBTTL  LINE WRAP LOGIC - Open next line for wrap
;SUBROUTINE MKRMNL(line)        ; Make the next line a blank, empty line
;**                     on entry:   DL=current line number
;**                     on exit:    DL=current line number(may change from entry)
;**                                 if CF=1 no room available
;**
MKRMNL:	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
MKRMN0:	CALL	SCNRDT
	JB	MKRMN5
	CMP DL, byte [WDOBOT]
	JZ	MKRMN6
	JB	MKRMN4
	MOV DL, byte [WDOBOT]
	JMP	MKRMN0
MKRMN4:	INC	DL
	JMP	MKRMN0
;** IF CURRENT_PHYSICAL .LT. WINDOW_BOTTOM
MKRMN5:	CMP DL, byte [WDOBOT]
MKRMN6:	POP	DX
	PUSH	DX ; Get back posn to scroll from
	JZ	MKRMN7 ; BRIF at bottom of window(scroll up)
	CMC
	JB	MKRMNZ ; BRIF outside of window
	CMP DL, byte [WDOTOP]
	JB	MKRMNZ ; BRIF outside of window
	TEST byte [F_EDIT], 0o377
	JZ	MKRMNZ ; BRIF not editing, no need to scroll
	INC	DL ; Scroll down starting at next line
;** *** SCROLL DOWN
	CALL	SCRLD0 ; Scroll down to end of window
MKRMNY:	CLC ; Indicate successful
MKRMNZ:	POP	DX ; Restore current line number
	JMP	MKRMNX
;** *** ELSE IF (FIRST_PHYSICAL(LOGICAL) .NE. WINDOW_TOP) OR NOT(INPUT_EDIT)
MKRMN7:	TEST byte [F_EDIT], 0o377
	JZ	MKRMN9 ; BRIF not input edit, always allow scroll
MKRMN8:	CALL	CSRUP
	JB	MKRMNZ ; BRIF logical line starts at top of window(abort)
	PUSH	AX
	CALL	SCNRDT
	POP	AX
	JNB	MKRMN8 ; BRIF previous physical part of this logical
;** *** SCROLL UP
MKRMN9:	POP	DX
	PUSH	DX
	CMP DL, byte [WDOBOT] ; Full screen scroll?
	JAE	MKRMNF ; BRIF scroll up entire screen
	CALL	SCRLUD ; Scroll up from DL to WDOTOP
	JMP	MKRMNU
MKRMNF:	CALL	SCRLUP ; Scroll up entire window
MKRMNU:	POP	DX
	CALL	CSRUP ; Return line number of original line
	CLC
MKRMNX:	POP	CX
	POP	BX
	POP	AX
	RET
; SUBTTL  SCROLL ROUTINES - Scroll up and down
;Scroll up from DL to WDOTOP
SCRLUD:	PUSH	CX
	MOV	CL,DL
	MOV DL, byte [WDOTOP]
	JMP	SCRLU1
;SCROLL UP
SCRLUP:	MOV DL, byte [WDOTOP] ; Top line number
;Scroll up from DL to bottom
SCRLU0:	PUSH	CX
	MOV CL, byte [WDOBOT]
SCRLU1:	PUSH	AX
	PUSH	BX
	PUSH	DX
	MOV	AL,DL
	MOV	BL,DL ; From = To = Top line number
	INC	AL ; From = To + 1
	MOV BH, byte [WDOLFT]
	MOV	AH,BH ; From column = To column = left margin
	SUB	CL,BL ; CL = line count
	JA	SCRUL1 ; BRIF two or more line scroll
	JB	SCRUL4 ; BRIF TOP > BOTTOM(should never happen)
	PUSH	AX
	MOV	DL,BL
	JMP	SCRUL3 ; TOP=BOTTOM, just init line
SCRUL1:	PUSH	AX
	MOV CH, byte [CRTWID] ; Scroll entire lines
	CALL	SCROLL ; Scroll screen
;If CSRY, FSTLIN, LSTLIN are within scroll, decrement their values
	ADD	AL,CL ; AL=Last line scrolled + 1
	DEC	AL ; AL=Bottom line scrolled
; BL=Top line scrolled
	MOV	AH,255 ; decrement line# variables in scroll window
	CALL	TSTSCR
	MOV	DL,AL ; DL=bottom line of scroll (initialize it)
;Clear the last line of the scroll
SCRUL3:	MOV DH, byte [WDOLFT]
	POP	AX
	OR	CL,CL
	JE	SCRUL4 ; No scroll(one line init)
	CALL	SCRUTT ; Scroll up terminator table
SCRUL4:	CALL	PLINIT ; Init physical line from (DL,DH) to (DL,WDORGT)
	POP	DX
	POP	BX
	POP	AX
	POP	CX
	RET
;TSTSCR is called after Scrolling Up or Down to update Line Number variables
; which may be in the scroll window
; Entry - BL=top line number of scroll window
;         AL=bottom line number of scroll window
;         AH=1 if line# variables are to be incremented, -1 if decremented
;
TSTSCR:	PUSH	SI
	PUSH	AX
	MOV	SI,CSRY
	CALL	TSTWDO ; Adjust CSRY if its within scroll window
	MOV AH, byte [WDOTOP]
	CMP	byte [SI+0o0],AH
	JB	TCSRY1 ; BRIF CSRY above top of window
	MOV AH, byte [WDOBOT]
	CMP	byte [SI+0o0],AH
	JNA	CSRYOK ; BRIF CSRY didn't increment beyond bottom
TCSRY1:	MOV	byte [SI+0o0],AH ; Bring it back to within scroll window
CSRYOK:	MOV	SI,FSTLIN
	POP	AX
	CALL	TSTWDO ; Adjust FSTLIN if its within scroll window
	MOV	SI,LSTLIN
	CALL	TSTWDO ; Adjust LSTLIN if its within scroll window
	POP	SI
	RET
; If BL .LEQ. [SI] .LEQ. AL then [SI]=[SI]+AH
;
TSTWDO:
	CMP	AL,byte [SI+0o0]
	JB	NINWDO ; BRIF [SI] not within scroll
	CMP	BL,byte [SI+0o0]
	JA	NINWDO ; BRIF [SI] not within scroll
	ADD	byte [SI+0o0],AH ; Adjust [SI] for scroll
NINWDO:	RET
;SCROLL DOWN
SCRLDN:	MOV DL, byte [WDOTOP]
;Scroll down from DL to WDOBOT
SCRLD0:	PUSH	AX
	PUSH	BX
	PUSH	CX
	MOV	AL,DL
	MOV	BL,DL ; From = To = top of scroll
	INC	BL ; To = From + 1
	MOV BH, byte [WDOLFT] ; Column = left margin
	MOV	AH,BH
	MOV CL, byte [WDOBOT]
	SUB	CL,AL ; Count of lines =(window bottom)-top of scroll
	PUSH	AX
	JBE	SCRDL3 ; BRIF null scroll, just clear line
	MOV CH, byte [WDORGT] ; Scroll lines, not columns
SCRLD1:	CALL	SCROLL ; Scroll screen
;If CSRY, FSTLIN, LSTLIN are within scroll, increment their values
	ADD	AL,CL ; AL=Last line scrolled
	DEC	AL
	MOV	AH,0o1 ; increment line# variables in scroll window
	CALL	TSTSCR
;Clear the last line of the scroll(in DL)
SCRDL3:	MOV DH, byte [WDOLFT]
	POP	AX
	OR	CL,CL
	JS	SCRDL4 ; No scroll(out of window)
	JE	SCRDL4 ; No scroll(one line init)
	CALL	SCRDTT ; Scroll down term table(mark last line init'd)
SCRDL4:	CALL	PLINIT ; Init physical line from (DL,DH) to (DL,WDORGT)
	POP	CX
	POP	BX
	POP	AX
	RET
;SCROLL DOWN current line to next line
SCRDLN:	PUSH	AX
	PUSH	BX
	PUSH	CX
	MOV	AX,DX ; Start of scroll is current line
	MOV AH, byte [WDOLFT]
	MOV	BX,AX
	INC	BL ; TO start is next line
	MOV CH, byte [WDORGT]
	MOV	CL,0o1 ; Scroll one entir line
	PUSH	AX
	JMP	SCRLD1 ; Do scroll and update LSTPOS, FSTPOS, CSRY
; SUBTTL  SCROLL ROUTINES - Support routines: scroll terminator table, line init
;Scroll up terminator table(same parameters as SCROLL)
;                   on entry:   (see SCROLL)
;                   on exit:    modifies AX, BX, CX
;
SCRUTT:	PUSH	DX
	MOV	DL,BL
	CALL	SCNRDT ; TRMCUR=address of top of scroll
	MOV BX, word [TRMCUR]
	MOV	CH,0o0
SCRUTL:	MOV	AX,word [LINTTB+BX] ; Get a terminator
	MOV	word [LINTTB+BX-0o2],AX ; Save a terminator
	INC	BX
	INC	BX
	LOOP	SCRUTL ; Continue till done
	MOV	byte [LINTTB+BX-0o2],0o0 ; Terminate end line of scroll
	MOV	byte [LINTTB+BX-0o1],TRMEOL
	POP	DX
	RET
;Scroll down terminator table(same parameters as SCROLL)
;                   on entry:   (see SCROLL)
;                   on exit:    modifies AX, BX, CX
;
SCRDTT:
	PUSH	DX
	MOV	DL,AL
	ADD	DL,CL
	CALL	SCNRDT ; TRMCUR=displacement of bottom of scroll + 2
	MOV BX, word [TRMCUR]
	MOV	CH,0o0
SCRDTL:	SUB	BX,0o2 ; Next posn
	MOV	AX,word [LINTTB+BX-0o2] ; Get a terminator
	MOV	word [LINTTB+BX],AX ; Save a terminator
	LOOP	SCRDTL ; Continue till done
	MOV	byte [LINTTB+BX-0o2],0o0 ; Terminate end line of scroll
	MOV	byte [LINTTB+BX-0o1],TRMEOL
	MOV DL, byte [WDOBOT]
	CALL	SCNRTL
	JB	SCRDT1 ; EOL term'd, all done
	JNZ	SCRDT1
	DEC	AH
SCRDT1:	MOV	AL,TRMEOL
	CALL	SCNWTT ; Make sure last line in window is EOL term'd
	POP	DX
	RET
;Physical line initialization
;               on entry:   (DH,DL) = start of initialization
;
PLINIT:	PUSH	CX
	PUSH	AX
	CALL	SCNRDT
	MOV	AH,DH
	DEC	AH
	PUSH	BX
	MOV BX, word [TRMCUR] ; Terminate line to left of DH
	MOV	byte [LINTTB+BX-0o1],TRMEOL
	MOV	byte [LINTTB+BX-0o2],AH
	POP	BX
	POP	AX
PLINI2:	CALL	CLREOL ; Clear to end of line from (DH,DL)
	POP	CX
	RET
; SUBTTL  LABEL Key Processing
;LABELK - If function key display is off then turn on and exit.
;         If function key display is on then advance display line and
;         redisplay.
;ENTRY  - DX = cursor position
;EXIT   - DX unmodified
;USES   - AX,BX,CX
;
extern FKYADV
extern KEYDSP
extern FKYFMT
extern KEYSW
LABELK:	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	SI
	PUSH	DI
	CMP byte [KEYSW], 0 ;Test for key on
	CALL	FKYADV ;If KEYSW was 0(ZF=0) then init PF start key,
;   else advance to next set of PF keys
;   return ZF=1 if advance beyond last of PF keys
	JZ	LABOFF ;Process key off request
	MOV byte [KEYSW], 255 ;Turn on key display flag
LABDSP:	CALL	KEYDSP ;Display function keys
	POP	DI
	POP	SI
	POP	DX
	POP	CX
	POP	BX
	POP	AX
	RET
LABOFF:
	MOV byte [KEYSW], 0 ;Turn the key flag off
	JMP	LABDSP ;Go clear the function key display line
; SUBTTL  Miscellaneous editor interface routines
;SUBROUTINE SCNMRK              ; Mark current position as first posn of logical
;**                 on entry:   ZF=1 indicates INPUT statement, AL=1 indicates
;**                                 EDIT statement.
;**                 on exit:    -
;**
SCNMRK:	PUSHF
	MOV DL, byte [CSRY]
	MOV DH, byte [CSRX]
	DEC	AL
	JNZ	SCNMK0 ; Not begin of EDIT statement
	CALL	LSTART ; Set (DH,DL)=start of current line
	PUSH	BX
	JMP	SCNMK2
;** IF NOT TOP OF WINDOW
SCNMK0:	CALL	CSRUP ; Move to previous line
	JB	SCNMK1 ; BRIF at top of window
;** *** TERMINATE PREVIOUS PHYSICAL LINE
	CALL	SCNRTL
	MOV	AL,TRMEOL ; Make sure current line is start of logical line
	CALL	SCNWTT
	INC	DL ; Restore current line number
;** IF LINE IS MARKED WITH NULL
SCNMK1:	CALL	SCNRDT
	PUSH	BX
	MOV BX, word [TRMCUR]
	TEST	byte [LINTTB+BX-0o1],TRMNUL
	JZ	SCNMK2 ; BRIF not specially marked line
	PUSH	DX
	PUSH	CX
;** SCAN LINE FOR NULL CHAR(255 DECIMAL)
	MOV DH, byte [WDOLFT]
	MOV CL, byte [LINLEN]
SCNMKL:	CALL	SCRINP
	CMP	AL,255
	JZ	SCNML3 ; BRIF is specially marked line
SCNML2:	INC	DH
	SUB	CL,0o1
	JA	SCNMKL ; BRIF more chars to check
	OR	SP,SP
SCNML3:
	POP	CX
	POP	DX
	JNZ	SCNMK2 ; BRIF char was not on line, don't clear line
;** *** DELETE IT
	CALL	LDELET ; Delete this line
;** IF NOT DIRECT, SET LSTPOS, FSTPOS = CURRENT_POSN
SCNMK2:
	MOV byte [CSRY], DL
	MOV byte [CSRX], DH ; Update CURS_POSN in case of change
	POP	BX
	POPF
	JZ	SCNMK3 ; INPUT statement, use current posn
	MOV byte [LSTLIN], 0o377 ; Direct, set FSTPOS, LSTPOS to min and max
	MOV byte [FSTLIN], 0o0
	JMP	SCNMKX
SCNMK3:	MOV byte [LSTLIN], DL
	MOV byte [FSTLIN], DL
	DEC	DH
	MOV byte [LSTCOL], DH ; Mark LSTCOL one to left of current posn
	INC	DH
	MOV byte [FSTCOL], DH
SCNMKX:	RET
;** END SUBROUTINE SCNMRK
; SUBTTL  Read logical line
;SUBROUTINE SCNRDL              ; Read a logical line
;**                     on entry:   ZF=1 indicates ignore FSTPOS, LSTPOS(statement
;**                                     line input).
;**                                 DX=current posn(within logical line to return)
;**                                 BX=buffer address
;**                                 CX=max count
;**                     on exit:    BX=last char address plus one
;**                                 CX=CX - (count of chars moved)
;**                                 DX=destroyed
;**
SCNRDL:	PUSHF ; Save statement input flag
;** Set DX=start of move
;** WHILE ((DL .NE FSTLIN) AND DL IN_SAME_LOGICAL_LINE)
SCRD00:	CMP DL, byte [FSTLIN]
	JZ	SCRD01 ; Found first line of logical
;** *** DL = PREVIOUS LINE
	CALL	CSRUP
	JB	SCRD01 ; At top of window, stop here
	CALL	SCNRDT
	JNB	SCRD00 ; Still same logical, continue
	INC	DL ; Set DL = first physical of logical
;** IF (STATEMENT_INPUT OR (NOT ON FIRST_LINE))
SCRD01:	POPF ; We have start line, now get start column
	PUSHF
;** *** START_COLUMN=LEFT_MARGIN
	MOV DH, byte [WDOLFT] ; Assume start at left margin
	JNZ	SCRD02 ; BRIF statement input
	CMP DL, byte [FSTLIN]
	JNZ	SCRD02 ; BRIF not on FIRST_LINE
;** *** ELSE START_COLUMN=FIRST_COLUMN
	MOV DH, byte [FSTCOL]
;** WHILE (POSN IS ON SAME LOGICAL) AND ((POSN .LTE. LSTPOS) OR STATEMENT_INPUT) BEGIN
SCRD02:	POPF
	PUSHF
	JNZ	SCRD03 ; BRIF statement input, ignore LSTPOS
	CMP DL, byte [LSTLIN]
	JA	SCRDXZ ; **BRIF passed LSTPOS(was at prev. line term'r)
	JNZ	SCRD03 ; BRIF not at LSTPOS
	CMP DH, byte [LSTCOL]
	JA	SCRDXZ ; BRIF beyond LSTPOS, all done
;** *** READ A CHARACTER INTO THE BUFFER
;** *** DO CASE TERMINATOR OF LINEFEED, NULL_WRAP, WRAP, BEFORE EOL, AT EOL
SCRD03:	CALL	SCNRDT
	PUSH	AX
	JB	SCRD04 ; BRIF not reading a linefeed
	JNZ	SCRD04 ; BRIF not reading a linefeed
	CMP	AH,DH
	JNZ	SCRD04 ; BRIF not reading a linefeed
;** *** *** CASE: LINEFEED
SCRDLF:	MOV	AX,CHRLNF+0o0
	JMP	SCRD08 ; At linefeed terminator, pass linefeed
SCRD04:	CMP	AH,DH
	JA	SCRD07 ; BRIF within data on screen
	JB	SCRD06 ; BRIF beyond terminator
;** *** *** CASE: NULL_WRAP
	CMP	AL,TRMNWP
	JNZ	SCRD07 ; BRIF not at NULL_WRAP terminator
SCRD06:	CMP	AL,TRMEOL
	POP	AX
	JZ	SCRDXZ ; BRIF beyond EOL
;** *** *** CASE: WRAP
	INC	DL ; Wrap to next line
	MOV DH, byte [WDOLFT]
	JMP	SCRD02
;** *** *** CASE: BEFORE EOL
SCRD07:
	CLC ; Indicate call is from Screen Editor
	CALL	SCRINP ; AX=Character at (DH,DL)
SCRD08:	MOV	byte [BX+0o0],AL
	DEC	CX
	POP	AX
	JZ	SCRDEX
	CMP	AL,TRMEOL
	JNZ	SCRD09 ; BRIF not at EOL
	CMP	AH,DH
	JBE	SCRDEX ; BRIF at EOL(or beyond), all done
SCRD09:	INC	BX
	CALL	CSRADV
	JB	SCRDXZ ; If end of window, all done
	JMP	SCRD02 ; Pass next character
;** *** *** CASE: AT(OR BEYOND) EOL
SCRDEX:	INC	BX ; Set BX= last posn written plus one
SCRDXZ:	POPF
	CALL	SCNBRK ; Clear any flags associated with INPUT
	RET
;** *** *** END
;** *** END
;** END SUBROUTINE SCNRDL
; SUBTTL  CONTROL CHARACTER ROUTINES
;CONTROL CHARACTER DISPATCH TABLE
;**
FUNTAB: dw CTLIGN ; ^@  -  Ignore
dw CTLIGN ; ^A  -  Ignore
dw BCKWRD ; ^B  -  Back one word
dw CTLIGN ; ^C  -  Ignore
dw CTLIGN ; ^D  -  Ignore
dw LTRUNC ; ^E  -  Truncate logical line
dw FWDWRD ; ^F  -  Forward one word
dw CBEEP ; ^G  -  Beep
dw BAKSPC ; ^H  -  Destructive backspace
dw LTAB ; ^I  -  Destructive tab
dw LFEED ; ^J  -  Linefeed
dw WHOME ; ^K  -  Home within window
dw CCLRSN ; ^L  -  Clear window, home cursor
dw LCARET ; ^M  -  Carriage return
dw LAPPND ; ^N  -  Append to end of line
dw CTLIGN ; ^O  -  Ignore
dw CTLIGN ; ^P  -  Ignore
dw CTLIGN ; ^Q  -  Ignore
dw LINSRT ; ^R  -  Insert a blank
dw CTLIGN ; ^S  -  Ignore
dw LABELK ; ^T  -  LABEL Key
dw LDELET ; ^U  -  Delete a line
dw CTLIGN ; ^V  -  Ignore
dw WDELET ; ^W  -  Delete a word
dw CTLIGN ; ^X  -  Ignore
dw CTLIGN ; ^Y  -  Ignore
dw WERASE ; ^Z  -  Erase to end of window
dw CTLIGN ; ^[ or ESC - Ignore
dw WCSADV ; ^\  -  Cursor advance within window
dw WCSREG ; ^]  -  Cursor regress within window
dw WCSUP ; ^^  -  Cursor up within window
dw WCSDWN ; ^_  -  Cursor down within window
dw CDELET ; DEL -  Delete a character
;SUBROUTINE CTLDSP(CONTROL_CHAR); Do control char logic
;**                         on entry:   AX=control character
;**                         on exit:    if CF=0 then AX=character to output
;**                                     if CF=1 then AX is undefined
CTLDSP:
	CALL	SCNPOS ; DH=column, DL=row
extern CSRTYP
extern SETCSR
	MOV byte [CSRTYP], 0 ; Set for off cursor
	CALL	SETCSR ; Ensure that the cursor is off
	MOV DH, byte [CSRX] ; Set DH=true posn(not width truncated)
	TEST byte [ESCFLG], 0o377
	JNZ	DOESC ; BRIF in middle of escape sequence
	CMP	AL,0o33
	JZ	DOESC
CTLDS0:
CTLDP0:
CTLDP1:
extern EDTMAP
extern PRTMAP
	TEST byte [F_EDIT], 0o377 ; Test for Screen Edit mode
	JZ	CTLPRT ; BRIF not edit mode
	CMP	AH,1 ; Set PSW.C if two byte character
	CMC
	CALL	EDTMAP ; Map edit function/output character code
	JMP	CTLEDT
CTLPRT:	CMP	AH,1 ; Set PSW.C if two byte character
	CMC
	CALL	PRTMAP ; Map print function/output character codes
CTLEDT:	JZ	CTLDPY ; Ignore this character
; Print or perform the editor function
	CMP	AH,255 ; Is it an editor function (&HFF)?
	JNZ	CTLDSX ; No - print the character
	XOR	AH,AH ; Clear (no longer needed) editor function flag
	CMP	AL,0o177 ; Delete function?
	JNZ	CTLNDL ; BRIF not DEL
	MOV	AL," " ; DEL code
CTLNDL:	CMP	AL,255
	JNZ	CTLNMK ; BRIF not "mark line for deletion"
	PUSH	AX
	PUSH	BX
	CALL	SCNRDT
	MOV BX, word [TRMCUR]
	OR	byte [LINTTB+BX-0o1],TRMNUL ; Set "not for input" flag on this line
	POP	BX
	POP	AX
;       STC
	RET
CTLNMK:	CMP	AL," "+0o1 ; Test for legal function code
	JNB	CTLDPY ; Ignore this code
	PUSH	AX
	CALL	CTLIRS ; Possibly reset insert flag
	ADD	AX,AX ; Two bytes per entry
	MOV	BX,AX
	MOV	AX,CTLDPX
	PUSH	AX ; Put return on stack
	MOV	AX,word [FUNTAB+BX]
	PUSH	AX ; Put routine address on stack
CTLDSX:	CLC
	RET ; Go do control routine
;** *** UPDATE CURRENT_POSN, RETURN
CTLDPX:	MOV byte [CSRY], DL
	MOV byte [CSRX], DH ; Update cursor posn
	POP	AX
	SUB	AL,CHRRET
	MOV byte [F_CRET], AL ; F.CRET = 0 if character was Carriage return
CTLDPY:
	STC
CTLIGN:
CTLDPZ:	RET
;** ESCAPE SEQUENCE PROCESSING
DOESC:	CALL	SCROUT ; Returns carry set if continuation of escape sequence
	SBB	AL,AL ; If ESC sequence, AL=FF else AL=0
	MOV byte [ESCFLG], AL ; Set/Reset flag
	JMP	CTLDPY
;** END SUBROUTINE CTLDSP
;THE CONTROL CHARACTERS WHICH RESET INSERT FLAG ARE IN TABLE BELOW:
;
CTLITB:
db CHRLDL ; LINE_DELETE
db CHRERA ; ERASE_SCREEN
db CHRFDW ; FORWARD_WORD
db CHRBKW ; BACKWARD_WORD
db CHRAPP ; APPEND_TO_LINE
db CHREDT ; EDIT_PREVIOUS_LINE
db CHRCLE ; CLEAR_TO_END
db CHRBEL ; BELL
db CHRHOM ; HOME
db CHRADV ; CURSOR_ADV
db CHRREG ; CURSOR_REG
db CHRUP ; CURSOR_UP
db CHRDWN ; CURSOR_DOWN
CTLCNT equ $-CTLITB
;SUBROUTINE CTLIRS              ; Reset insert flag for specified characters
;**                 on entry:   AL=character
;**                 on exit:    DI garbaged
;**
CTLIRS:	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DI
;** IF (SPECIAL_ACTION(CTLKEY))
	MOV	DI,CTLITB ; DI= [control char table]
	MOV	CX,CTLCNT ; CX= count of entries in table
	MOV	BX,CX
	PUSH	ES
	PUSH	CS ; Scan in code segment
	POP	ES
	CLD ; Scan forward
 REPNE	SCASB ; Scan for character in table
	POP	ES
	JNE	INCNOT ; BRIF did not find the control character
;** *** F.INSRT=FALSE
	MOV byte [F_INST], 0o0 ; Reset insert flag
INCNOT:	POP	DI
	POP	CX
	POP	BX
	POP	AX
	RET
;** END SUBROUTINE CTLIRS
;** *** END
; SUBTTL  CONTROL CHARACTER ROUTINES - Cursor movement by character, line and TAB
;The control character routines are entered with DH=current column and
;   DL=current line. They return updated posn in the same registers. They
;   can modify AX, BX, CX but must save any other registers used.
;CURSOR CONTROL
;   The cursor control routines are somewhat special. Except for cursor advance,
;   the cursor is made to stay within previously printed data. The cursor
;   advance routine will append blanks by changing the logical right margin,
;   without actually printing anything. All of the cursor control routines
;   will update FSTPOS and LSTPOS as long as the cursor stays within a logical
;   line. When the cursor leaves a logical line, the FSTPOS and LSTPOS values
;   do not change. If the cursor is then moved back onto the original logical
;   line, the values are updated once more.
;
;Cursor advance
WCSADV:	CALL	CSRADV ; Advance cursor
	JB	WCSABT ; BRIF can't do, quit
;       CALL    SCNRDT          ; AH=end of this physical, AL=terminator
;       CMPB    DH,AH
;If cursor beyond previously printed data, don't update LSTCOL
;       JAE     WCSABT          ; BRIF not to left of line terminator posn
;If cursor beyond previous LSTPOS and on same logical, update LSTPOS
UPDPOS:	PUSH	DX
	DEC	DH ; LSTCOL is to left of cursor
	CMP DL, byte [LSTLIN]
	JB	UPDPS3 ; BRIF not new LSTPOS
	JZ	UPDPS2 ; BRIF on same line, possibly update LSTPOS
	PUSH	DX
	CALL	LSTART ; Get start line of current logical
	CMP DL, byte [LSTLIN]
	POP	DX
	JA	UPDPS3 ; BRIF LSTPOS not on current logical line
;LSTPOS on current logical, previous physical
	MOV byte [LSTLIN], DL ; Set LSTPOS to current
	MOV byte [LSTCOL], DH
UPDPS2:	CMP DH, byte [LSTCOL]
	JBE	UPDPS3 ; BRIF not new last posn
	MOV byte [LSTCOL], DH ; Set new last posn
;If cursor before previous FSTPOS and on same logical, update FSTPOS
UPDPS3:	INC	DH ; Restore column
	CMP DL, byte [FSTLIN]
	JNZ	UPDPSX ; BRIF not on same line as first position
	CMP DH, byte [FSTCOL]
	JAE	UPDPSX ; BRIF not new first position
	MOV byte [FSTCOL], DH ; Set new first position to current position
UPDPSX:	POP	DX
WCSABT:	RET
;Cursor regress
WCSREG:	CALL	CSRREG ; Move cursor
	JB	WCSABT ; Can't move, quit
WCSRET:	CALL	SCNRDT
	CMP	AH,DH
	JNB	UPDPOS ; Within logical, update FSTPOS, LSTPOS, return
;Cursor to right of line terminator, don't update LSTCOL
	JMP	WCSABT ; Return
;Cursor up
WCSUP:	CALL	CSRUP ; Move cursor
	JNB	WCSRET ; BRIF successful, possibly update FSTPOS, LSTPOS
	RET ; Unsuccessful, return(NOP)
;Cursor down
WCSDWN:	CALL	CSRDWN ; Move cursor
	JNB	WCSRET ; BRIF successful, possibly update FSTPOS, LSTPOS
	RET ; Unsuccessful, return(NOP)
;TAB                            ; Move cursor to next TAB stop
;
LTAB:	TEST byte [F_INST], 0o377
	JZ	LTABL ; BRIF not insert TAB
;Insert spaces until CSRX is at TAB stop or LINLEN
LTABIL:	MOV	AX," "
	CALL	SCNOUT ; Insert a blank
	MOV DL, byte [CSRY]
	MOV DH, byte [CSRX]
	CMP DH, byte [LINLEN]
	JA	LTABZ ; All done, at end of line
	DEC	DH
	TEST	DH,0o7
	JNZ	LTABIL ; Keep inserting
	INC	DH
	JMP	LTABZ ; All done, at TAB stop
;Non-insert TAB, just pass over characters
LTABL:	CMP DH, byte [LINLEN]
	JAE	LTABX0 ; BRIF need to wrap
	INC	DH
	TEST	DH,0o7
	JNZ	LTABL
	INC	DH
	JMP	LTABX ; BRIF reached good posn
LTABX0:	CMP DL, byte [WDOBOT]
	JAE	LTABZ ; BRIF no room to end of page
	INC	DL
	MOV DH, byte [WDOLFT] ; Else move to start of next line
LTABX:	CALL	UPDPOS ; Update LSTPOS
LTABZ:	RET
; SUBTTL  CONTROL CHARACTER ROUTINES - Cursor movement by word
;Advance cursor to beginning of next word within screen
FWDWRD:	PUSH	DX
	PUSH	word [LSTLIN]
	CMP DL, byte [LSTLIN]
	JNZ	FWDWR0 ; BRIF LSTPOS not on this line
	CMP DH, byte [LSTCOL]
	JB	FWDWR0 ; BRIF within logical line
	MOV byte [LSTLIN], 0o377 ; Ignore LSTPOS in scan
FWDWR0:	CLC
FWDWR1:	CALL	FWDWDL ; Try within logical
	JB	FWDWR2 ; BRIF unsuccessful
	POP	word [LSTLIN]
	CALL	UPDPOS
	POP	AX ; Remove old posn from stack
	RET
;Reached end of logical line, try next logical
FWDWR2:	CALL	CSRDWN
	JB	FWDWRZ ; BRIF end of screen
	MOV DH, byte [WDOLFT] ; Start scan again at next line
	STC
	JMP	FWDWR1 ; Continue scan
;Unsuccessful, return cursor to original posn
FWDWRZ:	POP	word [LSTLIN]
	POP	DX
	RET
FWDWD0:	CALL	LCSADV
	JB	FWDWD3 ; At end of logical line
;Advance cursor to beginning of next word within logical line
FWDWDL:	JB	FWDWD2 ; Start as though between words
	CALL	ANCHK ; Check if current char is within word
	JNB	FWDWD0 ; BRIF still within previous word
;At space between words
FWDWD1:	CALL	LCSADV
	JB	FWDWD3 ; At end of logical line, check next logical
FWDWD2:	CALL	ANCHK
	JB	FWDWD1
FWDWDX:	RET ; Return, DX=posn of new word or end of logical line
FWDWD3:	JNZ	FWDWDX ; BRIF not stop at LSTPOS
;Stopped at LSTPOS, continue scan to end of physical line
	CMP	AH,DH
	JA	FWDWD4 ; BRIF more this line
	STC
	RET
FWDWD4:	MOV byte [LSTLIN], 0o377 ; Ignore LSTPOS from here on
	JMP	FWDWD1 ; Since crossed LSTPOS, passed end of current word
;Regress cursor to start of previous word
BCKWRD:	PUSH	word [FSTCOL]
	PUSH	DX
	CMP DH, byte [FSTLIN]
	JNZ	BCKWD2
	CMP DH, byte [FSTCOL]
	JA	BCKWD2
	MOV byte [FSTLIN], 0o0
;Assume passed beginning of current word, continue to start of next
BCKWD2:	CALL	LCSREG
	JB	BCKWD7 ; BRIF At start of line
BCKWD4:	CALL	ANCHK
	JB	BCKWD2 ; BRIF still between words
;Scanning previous word, any termination is good
BCKWD5:	CALL	LCSREG
	JB	BCKWD6 ; BRIF at beginning of line, found previous word
	CALL	ANCHK
	JNB	BCKWD5 ; BRIF not at beginning of word
	CALL	CSRADV ; Advance back to start of word
BCKWD6:	POP	AX
	PUSH	DX ; Push new posn on stack
BCKWDX:	POP	DX
	POP	word [FSTCOL]
	CALL	UPDPOS
	RET ; Return, DL=posn of previous word
BCKWD7:	JNZ	BCKWD8 ; BRIF not stop at FSTPOS
	MOV byte [FSTLIN], 0o0 ; Ignore FSTPOS from here on
	JMP	BCKWD2 ; Since passed begginning of logical, between words
BCKWD8:	CALL	CSRUP ; Try previous logical line
	JB	BCKWDX ; At beginning of screen
	CALL	SCNRDT ; Read previous line teminator
	OR	AH,AH
	JZ	BCKWD8 ; Previous line is null, try next previous
	MOV	DH,AH
	JMP	BCKWD4 ; Continue scan
; SUBTTL  CONTROL CHARACTER ROUTINES - Screen home, truncate and clear
extern BEEP
CBEEP:	CALL	BEEP ; Sound Bell
	JMP	SCNPOS ; return current cursor location
extern CLRSCN
;Clear the screen
CCLRSN:
	CLC ; no-carry = internal parameter
	MOV	AL,0o2 ; specify text only
	CALL	CLRSCN ; OEM supplied Clear-Screen Routine
;fall into WHOME
;Home the cursor
WHOME:	MOV DL, byte [WDOTOP]
	MOV DH, byte [WDOLFT]
	RET
;Erase to the end of the screen
WERASE:	CALL	PLINIT ; Clear current physical to end of line
	PUSH	DX
	MOV DH, byte [WDOLFT] ; Clear rest of lines from left margin
;WHILE POSN .LTE. WDOBOT
;** IF DATA_EXISTS(POSN) THEN INITIALIZE LINE
WERAS0:	INC	DL
	CMP DL, byte [WDOBOT]
	JA	WERASX ; Beyond window, exit
	CALL	PLINIT ; Clear this line
	JMP	WERAS0 ; Init next line
WERASX:	POP	DX ; Return DX=cursor posn
	RET
; SUBTTL  CONTROL CHARACTER ROUTINES - Line truncate and delete
;Delete entire logical line
LDELET:	CALL	LSTART ; Get start of logical line in DX
;Truncate line from posn in DX
LTRUNC:	PUSH	DX
	CALL	SCNRTL ; AH=last valid data on physical line
	PUSHF
	STC ; Indicate don't clear line by scrolling
	CALL	LCLEAR ; Clear this physical line
	JB	LTRUN9 ; Reached LSTPOS, all done
	INC	DL
;"Suck up" remaining physical lines attached to current logical
LTRUN1:	POPF
	JB	LTRUNX ; Reached end of logical line
	CALL	SCNRTL
	PUSHF
	MOV DH, byte [WDOLFT]
	CLC
	CALL	LCLEAR ; Clear this line from start of line
	JB	LTRUN9 ; Reached LSTPOS, all done
	JMP	LTRUN1
LTRUN9:	POPF
LTRUNX:	POP	DX
	RET
;Clear current physical to end of physical or LSTPOS, whichever is smallest
; (DH,DL)=start posn, AH=TERM_POSN, if CF=1, don't scroll
LCLEAR:	PUSHF
	CMP DL, byte [LSTLIN]
	JZ	LCLER2 ; BRIF clear up to LSTPOS
LCLER0:	CMP DH, byte [WDORGT]
	JA	LCLER5 ; BRIF beyond end of physical(just exit)
	POPF
	JNB	LCLER1 ; BRIF clear line by scroll
	CALL	PLINIT ; Clear this physical line
	CLC
	RET
LCLER1:	CALL	SCRLU0 ; Scroll up from bottom to current line
	CLC
	RET
LCLER2:	POPF
	CALL	PLINIT
	STC
	RET
LCLER5:	POPF
	CLC
	RET
; SUBTTL  CONTROL CHARACTER ROUTINES - Character and word delete
;Word delete
;
WDELET:
	CMP DH, byte [LINLEN]
	JBE	WDELT0 ; BRIF on physical line
	CALL	CSRADV ; Put cursor on next line
	JB	WDELTZ ; BRIF at end of screen
WDELT0:
	CMP DL, byte [LSTLIN] ; **
	JNZ	WDELT2 ; **BRIF not on LSTPOS line
	CMP DH, byte [LSTCOL] ; **
	JAE	WDELTZ ; **BRIF at or beyond LSTPOS(don't do word delete)
WDELT2: ; **
	PUSH	DX
	CMP DH, byte [LINLEN]
	JBE	WDELT4 ; Good delete posn(within physical line)
	CALL	LCSADV ; Advance cursor to next physical of logical
WDELT4:	PUSH	DX
	CLC
	PUSH	word [LSTLIN]
	CALL	FWDWDL ; Set (DH,DL)= start of next word or end of line
	POP	word [LSTLIN]
	JNB	WDELT6 ; BRIF found another word following
;No word following, just delete to end of line
	INC	DH ; Include terminator in delete
WDELT6:	MOV	CX,DX
	POP	DX
	CMP CL, byte [LSTLIN] ; **
	JB	WDELT8 ; **BRIF not beyond LSTPOS line
	JA	WDELT7 ; **BRIF beyond LSTPOS line, use LSTPOS
	CMP CH, byte [LSTCOL] ; **At LSTPOS line, check if column is OK
	JB	WDELT8 ; **BRIF before LSTPOS, column is OK
WDELT7:	MOV CX, word [LSTLIN] ; **Use LSTPOS as end of delete
	INC	CH ; **INC because delete is up to char before this posn
WDELT8: ; **
	CMP	DL,CL
	JNZ	WDELTC ; BRIF multiple line delete
WDELT9:	SUB	CH,DH ; CH=chars to next word minus one
	JBE	WDELTX ; BRIF no chars to delete
	CALL	CDELLG ; Delete CH chars in this line
WDELTX:	POP	DX
WDELTZ:	RET
WDELTC:	INC	DL
WDELTD:	PUSH	DX
	PUSH	CX
; Delete across physical lines, delete to end of this line
	CMP	DL,CL
	MOV DH, byte [WDOLFT]
	JZ	WDELTE
	CALL	SCNRTL
	MOV	CH,AH
	CALL	CDELPH ; Erase intervening line
	POP	CX
	POP	DX
	DEC	CL ; Each erase of intervening line brings CL closer
	JMP	WDELTD
WDELTE:	CMP CH, byte [WDOLFT]
	JBE	WDELTF ; BRIF at begin of line
	DEC	CH
	CALL	CDELLG ; Delete up to the next word on this line
WDELTF:	POP	CX
	POP	DX
	DEC	DL ; Go back to original line
	MOV CH, byte [LINLEN]
	INC	CH
	JMP	WDELT9 ; Delete to end of line
;Destructive back space
;
BAKSPC:
	CALL	LCSREG ; Back space within logical line
	CALL	SCNRTL
	CMP	DH,AH
	JBE	CDELET ; BRIF current posn less than TERM_POSN
	CMP AH, byte [WDOLFT]
	JAE	BAKSP1 ; BRIF not on null line
	MOV AH, byte [WDOLFT]
BAKSP1:	MOV	DH,AH ; If beyond terminator, set posn to terminator
;Delete character
;
CDELET:	MOV	CH,0o1 ; Assume one byte char delete
	CMP DH, byte [LINLEN]
	JBE	CDELT1 ; BRIF within physical line
	RET
CDELT1:
;SUBROUTINE CDELLG:             ; Delete CH characters @(DH,DL) within logical
;                       On entry:   CH=count, CL= flag, (DH,DL)=posn
;                                   If CL is non-zero, remove null line from screen
;
CDELLG:	PUSH	DX
	CALL	SCNRTL ; Get last valid char posn in AH
	PUSHF
	CALL	CDELPH ; Delete characters from current physical
;   returns new term posn in AH
	XOR	CL,CL ; CL is iteration counter
	POPF
	MOV	AL,TRMEOL
	JB	CDLGEX ; BRIF was EOL term'd, update terminator, exit
	JNZ	CDLGWP ; BRIF line was WRAP or NULL_WRAP term'd, get
;       chars from next line
;Line was LF terminated, check for LF delete
	CMP	AH,DH
	MOV	AL,TRMLNF
	JA	CDLGEX ; BRIF didn't delete LF, update terminator, exit
	OR	AH,AH
	JZ	CDLGRT ; **BRIF entire line deleted and removed
	MOV	AH,DH
	JMP	CDLWP1
;Need to get chars from next physical line at (AH,DL) posn to end of physical
CDLGWP:	OR	AH,AH
	JZ	CDLGRT ; BRIF entire line deleted and removed
	INC	AH
CDLWP1:	CMP DL, byte [LSTLIN] ; **
	JZ	CDLGRT ; **LSTPOS on this line, all done
	PUSH	word [LSTLIN] ; **Save current LSTPOS
	CALL	CDUNWP ; Unwrap the characters desired returns terminator
;     in (AH,AL) and byte count in CH
	CALL	SCNWTT ; Update terminator
	OR	CH,CH
	JNZ	CDLWP2 ; BRIF we have characters to unwrap
	POP	AX ; Restore the stack
	JMP	CDLGRT ; Return, all done
;Need to delete CH characters unwrapped from next line
CDLWP2:	MOV DH, byte [WDOLFT] ; Unwrapped from start of line
	INC	DL ; Next line
	DEC	CL ; Update iteration counter
	CALL	SCNRTL ; Read next lines terminator
;Need to restore LSTPOS to old value for character delete
	MOV DI, word [LSTLIN] ; **Save current value of LSTPOS in SI
	POP	word [LSTLIN] ; **Restore value before CDUNWP so CDELPH works properly
	PUSHF
	PUSH	DI ; **Save current "true" value of LSTPOS
	XCHG	DI,AX ; **
	CMP AL, byte [LSTLIN] ; **
	PUSHF ; **
	XCHG	DI,AX ; **
	CALL	CDELPH ; Delete chars to end of line or LSTPOS
	POPF ; **
	POP	DI ; **
	JZ	CDLGNC ; **BRIF CDUNWP did not change LSTPOS
	MOV word [LSTLIN], DI ; **Restore CDUNWP value of LSTPOS
CDLGNC:	OR	AH,AH
	JNZ	CDLGW1 ; BRIF still chars on this line
	POPF
	JNB	CDLGRT ; BRIF LF or wrap term'd, already removed
CDLGNL:	DEC	DL
	INC	CL
	CALL	SCNRTL
	JB	CDLGN0 ; BRIF previous line EOL term'd, remove null line
	JZ	CDLGRT ; BRIF previous line LF term'd, leave null line
	MOV	AL,TRMEOL
	CALL	SCNWTT ; Previous line was wrapped, terminate it and
;   remove null line
CDLGN0:	INC	DL
	DEC	CL
	CALL	SCRLU0 ; Remove null line by scrolling
	JMP	CDLGRT ; All done
CDLGW1:	POPF
	JB	CDLGEX ; BRIF at EOL, all done
	JNZ	CDLGWP ; BRIF wrapped, unwrap chars from next line
;We have terminator in (AH,AL), posn in (DH,DL)
CDLGEX:	CALL	SCNWTT ; Update terminator
CDLGRT:	ADD	CL,DL
	POP	DX
	MOV	DL,CL
	RET
CDUWXI:	MOV	CH,0o0 ; Indicate no characters unwrapped
	JMP	CDUWPX ; Indirect jump
;SUBROUTINE CDUNWP:             ; "Unwrap" chars from next line
;                       On entry:   (AH,DL)= destination
;                       On exit:    (AH,AL)= new line terminator
;                                   CH=nunber of bytes unwrapped
;
CDUNWP:	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	word [TRMCUR]
	MOV	AL,TRMWRP
	MOV CH, byte [LINLEN]
	SUB	CH,AH
	JB	CDUWXI ; BRIF no space to unwrap characters to, just exit
	CMP DL, byte [LSTLIN] ; **
	JNZ	CDUWP0 ; **BRIF not unwrapping to LSTPOS
	TEST byte [LSTCOL], 0o377 ; **
	JNZ	CDUWP0 ; **BRIF have some characters to unwrap
	MOV AH, byte [LINLEN] ; **
	JMP	CDUWXI ; **If no characters to unwrap, just exit
CDUWP0:	INC	CH
	MOV	BX,AX ; Put DESTINATION in BX
	MOV	BL,DL
	INC	DL
	CALL	SCNRTL ; Read terminator for next line
	PUSH	AX
	PUSHF
	CMP	CH,AH
	JBE	CDUWP1 ; BRIF enough characters to satisfy demand
	MOV	CH,AH ; Else get all characters in next line
CDUWP1:	MOV	CL,0o1
	MOV DH, byte [WDOLFT]
	MOV	AX,DX ; Put SOURCE in AX
	OR	CH,CH
	JNZ	CDUWPN ; BRIF not a null line following
	POPF
	PUSHF
	JZ	CDUWP4 ; BRIF LF term'd, don't remove null line
	PUSH	word [TRMCUR]
	CALL	SCRLU0 ; Get rid of null line following
	POP	word [TRMCUR]
	JMP	CDUWP4 ; Set up terminator for return
CDUWPN:
	CALL	SCROLL ; Scroll chars from old line to new
	CMP DL, byte [LSTLIN]
	JNZ	CDUWP4 ; BRIF not on LSTPOS line
;If LSTPOS is between WDOLFT and SOURCE+COUNT, unwrap LSTPOS
	PUSH	AX
	ADD	AH,CH
	SUB AH, byte [LSTCOL]
	POP	AX
	JBE	CDUWP3 ; BRIF LSTPOS .GT. SOURCE+COUNT
	SUB byte [LSTCOL], AH ; LSTCOL=DESTINATION+(LSTPOS-SOURCE)
	JNB	CDUWPL
	MOV byte [LSTCOL], 0o0 ; LSTCOL was zero, don't let it go negative
CDUWPL:	ADD byte [LSTCOL], BH
	DEC	byte [LSTLIN] ; LSTLIN is line unwrapped to
; COMMENT %
; ; Blank from DESTINATION+COUNT-((SOURCE+COUNT)-LSTPOS) to EOL
; 	PUSH    AX
; 	PUSH    DX
; 	PUSH    CX
; 	ADDB    DH,CH
; 	SUBB    DH,AH           ; (DH,DL)=start posn for blanking
; 	MOVB    CH,LINLEN       ; CH=end column
; 	MOVI    AX," "
; CDUWPB: CALL    SCROUT
; 	INCB    DH
; 	CMPB    DH,CH
; 	JBE     CDUWPB          ; Continue blanking to EOL
; 	POP     CX
; 	POP     DX
; 	POP     AX
CDUWP3:
;Return terminator for DL-1
CDUWP4:	ADD	BH,CH ; Get new terminator posn into BH
	DEC	BH
	POPF
	POP	AX ; Restore original terminators for this line
	MOV	BL,TRMEOL ; Assume line unwrapped is at EOL
	JB	CDUWPE ; BRIF at EOL
	MOV	BL,TRMLNF ; Assume LF was unwrapped on unwrapped line
	JZ	CDUWP6 ; BRIF at LF
;WRAP or NULL_WRAP, if BH .NE. LINLEN, then it must be LINLEN-1 and NULL_WRAP
CDUWP5:	MOV	BL,TRMWRP ; Assume line is WRAP
	CMP BH, byte [LINLEN]
	JZ	CDUWP7 ; Previous line is full, must be WRAP
	MOV	BL,TRMNWP
	MOV BH, byte [LINLEN]
	JMP	CDUWP7 ; Previous line not full even though we had
;   enough chars to fill it, must be NULL_WRAP
;EOL terminated
CDUWPE:	OR	AH,AH
	JZ	CDUWP7 ; If unwrapped null line, return EOL
;Was EOL or LF terminated, see if entire line was unwrapped
CDUWP6:	CMP	AH,CH
	JNZ	CDUWP5 ; BRIF wasn't unwrapped, previous line is WRAP
;terminator=(BH,BL)
CDUWP7:	PUSH	BX
;       ORB     CH,CH
;       JZ      CDUWP8          ; BRIF no chars to delete from here on
;       MOVBI   CL,^O377        ; Set flag indicating can remove lines deleted
;       CALL    CDELLG          ; Delete CH characters at (DH,DL)
CDUWP8:	POP	AX
CDUWPX:	POP	word [TRMCUR]
	POP	DX
	MOV	BH,CH
	POP	CX
	MOV	CH,BH
	POP	BX
	RET
;Needed one char and first char on next line is DBLCHR
CDUWPF:	POP	AX
	POPF ; Clean up stack
	MOV AH, byte [LINLEN]
	MOV	AL,TRMNWP ; Set terminator to NULL_WRAP
	JMP	CDUWP7
;SUBROUTINE CDELPH              ; Delete chars on physical line
;                       On entry:   (DH,DL)=posn to start delete from
;                                   (AH,AL)=line terminator for line DL
;                                   CH=count
;                       On exit:    AH=term posn
;                                   (DH,DL)=posn
;
CDELPH: ;PUSH    SI
	XOR	SI,SI ; Set SI to zero(flag no char restore necessary)
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	AX
	CMP	DH,AH
	JA	CDEL9I ; BRIF delete beyond or at physical end
	MOV	BX,DX ; (BH,BL)=DESTINATION
	MOV	AX,DX
	ADD	AH,CH ; (AH,AL)=SOURCE
	POP	CX ; CH=end of physical line
	PUSH	CX
	CMP	AH,CH
	JBE	CDELP0 ; BRIF not deleting more than we have
	MOV	AH,CH
	INC	AH ; Delete entire line
CDELP0:	CMP DL, byte [LSTLIN]
	JNZ	CDELP1 ; BRIF not on line with LSTPOS
	CMP CH, byte [LSTCOL]
	JBE	CDELP1 ; BRIF physical end less than LSTPOS
	MOV CH, byte [LSTCOL] ; Use LSTPOS as end of this line
	CMP	DH,CH
	JA	CDEL9I ; BRIF delete beyond terminator
CDELP1:
	PUSH	CX ; Save last posn of SOURCE
	SUB	CH,AH
	PUSHF
	MOV	DH,BH
	ADD	DH,CH ; (DH,DL)=end of DESTINATION
	POPF
	JB	CDELP4 ; BRIF SOURCE greater than logical end of physical
	MOV	CL,0o1
	INC	CH
	CALL	SCROLL ; Move characters to left
;Blank from end of SOURCE to end of DESTINATION+1
CDELP4:	POP	CX ; CH=end column of SOURCE
	INC	DH ; DH=end column of DESTINATION plus one
	PUSH	DX
	MOV	AX," "
CDELP5:	CMP	DH,CH
	JA	CDELP6
	CALL	SCROUT ; Blank this posn
	INC	DH
	JMP	CDELP5
CDEL9I:	JMP	CDELP9 ; Indirect to CDELP9
CDELP6:	POP	DX ; Restore end column of DESTINATION plus one
	POP	AX ; Restore terminator passed to routine
;CH=last valid column, DH=first blanking column, AH=term column, AL=term type
	CMP DL, byte [LSTLIN]
	JNZ	CDELP7 ; BRIF was not delete before LSTPOS
	CMP CH, byte [LSTCOL]
	JB	CDELP7 ; BRIF delete up to terminator
;Delete included LSTPOS, subtract total deleted from LSTCOL
	POP	DX
	POP	CX
	SUB byte [LSTCOL], CH
	JAE	CDEL8A ; **BRIF LSTCOL valid
	MOV byte [LSTCOL], 0o0 ; **Set LSTCOL to 0
	JMP	CDEL8A ; Delete up to LSTPOS, adjust LSTPOS
;Deleted all data up to terminator, adjust terminator
CDELP7:	MOV	AH,DH
	DEC	AH ; Set terminator to last column of DESTINATION
CDELP8:	POP	DX ; (DH,DL)=original posn(start of DESTINATION)
	POP	CX ; CL=flag
CDEL8A:	CMP	DH,AH
	JBE	CDELPX ; BRIF still data remaining to right
	CMP	DH,0o1
	JNZ	CDELPX ; BRIF still data remaining to left
	CMP	AL,TRMEOL
	JZ	CDELPX ; BRIF don't remove null line
;We have null line, remove it from the screen
	PUSH	word [TRMCUR]
	CMP DL, byte [LSTLIN] ; **If LSTPOS is wiped out, put it at
; ** end of previous line
	JNZ	CDEL8B ; **BRIF not wiped out
	DEC	byte [LSTLIN] ; **
	MOV BH, byte [WDOLFT] ; **
	MOV byte [LSTCOL], BH ; **
CDEL8B: ; **
	CALL	SCRLU0 ; Scroll up from bottom of screen to DL
	POP	word [TRMCUR]
	JMP	CDELPX ; All done
;We are deleting to right of line terminator
CDELP9:	POP	AX ; Restore terminator passed
	CMP	AL,TRMLNF
	MOV	DH,AH ; DH=end of valid data plus one
	JZ	CDELP7 ; BRIF LF term'd, delete it
	POP	DX ; Delete beyond valid data, ignore it
	POP	CX
CDELPX:	POP	BX
	CMP DL, byte [LSTLIN]
	JZ	CDELPF ; BRIF not on LSTPOS line, no update
	CMP AH, byte [LSTCOL]
	JAE	CDELPF ; BRIF LSTPOS is within line, no update
;POP     SI
CDELPF:	RET
; SUBTTL  CONTROL CHARACTER ROUTINES - Line append, carriage return and linefeed
;Append to end of logical line
;
LAPPND:
LAPPN0:	CALL	SCNRDT
	JB	LAPPN1 ; BRIF we are at last line in logical
	INC	DL
	JMP	LAPPN0 ; See if next line is last line in logical
LAPPN1:	MOV	DH,AH ; Set current posn to EOL
	CMP AH, byte [LINLEN]
	JNB	LAPPN2 ; If end of window, advance cursor posn here
	JMP	WCSADV ; Use logical cursor advance(advances LSTPOS)
;This will set the cursor posn one beyond end(wrap next char typed)
LAPPN2:	INC	DH
	RET
;Carriage return
;
LCARET:
	CALL	SCNRDT
	JB	LCRET1 ; BRIF this line already EOL terminated
	JZ	LCRET0 ; BRIF LF terminated
	CMP	AL,TRMNWP
	JNZ	LCRET1 ; BRIF not NULL_WRAP terminated
LCRET0:	DEC	AH ; Do not include LF or NULL_WRAP in line
LCRET1:	MOV	AL,TRMEOL
	CALL	SCNWTT ; Make this line EOL terminated
	MOV DH, byte [WDOLFT] ; And move posn to left margin
	RET
;Line feed
;
LFEED:	MOV	SI,0o0
	TEST byte [F_CRET], 0o377
	JZ	LFD90I ; BRIF LF following CR
	TEST byte [F_INST], 0o377
	JZ	LFED30 ; BRIF not insert mode
	CALL	SCNRTL
	CMP	AH,DH
	JB	LFED30 ; Inserting beyond end of physical(just append)
;Insert mode, move characters from cursor to EOL onto the next line
	CMP DL, byte [LSTLIN]
	JZ	CBEPI2 ; BRIF on LSTPOS line, can't do insert LF
; IMPROVEMENT: Find last physical in this logical and see if it can be moved
;   down one line. If not, abort before any inserts
LFED10:
	CLC ; Indicate call is from Screen Editor
	CALL	SCRINP
	MOV	SI,AX ; Save first char in SI
	MOV	AX," "
	CALL	SCROUT
	PUSH	DX
LFED12:	MOV	CH,0o1
	CALL	MKRMCH ; Move everything over one
	INC	DH
	CMP DH, byte [LINLEN]
	JBE	LFED12 ; Keep going until the end of the line
	MOV	AH,DL
	POP	DX ; Restore posn
	MOV	DL,AH
	CALL	PLINIT ; Terminate line at current posn
	CMP DL, byte [WDOBOT]
	JNZ	LFED43 ; Change terminator to LF and goto next line
	JMP	LFEEDX
;No room!!
CBEEPI:	POPF ; Clean stack
CBEPI2:	JMP	CBEEP
LFD90I:	JMP	LFED90 ; Indirect jump to LFED90
;Insert beyond end of physical=append
; Append LF to end of physical line
LFED30:	CALL	SCNRTL
	PUSHF
	JB	LFED31 ; BRIF need one more space to output LF
	JZ	LFED32 ; BRIF already LF terminated, don't need space
LFED31:	INC	AH ; Need one more space at terminator posn
LFED32:	CMP AH, byte [LINLEN]
	JBE	LFED40 ; BRIF have room on this line
	CALL	LFWRAP ; Wrap linefeed to next line
	JB	LFED69 ; BRIF no room
;The possibilities at this point are WRAP or EOL terminated
	POPF
	JNB	LFED34 ; BRIF not EOL term'd(no change to terminator)
	CALL	SCNRDT
	MOV AH, byte [LINLEN] ; EOL terminated, change to WRAP at LINLEN
	MOV	AL,TRMWRP
	CALL	SCNWTT
LFED34:	MOV DH, byte [WDOLFT]
	CMP DL, byte [LSTLIN]
	JNZ	LFED35 ; BRIF not extending LSTPOS
	INC	byte [LSTLIN] ; Move LSTPOS with LF
	MOV byte [LSTCOL], DH
LFED35:	INC	DL ; Move to new line(created by MKRMNL above)
	MOV	AH,DH
	JMP	LFED43
LFED40:	POPF
	JNB	LFED42 ; BRIF not EOL, just change terminator to LF
LFED41:	CALL	MKRMNL ; Open up next line
	JB	LFEEDX ; No room for LF
;SUCCESS: terminate current line with LF
LFED42:	MOV	DH,AH
	MOV	AX," "
	CALL	SCROUT ; Put a blank at terminator posn
LFED43:	CALL	SCNRDT ; Reread terminator in case of MKRMNL scroll up
	MOV	AH,DH
	MOV	AL,TRMLNF
	CALL	SCNWTT ; And terminate line with LF
	CMP DL, byte [LSTLIN]
	JNZ	LFED95 ; BRIF no LSTPOS update
	MOV byte [LSTCOL], 0o0 ; LSTPOS moves to line beyond linefeed
	INC	byte [LSTLIN]
	JMP	LFED95
LFED90:	PUSH	SI
	CALL	MKRMNL ; Open up next line
	POP	SI
	JB	LFEEDX ; No room
LFED95:	CALL	CSRDWN ; Move to next line
	MOV DH, byte [WDOLFT]
	OR	SI,SI
	JZ	LFEEDX
	MOV	AX,SI
	CALL	SCROUT ; Restore first char of insert linefeed
LFEEDX:	CMP DL, byte [WDOBOT]
	JBE	LFEEDZ
	MOV DL, byte [WDOBOT]
LFEEDZ:	RET
;No room for linefeed, terminate this line and exit
LFED69:	POP	AX
	JMP	LFEEDX
; SUBTTL  CONTROL CHARACTER ROUTINES - Insert and MKRMCH
LINSRT:	XOR byte [F_INST], 0o377 ;Toggle insert flag
	RET
;SUBROUTINE MKRMCH              ; This routine opens up space in logical lines
;**                     On entry:   (DH,DL)=posn to open space
;**                                 CH=number of spaces to open(1 or 2)
;**                     On exit:    (DH,DL)=same posn(DL value can change)
;**
extern BUF
MKRMCH:	PUSH	SI
	PUSH	AX
	PUSH	CX
	PUSH	DX
	MOV	SI,BUF
	MOV	DI,BUF+128 ; SI and DI are overflow character buffers
	CALL	SCNRDT
	PUSHF
	PUSH	AX
	CALL	MVCHLN ; Move characters over put overflow at [DI]
	XOR	CL,CL ; CL=Iteration depth(and count of physical lines)
MKRMC0:	OR	CH,CH
	JNZ	MKRMC1 ; BRIF line overflowed
	POP	AX
	POPF
MKRMCX:	ADD	CL,DL ; CL=original line number
	POP	DX ; DH=orginal column
	MOV	DL,CL ; DL=original line number
MKRMX2:	POP	CX
	POP	AX
	POP	SI
	RET
;Line overflow we must wrap char to next line
MKRMC1:	POP	AX
	POPF ; Get back old terminator
	JB	MKRMC3 ; BRIF was EOL term'd
	JNZ	MKRMC4 ; BRIF was WRAP or NULL_WRAP term'd
;Linefeed, make room for linefeed on next line
	PUSH	AX
	CALL	LFWRAP
	POP	AX
	JB	MKRMCQ ;  No room, throw away overflow
	DEC	CH
	JZ	MKRMCX ; Only wrapped the linefeed, done
	JMP	MKRMC4 ; Pass overflow to next line
;EOL terminatedd
MKRMC3:	PUSH	AX
	CALL	MKRMNL ; Open up next line for overflow
	POP	AX
	JNB	MKRMC4 ; BRIF room, wrap overflow
;No room for wrap, terminate this line with EOL and exit
MKRMCQ:	CALL	SCNRDT
	MOV	AL,TRMEOL
	CALL	SCNWTT ; No room for overflow, just terminate line
	JMP	MKRMCX
;Insert overflow on next line
MKRMC4:	CMP DL, byte [LSTLIN]
	JNZ	MKRMC6 ; BRIF not on LSTPOS line
;AH=Old terminator posn, CH=Overflow count
	SUB	AH,CH
	CMP	AL,TRMNWP
	JNZ	MKRMC5 ; BRIF wasn't NULL_WRAP, don't adjust posn
	DEC	AH
;AH=First position wrapped - 1
MKRMC5:	CMP AH, byte [LSTCOL]
	JAE	MKRMC6 ; BRIF did not wrap LSTCOL
;Wrapped LSTPOS
	MOV byte [LSTCOL], 0o0 ; Set LSTPOS to start of next line
	INC	byte [LSTLIN]
MKRMC6:	INC	DL ; (DH,DL)=start of next line
	MOV DH, byte [WDOLFT]
	DEC	CL ; Decrement interation counter
	XCHG	SI,DI ; Use other overflow buffer for this line
	CALL	SCNRDT
	PUSHF
	PUSH	AX
	PUSH	CX ; Save char count
	CALL	MVCHLN ; Make room on this line for previous overflow
	MOV	BX,CX ; Save count of overflow
	POP	CX ; Get back overflow count in CH
	PUSH	SI ; Save pointer to characters for insertion
;Loop to output characters which overflowed onto this line from previous line
MKRMC7:	CLD ; Scan forwards
	LODSW ; Get a character
	CALL	SCROUT ; Output it
	INC	DH
	SUB	CH,0o1
	JA	MKRMC7 ; Output the next char
	POP	SI
	MOV	CH,BH ; Restore overflow count for this line
	JMP	MKRMC0 ; Wrap new overflow
;Wrap a linefeed to next line
LFWRAP:	INC	DL
	CALL	MKRMNL
	JB	LFWPEX ;  room, throw away overflow
	PUSH	DX
	CALL	SCRDLN ; Scroll this line down to next
	POP	DX
	CALL	LFTERM ; Make this line LF term'd
	CLC
LFWPEX:	DEC	DL ; Restore original line number
	RET
;SUBROUTINE MVCHLN              ; Open up space in physical line
;**                     On entry:   (DH,DL)=posn to open space at
;**                                 SI=address of buffer to put overflow chars
;**                     On exit:    (DH,DL)=same posn(DL might change if scroll)
;**                                 CH=No. of bytes overflowed
;**                                 BX destroyed
;**
MVC30I:	JMP	MVCH30
;MVC80I: JMP     MVCH80
MVCHLN:	PUSH	DI
	PUSH	CX
	CMP DL, byte [LSTLIN]
	MOV CL, byte [LINLEN]
	JNZ	MVCH00 ; BRIF within logical EOL(unless beyond TERM_POS)
	MOV CL, byte [LSTCOL]
MVCH00:	CALL	SCNRTL ; AX=current physical terminator
	CMP	AH,DH
	JB	MVC30I ; BRIF inserting beyond end of physical
	CMP DL, byte [LSTLIN]
	JNZ	MVCH03
	CMP	CL,AH
	JNB	MVCH03 ; BRIF LSTPOS .GTE. TERM_POSN
	MOV	AH,CL ; Else use LSTPOS as TERM_POSN
;We are inserting before end of physical line and LSTPOS .GTE. TERM_POSN
MVCH03:	PUSH	DX
	PUSH	AX
	ADD	CH,AH ; CH=last column for space needed
	SUB CH, byte [LINLEN]
	JA	MVCH10 ; BRIF overflow
	XOR	BH,BH ; Indicate no overflow
	JMP	MVCH20
;We have overflow bytes to save
MVCH10:	MOV	DH,AH
	SUB	DH,CH
	INC	DH ; DH=column of first overflow to save
	CLC ; Indicate call is from Screen Editor
	CALL	SCRINP ; Read an overflow char
	MOV	BX,CX ; Save overflow count in BH
;Loop to move overflow character to save buffer
MVCH14:	CLD
	STOSW ; Save overflow char
	DEC	CH
	JZ	MVCH20 ; All done with overflow save
	INC	DH
	CLC ; Indicate call is from Screen Editor
	CALL	SCRINP ; Read an overflow char
	JMP	MVCH14 ; And save it
;Move characters in line over
MVCH20:	MOV	CX,BX ; Restore # bytes overflowed to CH
	POP	AX ; AH=term posn
	SUB	AH,CH ; Adjust term posn so move doesn't overflow
	POP	DX ; DH=start column of insert
	POP	BX ; BH=number of bytes to move over
	MOV	CL,BL
	PUSH	CX ; Save overflow count and CL for restore on exit
	MOV	CH,AH ; CH=last column to move
	SUB	CH,DH
	INC	CH ; CH=count of chars from CURPOS to TERMPOS
	PUSHF
	MOV	CL,0o1 ; Move on one line
	MOV	AX,DX ; FROM=CURPOS
	MOV	BL,DL
	ADD	BH,DH ; TO=CURPOS+COUNT
	POPF
	JNZ	MVCH21 ; BRIF count not zero, do move
	MOV	BH,DH ; All characters to move overflowed
	JMP	MVCH22 ; Just update terminator to current posn
MVCH21:	CALL	SCROL2 ; Move over characters
	ADD	BH,CH ; New TERMPOS=TO+number of characters moved
	DEC	BH
MVCH22:	POP	CX ; CH=-(No. of bytes wrapped)
;CH=overflow count, CL=insert count, BH=terminator posn
MVCH23:	CALL	SCNRDT
	JB	MVCH25
	JZ	MVCH25
;We have wrapped chars, terminate either WRAP or NULL_WRAP
MVCH24:	CMP BH, byte [LINLEN]
	MOV	AL,TRMWRP
	JZ	MVCH26
	OR	CH,CH
	JZ	MVCH26
	MOV	AL,TRMNWP ; Null wrap that does not overflow changes to wrap
	MOV BH, byte [LINLEN]
	PUSH	AX
	PUSH	DX
	MOV	DH,BH
	MOV	AX," " ; Blank DBLCHR destroyed by scroll
	CALL	SCROUT
	POP	DX
	POP	AX
	JMP	MVCH26
;Was EOL or LF terminated
MVCH25:	OR	CH,CH
	JNZ	MVCH24 ; Overflow means WRAP or NULL_WRAP
MVCH26:	CMP	AH,BH
	JA	MVCH27 ; Terminator beyond scroll end
	MOV	AH,BH
;AH=New terminator, CL=insert count
	CALL	SCNWTT ; Update terminator
MVCH27:	CMP DL, byte [LSTLIN]
	JNZ	MVCHEX ; BRIF move is not on LSTPOS line
	CMP BH, byte [LSTCOL]
	JBE	MVCHEX ; BRIF end of move is before LSTPOS
	MOV byte [LSTCOL], BH ; Else add number moved over to LSTPOS
MVCHEX:	POP	DI
	RET
;Inserting beyond end of logical
MVCH30:	MOV	CL,CH ; Save insert count in CL
	ADD	CH,DH ; CH=end of insert
	CMP	AL,TRMLNF
	JZ	MVCH31 ; BRIF LF term'd cannot push null off end
	DEC	CH ; Ignore one null push off end of physical
MVCH31:	CMP CH, byte [LINLEN]
	JBE	MVCH33 ; BRIF have room
;No room, return blanks overflow, update terminator
	SUB CH, byte [LINLEN] ; CH=No. of overflow bytes
	MOV	AX," "
	PUSH	CX
MVCH32:	CLD ; Store overflow bytes(All blanks)
	STOSW
	DEC	CH
	JNZ	MVCH32
	POP	CX ; Restore CH=number of overflow bytes
	POP	BX
	MOV	BH,CH
	PUSH	BX ; Put overflow count with original CL on stack
	MOV BH, byte [LINLEN] ; BH=term posn, CH=overflow count, CL=insert count
	JMP	MVCH23 ; Update terminator and LSTPOS, exit
;Have room, just update terminator
MVCH33:	POP	BX
	MOV	BH,0o0 ; Put overflow count(=0) on stack for return
	XCHG	BH,CH ; BH=term posn, CH=overflow count, CL=insert count
	JMP	MVCH23 ; New term posn still .LTE. LINLEN
; COMMENT %
; ;On LSTLIN, possibly insert to LSTPOS or LSTPOS+COUNT
; ;N.B. We are guaranteed to be at a posn to left of TERM_POS
; ;Two cases: insert up to LSTPOS or insert up to LSTPOS+COUNT
; MVCH80: PUSH    DX
; 	PUSH    CX
; 	PUSH    AX
; 	MOVB    CL,AH           ; Save TERM_POS in CL for compare
; 	MOVB    DH,LSTCOL
; ;Scan from LSTPOS+1 to lesser of (LSTPOS+COUNT,TERM_POS) or non-blank character
; MVCH81: INCB    DH              ; Next column
; IFN     IBMLIK,<
; 	CLC                     ; Indicate call is from Screen Editor
; >                               ; IFN IBMLIK
; 	CALL    SCRINP          ; AX=character at this posn
; IFN     DBLCHR,<
; 	JNB     MVCH82          ; BRIF not reading second of double byte char
; 	INCB    DH              ; Restore DH(SCRINP decremented it)
; >                               ; IFN DBLCHR
; MVCH82: CMPI    AX," "
; 	JNZ     MVCH86          ; Found non-blank
; 	CMPB    DH,CL
; 	JAE     MVCH84          ; At TERM_POS
; MVCH83: DECB    CH
; 	JNZ     MVCH81          ; Not at LSTPOS+COUNT, continue scan
; ;Insert to LSTPOS+COUNT [;or TERM_POS+COUNT, whichever is smaller]
; MVCH84: POP     AX
; 	POP     CX
; 	POP     DX
; 	MOVB    AH,LSTCOL       ; Change end of FROM insert window to LSTPOS
; MVCH85: JMP     MVCH03          ; Insert to LSTPOS
; ;Insert to last blank after LSTPOS
; MVCH86: POP     AX              ; AX=current terminators
; 	POP     BX              ; BH=Count desired
; 	MOVB    CH,DH           ; CH=end of TO insert window
; 	DECB    CH
; 	POP     DX              ; (DH,DL)=current posn
; 	ADDB    BH,DH           ; BH=start of TO insert window
; 	SUBB    CH,BH           ; CH=character count to move
; 	JB      MVCH89          ; BRIF at end, just overwrite last char
; 	INCB    CH
; 	MOVBI   CL,1            ; Move on one line
; 	MOVB    BL,DL           ; (BH,BL)=start of TO window
; 	MOV     AX,DX           ; (AH,AL)=start of FROM window
; IFN     DBLCHR,<
; 	PUSH    DX
; 	PUSH    AX
; 	MOV     DX,AX
; 	ADDB    DH,CH
; IFN     IBMLIK,<
; 	CLC                     ; Indicate call is from Screen Editor
; >                               ; IFN IBMLIK
; 	CALL    SCRINP          ; Are we going to scroll half of a double byte char?
; 	MOVI    AX," "
; 	JNB     MVCH88
; 	INCB    DH
; MVCH88: CALL    SCROUT          ; Obliterate double byte char scrolled on top of
; 	POP     AX
; 	POP     DX
; >                               ; IFN DBLCHR
; 	CALL    SCROL2          ; Move characters over
; MVCH89: POP     CX
; 	XORB    CH,CH           ; No characters wrapped
; 	JMP     MVCHEX          ; All done
;SUBROUTINE SCROL2              ; Used by insert code to move over chars in line
;                           On entry:   AH,BH,CH=scroll parameters
;
SCROL2 equ SCROLL ; No DBLCHR save/restore
;SUBROUTINE SCNRTL              ; Read logical terminator for physical line
;**                     On entry:   DL=line number
;**                     On exit:    AX=terminators
;**                                 CF set indicates EOL terminator
;**                                 CF clear, ZF set indicates LF terminator
;**                                 If NULL_WRAP terminator AH=TERM_POS-1
SCNRTL:	CALL	SCNRDT ; Get terminators
	JB	SCNRT2 ; BRIF not NULL_WRAP
	JZ	SCNRT2 ; BRIF not NULL_WRAP
	PUSHF
	CMP	AL,TRMNWP
	JNZ	SCNRT1 ; BRIF not NULL_WRAP
	DEC	AH ; Is NULL_WRAP, decrement posn
SCNRT1:	POPF
SCNRT2:	RET
;Wrap a linefeed(already a successful MKRMNL)
LFTERM:	PUSH	word [TRMCUR]
	PUSH	AX
	CALL	SCNRDT ; Read next line terminator
	MOV	AL,TRMLNF
	MOV AH, byte [WDOLFT]
	CALL	SCNWTT ; Write out LF terminator at left margin plus one
	POP	AX
	POP	word [TRMCUR]
	RET
; SUBTTL CURSOR MOVEMENT within window
;       These routines return CF=1 when they do not change the posn.
;
;Cursor right within window(or within physical line if outside window)
CSRADV:	INC	DH ; Next column
	CMP byte [LINLEN], DH
	JAE	CSRRET ; BRIF Good value
	DEC	DH
	CALL	CSRDWN
	JB	CSRRET ; BRIF can't change physical lines
	MOV DH, byte [WDOLFT] ; First column
CSRRET:	RET
;Cursor left within window(or within physical line if outside window)
CSRREG:	DEC	DH ; Previous column
	CMP DH, byte [WDOLFT]
	JNB	CSRRET ; BRIF good value
	INC	DH ; Restore column
	CALL	CSRUP
	JB	CSRRET ; BRIF can't change physical lines
	MOV DH, byte [LINLEN] ; Last column
	RET
;Cursor up within window(or NOP if outside window)
CSRUP:	CMP byte [WDOBOT], DL
	JB	CSRRET ; BRIF outside of window
	CMP DL, byte [WDOTOP]
	JB	CSRRET
	STC
	JZ	CSRRET ; BRIF at top or outside of window
	CLC
	DEC	DL
	RET
;Cursor down within window(or NOP if outside window)
CSRDWN:	CMP DL, byte [WDOTOP]
	JB	CSRRET ; BRIF outside window
	CMP byte [WDOBOT], DL
	JB	CSRRET ; BRIF at bottom or outside of window
	STC
	JZ	CSRRET
	CLC
	INC	DL ; Next line
	RET
; SUBTTL CURSOR MOVEMENT within logical line
;Cursor advance within logical line
;                   on entry:   DH=current column, DL=current line
;                   on exit:    If CF clear, DH=new column, DL=new line
;                                   Else DH=EOL column, DL=EOL line
;                                   ZF=1 if stop at LSTPOS
;                               AH=terminator column, AL=terminator value
;
LCSADV:	CMP DL, byte [LSTLIN]
	JNZ	LCSAD0 ; BRIF not at LSTPOS
	CMP DH, byte [LSTCOL]
	JB	LCSAD0 ; BRIF not at LSTPOS
	CALL	SCNRDT
	CMP	AH,AH ; Set ZF=1 if stop at LSTPOS
	STC
LCSADX:	RET
LCSAD0:	CALL	SCNRDT
	JB	LCSAD2 ; BRIF at last line
LCSAD1:	CALL	CSRADV
	JB	LCSADA ; BRIF at end of window
	CMP	AH,DH
	JNB	LCSADX ; BRIF within logical line
	INC	DL
	MOV DH, byte [WDOLFT] ; Else wrap to next physical of logical
	CLC
	RET
LCSAD2:	CMP	AH,DH
	JA	LCSAD1 ; BRIF not at EOL or beyond
LCSADA:	OR	DH,DH ; ZF=1(not stop at LSTPOS)
	STC
	RET
;Cursor regress within logical line
;                   on entry:   DH=current column, DL=current line
;                   on exit:    If CF clear, DH=new column, DL=new line
;                                   Else DH=EOL column, DL=EOL line
;                                   If stop at FSTPOS, ZF is set
;
LCSREG:	CMP DL, byte [FSTLIN]
	JNZ	LCSRG0 ; BRIF not at FSTPOS
	CMP DH, byte [FSTCOL]
	JA	LCSRG0 ; BRIF not at FSTPOS
	STC
	RET ; ZF=1, CF=1, stop at FSTPOS
LCSRG0:	PUSH	BX
	MOV	BX,DX
	CALL	CSRREG
	JB	LCSRGA ; BRIF at top of window
	CMP	BL,DL
	JZ	LCSRGX ; BRIF on same line, must be good posn
	CALL	SCNRDT
	JNB	LCSRGX ; BRIF still on same logical line
	MOV	DL,BL ; Move back to line we were on
	MOV DH, byte [WDOLFT] ; And posn at start of that line
LCSRGA:	OR	DH,DH ; ZF=0(not stop at FSTPOS)
	STC
LCSRGX:	POP	BX
	RET ; Return CF set(at EOL)
LSTART:
LSTRT0:	CMP DL, byte [FSTLIN]
	JZ	LSTRT1
	CALL	CSRUP
	JB	LSTRT1 ; Top of window must be start of line
	CALL	SCNRDT
	JNB	LSTRT0 ; BRIF this line is part of logical
	INC	DL
LSTRT1:	MOV DH, byte [WDOLFT]
	JB	LSTRTX ; BRIF not using FSTPOS, use left margin
	MOV DH, byte [FSTCOL]
LSTRTX:	RET
; SUBTTL  MISCELLANEOUS ROUTINES
;*********************************************************
;CHECK FOR WORD OR NON-WORD CHAR(ALPHA NUMERIC)
;
ANCHK:	PUSH	DX
	CLC ; Indicate call is from Screen Editor
	CALL	SCRINP ; Read character at current posn in DX
	JNB	ANCH0 ; BRIF DH was not decremented
	INC	DH
ANCH0:	OR	AH,AH
	JNZ	ANCNO ; BRIF is two-byte character - reject
	CMP	AL,0o60
	JB	ANCNO ; BRIF is not alpha-numeric
	CMP	AL,0o72
	JB	ANYES ; BRIF is numeric
	CMP	AL,0o101
	JB	ANCNO ; BRIF is not alpha-numeric
	CMP	AL,0o133
	JB	ANYES ; BRIF is alpha
	CMP	AL,0o141
	JB	ANCNO ; BRIF is not alpha-numeric
	CMP	AL,0o173
	JB	ANYES ; BRIF is small alpha
ANCNO:	STC
	POP	DX
	RET
ANYES:	CLC
	POP	DX
	RET
