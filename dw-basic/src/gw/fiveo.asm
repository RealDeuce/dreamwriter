; Auto-converted mechanically from ../gw-basic/fiveo.asm
; Edit the converter or the generated source deliberately; do not hand-wave syntax changes.

; [ This translation created 10-Feb-83 by Version 4.3 ]
; .RADIX  8
%include "dwoem.inc"
; TITLE FIVEO 5.0 Features -WHILE/WEND, CALL, CHAIN, WRITE /P. Allen
; .RADIX	10
%assign TSHIBA 0
%assign PC8A 0
%define LABEL PC8A
%assign OKI 0
%include "gio86u.inc"
%include "msdosu.inc"
%if CPM86
; TODO include CPM86U
%endif
extern RESTORE
extern SUBFLG
extern TEMP
; Code Segment ( terminated by END at bottom of file )
extern CHRGTR
extern SYNCHR
extern DCOMPR
extern GETYPR
extern SNERR
extern GETSTK
extern PTRGET
extern CRDO
extern VMOVFM
extern FRQINT
; SUBTTL  WHILE , WEND
global WHILE
global WEND
extern ERROR
extern FRMCHK
extern WNDSCN
extern FRMEVL
extern NEWSTT
extern FORSZC
extern SAVSTK
extern NXTLIN
extern CURLIN
extern ENDFOR
;
; THIS CODE HANDLES THE STATEMENTS WHILE/WEND
; THE 8080 STACK IS USED TO PUT AN ENTRY ON FOR EACH ACTIVE WHILE
; THE SAME WAY ACTIVE GOSUB AND FOR ENTRIES ARE MADE.
; THE FORMAT IS AS FOLLOWS:
;       $WHILE - THE TOKEN IDENTIFYING THE ENTRY (1 BYTE)
;       A TEXT POINTER AT THE CHARACTER AFTER THE WEND OF THE WHILE BODY (2 BYTES)
;       A TEXT POINTER AT THE CHARACTER AFTER THE WHILE OF THE WHILE BODY (2 BYTES)
;       THE LINE NUMBER OF THE LINE THAT THE WHILE IS ON (2 BYTES)
;
;       TOTAL   7 BYTES
;
WHILE: ;KEEP THE WHILE TEXT POINTER HERE
	MOV	[ENDFOR],BX ;SAVE TEXT ADDRESS
	CALL	WNDSCN ;SCAN FOR THE MATCHING WEND
;CAUSE AN ERRWH IF NO WEND TO MATCH
	CALL	CHRGTR ;POINT AT CHARACTWER AFTER WEND
	XCHG	BX,DX ;POSITION OF MATCHING WEND
	CALL	FNDWND ;SEE IF THERE IS A STACK ENTRY FOR THIS WHILE
	LAHF
	INC	SP ;GET RID OF THE NEWSTT ADDRESS ON THE STACK
	SAHF
	LAHF
	INC	SP
	SAHF
	JNZ	WNOTOL ;IF NO MATCH NO NEED TO TRUNCATE THE STACK
	ADD	BX,CX ;ELIMINATE EVERYTHING UP TO AND INCLUDING
;THE MATCHING WHILE ENTRY
	MOV	SP,BX
	MOV	[SAVSTK],BX
WNOTOL:	MOV	BX,CURLIN ;MAKE THE STACK ENTRY
	PUSH	BX
	MOV	BX,ENDFOR ;GET TEXT POINTER FOR WHILE BACK
	PUSH	BX
	PUSH	DX ;SAVE THE WEND TEXT POINTER
	JMP	FNWEND ;FINISH USING WEND CODE
WEND:	JZ	??L000
	JMP	SNERR ;STATEMENT HAS NO ARGUMENTS
??L000:
	XCHG	BX,DX ;FIND MATCHING WHILE ENTRY ON STACK
	CALL	FNDWND
	JNZ	WEERR ;MUST MATCH OR ELSE ERROR
	MOV	SP,BX ;TRUNCATE STACK AT MATCH POINT
	MOV	[SAVSTK],BX ;[H,L] POINTING INTO STACK ENTRY
	MOV	DX,CURLIN ;REMEMBER WEND LINE #
	MOV	[NXTLIN],DX ;IN NXTLIN
	INC	BX ;INDEX INTO STACK ENTRY TO GET VALUES
	INC	BX ;SKIP OVER TEXT POINTER OF WEND
	MOV	DX,[BX] ;SET [D,E]=TEXT POINTER OF WHILE
	INC	BX
	INC	BX
	MOV	BX,[BX] ;[H,L]=LINE NUMBER OF WHILE
	MOV	[CURLIN],BX ;IN CASE OF ERROR OR CONTINUATION FIX CURLIN
	XCHG	BX,DX ;GET TEXT POINTER OF WHILE FORMULA INTO [H,L]
FNWEND:	CALL	FRMEVL ;EVALUATE FORMULA
extern VSIGN
	PUSH	BX ;SAVE TEXT POINTER
	CALL	VSIGN ;GET IF TRUE OR FALSE
	POP	BX ;GET BACK WHILE TEXT POINTER
	JZ	FLSWHL ;GO BACK AT WEND IF FALSE
	MOV	CX,TOK_WHILE ;COMPLETE WHILE ENTRY
	MOV	CH,CL ;NEED IT IN THE HIGH BYTE
	PUSH	CX
	JMP	NEWSTT
FLSWHL:	MOV	BX,NXTLIN ;SETUP CURLIN FOR WEND
	MOV	[CURLIN],BX
	POP	BX ;TAKE OFF TEXT OF WEND AS NEW TEXT POINTER
	POP	CX ;GET RID OF TEXT POINTER OF WHILE
	POP	CX ;TAKE OFF LINE NUMBER OF WHILE
	JMP	NEWSTT
;
; THIS SUBROUTINE SEARCHES THE STACK FOR AN WHILE ENTRY
; WHOSE WEND TEXT POINTER MATCHES [D,E]. IT RETURNS WITH ZERO TRUE
; IF A MATCH IS FOUND AND ZERO FALSE OTHERWISE. FOR ENTRIES
; ARE SKIPPED OVER, BUT GOSUB ENTRIES ARE NOT.
;
%assign WHLSIZ 7
;
; Note - 8086 versions force stack entries to be an even length
; so stack accesses won't cross word boundaries.  This is done
; for speed.  To accomplish this, an extra byte is pushed on
; top of the WHILE token.  This extra byte is NOT reflected in
; the value of WHLSIZ but is taken care of by the code.
;
FNDWND:	MOV	BX,4 ;SKIP OVER RETURN ADDRESS AND NEWSTT
	ADD	BX,SP
FNDWN2:
	INC	BX
	MOV	AL,byte [BX] ;GET THE ENTRY TYPE
	INC	BX
	MOV	CX,TOK_FOR
	CMP	AL,CL ;SEE IF ITS $FOR
	JNZ	FNDWN3
	MOV	CX,FORSZC-1 ;Yes, so skip over it.  Note that
	ADD	BX,CX ;the pointer has already been
	JMP	FNDWN2 ;incremented once.
FNDWN3:	MOV	CX,TOK_WHILE
	CMP	AL,CL
	JZ	$+3
	RET
db 0o71, 0o27 ;CMP [BX],DX-SAME WEND?
	MOV	CX,WHLSIZ-1 ;Note that the pointer has
;already been incremented once.
	JNZ	$+3
	RET ;RETURN IF ENTRY MATCHES
	ADD	BX,CX
	JMP	FNDWN2
WEERR:	MOV	DX,ERRC_ERRWE
	JMP	ERROR
; SUBTTL  CHAIN
extern TXTTAB
extern VALTYP
extern FRMEVL
extern OMERR
extern SCRTCH
extern LINGET
global CHAIN
global BASIC_COMMON
extern PTRGTN
extern PTRGTR
extern MOVE1
extern NEWSTT
extern PTRGET
extern STRCPY
extern GARBA2
extern FRETOP
;
;
extern SAVFRE
extern IADAHL
extern TEMP3
extern TEMP9
extern VARTAB
extern ARYTAB
extern CHNFLG
extern STREND
extern CURLIN
extern SAVSTK
extern ENDBUF
extern MRGFLG
extern MDLFLG
extern CHNLIN
extern CMEPTR
extern CMSPTR
extern BLTUC
extern DATA
extern FNDLIN
extern USERR
extern ERSFIN
extern FCERR
extern NOARYS
extern DEL
extern LINKER
extern SCNLIN
extern FRQINT
; This is the code for the CHAIN statement
; The syntax is:
; CHAIN [MERGE]<file name>[,[<line number>][,ALL][,DELETE <range>]]
; The steps required to execute a CHAIN are:
;
; 1.) Scan arguments
;
; 2.) Scan program for all COMMON statements and
;       mark specified variables.
;
; 3.) Squeeze unmarked entries from symbol table.
;
; 4.) Copy string literals to string space
;
; 5.) Move all simple variables and arrays into the
;       bottom of string space.
;
; 6.) Load new program
;
; 7.) Move variables back down positioned after program.
;
; 8.) Run program
CHAIN:
	XOR	AL,AL ;Assume no MERGE
	MOV	byte [MRGFLG],AL
	MOV	byte [MDLFLG],AL ;Also no MERGE w/ DELETE option
extern OPTFLG
extern TOPTFG
extern OPTVAL
extern TOPTVL
	MOV	AL,byte [OPTFLG]
	MOV	byte [TOPTFG],AL ;SAVE OPTION BASE VALUE
	MOV	AL,byte [OPTVAL] ;SAVE OPTION VALUE FOR ARRAY BASE
	MOV	byte [TOPTVL],AL
	MOV	AL,byte [BX] ;Get current char
	MOV	DX,TOK_MERGE ;Is it MERGE?
	CMP	AL,DL ;Test
	JNZ	NTCHNM ;NO
	MOV	byte [MRGFLG],AL ;Set MERGE flag
	INC	BX
NTCHNM:	DEC	BX ;Rescan file name
	CALL	CHRGTR
extern PRGFLI
	CALL	PRGFLI ;Evaluate file name and OPEN it
	PUSH	BX ;Save text pointer
	MOV	BX,0 ;Get zero
	MOV	[CHNLIN],BX ;Assume no CHAIN line #
	POP	BX ;Restore text pointer
	DEC	BX ;Back up pointer
	CALL	CHRGTR ;Scan char
	JNZ	??L001
	JMP	NTCHAL ;No line number etc.
??L001:
	CALL	SYNCHR
db 0o54 ;Must be comma
	CMP	AL,0o54 ;Ommit line # (Use ALL for instance)
	JZ	NTLINF ;YES
	CALL	FRMEVL ;Evaluate line # formula
	PUSH	BX ;Save text poiner
	CALL	FRQINT ;Force to int in [H,L]
	MOV	[CHNLIN],BX ;Save it for later
	POP	BX ;Restore text poiner
	DEC	BX ;Rescan last char
	CALL	CHRGTR
	JZ	NTCHAL ;No ALL i.e. preserve all vars across CHAIN
NTLINF:	CALL	SYNCHR
db 0o54 ;Should be comma here
	MOV	DX,TOK_DELETE ;Test for DELETE option
	CMP	AL,DL ;Is it?
	JZ	CHMWDL ;Yes
	CALL	SYNCHR
db "A" ;Check for "ALL"
	CALL	SYNCHR
db "L"
	CALL	SYNCHR
db "L"
	JNZ	??L002
	JMP	DNCMDA ;Goto step 3
??L002:
	CALL	SYNCHR
db 0o54 ;Force comma to appear
	CMP	AL,DL ;Must be DELETE
	JZ	??L003
	JMP	SNERR ;No, give error
??L003:
	OR	AL,AL ;Flag to goto DNCMDA
CHMWDL:	PUSHF ;Save ALL flag
	MOV	byte [MDLFLG],AL ;Set MERGE w/ DELETE
	CALL	CHRGTR ;Get char after comma
	CALL	SCNLIN ;Scan line range
extern DEPTR
	PUSH	CX
	CALL	DEPTR ;Change pointers back to numbers
	POP	CX
	POP	DX ;Pop max line off stack
	PUSH	CX ;Save pointer to start of 1st line
	MOV	BX,CX ;Save pointer to start line
	MOV	[CMSPTR],BX
	CALL	FNDLIN ;Find the last line
	JAE	FCERRG ;Must have exact match on end of range
	MOV	DH,BH ;[D,E] =  pointer at the start of the line
	MOV	DL,BL ;beyond the last line in the range
	MOV	[CMEPTR],BX ;Save pointer to end line
	POP	BX ;Get back pointer to start of range
	CMP	BX,DX ;Make sure the start comes before the end
FCERRG:	JNAE	??L004
	JMP	FCERR ;If not, "Illegal function call"
??L004:
	POPF ;Flag that says whether to go to DNCMDA
	JZ	??L005
	JMP	DNCMDA ;"ALL" option was present
??L005:
NTCHAL:	MOV	BX,CURLIN ;Save current line number on stack
	PUSH	BX
	MOV	BX,TXTTAB ;Start searching for COMMONs at program start
	DEC	BX ;Compensate for next instr
CLPSC1:	INC	BX ;Look at first char of next line
CLPSCN:	MOV	AL,byte [BX] ;Get char from program
	INC	BX
	OR	AL,byte [BX] ;Are we pointing to program end?
	JNZ	??L006
	JMP	CLPFIN ;Yes
??L006:
	INC	BX
	MOV	DX,[BX] ;Get line # in [D,E]
	INC	BX
	MOV	[CURLIN],DX ;Save current line # in CURLIN for errors
CSTSCN:	CALL	CHRGTR ;Get statment type
AFTCOM:	OR	AL,AL
	JZ	CLPSC1 ;EOL Scan next one
	CMP	AL,":" ;Are we looking at colon
	JZ	CSTSCN ;Yes, get next statement
	CMP	AL,254 ;COMMONs prceeded by 254
	JNZ	NOCOMM ;not one
	INC	BX ;move ahead
	MOV	AL,byte [BX]
	MOV	DX,TOK_COMMON ;Test for COMMON, avoid byte externals
	CMP	AL,DL ;Is it a COMMON?
	JZ	DOCOMM ;Yes, handle it
	DEC	BX ;Back up the pointer.
NOCOMM:	CALL	CHRGTR ;Get first char of statement
	CALL	DATA ;Skip over statement
	DEC	BX ;Back up to rescan terminator
	JMP	CSTSCN ;Scan next one
DOCOMM:	CALL	CHRGTR ;Get thing after COMMON
	JZ	AFTCOM ;Get next thing
NXTCOM:	PUSH	BX ;Save text pointer
	MOV	AL,1 ;Call PTRGET to search for array
	MOV	byte [SUBFLG],AL
	CALL	PTRGTN ;This subroutine in F3 scans variables
	JZ	FNDAAY ;Found array
	MOV	AL,CH ;Try finding array with COMMON bit set
	OR	AL,128
	MOV	CH,AL
	XOR	AL,AL ;Set zero CC
	CALL	ERSFIN ;Search array table
	MOV	AL,0 ;Clear SUBFLG in all cases
	MOV	byte [SUBFLG],AL
	JNZ	NTFN2T ;Not found, try simple
	MOV	AL,byte [BX] ;Get terminator, should be "("
	CMP	AL,"(" ;Test
	JNZ	SCNSMP ;Must be simple then
	POPF ;Get rid of saved text pointer
	JMP	COMADY ;Already was COMMON, ignore it
NTFN2T:	MOV	AL,byte [BX] ;Get terminator
	CMP	AL,"(" ;Array specifier?
	POP	DX ;(DE:=saved text pointer.)
	JZ	SKPCOM ;Yes, undefined array - just skip it.
	PUSH	DX ;No, resave pointer to start of variable
SCNSMP:	POP	BX ;Rescan variable name for start
	CALL	PTRGTN ;Evaluate as simple
	OR	DX,DX ;If var not found, [D,E]=0
	JNZ	COMFNS ;Found it
	MOV	AL,CH ;Try to find in COMMON
	OR	AL,128 ;Set COMMON bit
	MOV	CH,AL
	MOV	DX,COMPT2 ;push on return address
	PUSH	DX
	MOV	DX,PTRGTR ;address to common return point
	PUSH	DX
	MOV	AL,byte [VALTYP] ;Must have VALTYP in [D]
	MOV	DH,AL
	JMP	NOARYS ;Search symbol table
COMPT2:	OR	DX,DX ;Found?
	JZ	SKPCOM ;No, just skip over this variable.
COMFNS:	PUSH	BX ;Save text pointer
	MOV	CH,DH ;Get pointer to var in [B,C]
	MOV	CL,DL
	MOV	BX,BCKUCM ;Loop back here
	PUSH	BX
CBAKBL:	DEC	CX ;Point at first char of rest
LPBKNC:	MOV	SI,CX
	MOV	AL,[SI] ;Back up until plus byte
	DEC	CX
	OR	AL,AL
	JNS	??L007
	JMP	LPBKNC
??L007:
;Now point to 2nd char of var name
	MOV	SI,CX
	MOV	AL,[SI] ;set COMMON bit
	OR	AL,128
	MOV	DI,CX
	STOSB
	RET ;done
FNDAAY:	MOV	byte [SUBFLG],AL ;Array found, clear SUBFLG
	MOV	AL,byte [BX] ;Make sure really array spec
	CMP	AL,"(" ;Really an array?
	JNZ	SCNSMP ;No, scan as simp
	POP	SI ;XTHL
	XCHG	SI,BX
	PUSH	SI ;Save text pointer, get rid of saved text pointer
BAKCOM:	DEC	CX ;Point at last char of name extension
	DEC	CX
	CALL	CBAKBL ;Back up before variable and mark as COMMON
BCKUCM:	POP	BX ;Restore text pointer
SKPCOM:	DEC	BX ;Rescan terminator
	CALL	CHRGTR
	JNZ	??L008
	JMP	AFTCOM ;End of COMMON statement
??L008:
	CMP	AL,"(" ;End of COMMON array spec?
	JNZ	CHKCST ;No, should be comma
COMADY:	PUSH	BX
	CALL	CHRGTR ;Fetch char after paren
	CMP	AL,")"
	JZ	COMRPN ;Only right paren follows
	POP	BX
extern EVAL
	CALL	EVAL ;Possible number of dimensions(compiler compatible)
	CALL	GETYPR
	JNZ	??L009
	JMP	FCERR ;Dimensions argument cannot be string
??L009:
	JMP	COMRP1
COMRPN:	POP	DX
COMRP1:	CALL	SYNCHR
db ")" ;Right paren should follow
	JNZ	??L010
	JMP	AFTCOM ;End of COMMON
??L010:
CHKCST:	CALL	SYNCHR
db 0o54 ;Force comma to appear here
	JMP	NXTCOM ;Get next COMMON variable
; Step 3 - Squeeze..
CLPFIN:	POP	BX ;Restore previous CURLIN
	MOV	[CURLIN],BX
	MOV	DX,ARYTAB ;End of simple var squeeze to [D,E]
	MOV	BX,VARTAB ;Start of simps
CLPSLP:	CMP	BX,DX ;Are we done?
	JZ	DNCMDS ;Yes done, with simps
	PUSH	BX ;Save where this simp is
	MOV	CL,byte [BX] ;Get VALTYP
	INC	BX
	INC	BX
	MOV	AL,byte [BX] ;Get COMMON bit
	OR	AL,AL ;Set minus if COMMON
	PUSHF ;Save indicator
	AND	AL,0o177 ;Clear COMMON bit
	MOV	byte [BX],AL ;Save back
	INC	BX
	CALL	IADAHL ;Skip over rest of var name
	MOV	CH,0 ;Skip VALTYP bytes
	ADD	BX,CX
	POPF ;Get indicator whether to delete
	POP	CX ;Pointer to where var started
	JNS	??L011
	JMP	CLPSLP
??L011:
	PUSH	CX ;This is where we will resume scanning vars later
	CALL	VARDLS ;Delete variable
	MOV	BX,ARYTAB ;Now correct ARYTAB by # of bytes deleted
	ADD	BX,DX ;Add negative difference between old and new
	MOV	[ARYTAB],BX ;Save new ARYTAB
	XCHG	BX,DX ;To [D,E]
	POP	BX ;Get current place back in [H,L]
	JMP	CLPSLP
VARDLS:	XCHG	BX,DX ;Point to where var ends
VARDL1:	MOV	BX,STREND ;One beyond last byte to move
DLSVLP:	CMP	BX,DX ;Done?
	MOV	SI,DX
	MOV	AL,[SI] ;Grab byte
	MOV	DI,CX
	STOSB ;Move down
	LAHF
	INC	DX ;Increment pointers
	SAHF
	LAHF
	INC	CX
	SAHF
	JNZ	DLSVLP
	MOV	AL,CL ;Get difference between old and new
	SUB	AL,BL ;Into [D,E] ([D,E]=[B,C]-[H,L])
	MOV	DL,AL
	MOV	AL,CH
	SBB	AL,BH
	MOV	DH,AL
	DEC	DX ;Correct # of bytes
	DEC	CX ;Moved one too far
	MOV	BX,CX ;Get new STREND [H,L]
	MOV	[STREND],BX ;Store it
	RET
DNCMDS:	MOV	DX,STREND ;Limit of array search
CLPAKP:	CMP	BX,DX ;Done?
	JZ	DNCMDA ;Yes
	PUSH	BX ;Save pointer to VALTYP
	INC	BX ;Move down to COMMON bit
	INC	BX
	MOV	AL,byte [BX] ;Get it
	OR	AL,AL ;Set CC's
	PUSHF ;Save COMMON indicator
	AND	AL,0o177 ;Clear COMMON bit
	MOV	byte [BX],AL ;Save back
	INC	BX ;Point to length of array
	CALL	IADAHL ;Add length of var name
	MOV	CL,byte [BX] ;Get length of array in [B,C]
	INC	BX
	MOV	CH,byte [BX]
	INC	BX
	ADD	BX,CX ;[H,L] now points after array
	POPF ;Get back COMMON indicator
	POP	CX ;Get pointer to start of array
	JNS	??L012
	JMP	CLPAKP ;COMMON, dont delete!
??L012:
	PUSH	CX ;Save so we can resume
	CALL	VARDLS ;Delete the array
	XCHG	BX,DX ;Returns with STREND in HL, so put in DE
	POP	BX ;Get back pointer to the next array
	JMP	CLPAKP ;Check next array
; Step 4 - Copy literals into string space
; This code is very similar to the string garbage collect code
; If BIGSTR is on, we also have to fix up the string back pointers.
DNCMDA:
	MOV	BX,VARTAB ;Look at simple strings
CSVAR:	MOV	DX,ARYTAB ;Limit of search to [D,E]
	CMP	BX,DX ;Done?
	JZ	CAYVAR ;Yes
	CALL	SKPNAM ;Skip name, returns Z if was a string
	JNZ	CSKPVA ;Skip this var, not string
	CALL	CDVARS ;Copy this guy into string space if nesc
	XOR	AL,AL ;CDVARS has already incremented [H,L]
CSKPVA:
	MOV	DL,AL
	MOV	DH,0 ;Add length of VALTYP
	ADD	BX,DX
	JMP	CSVAR
CAYVA2:	POP	CX ;Adjust stack
CAYVAR:	MOV	DX,STREND ;New limit of search
	CMP	BX,DX ;Done?
	JZ	DNCCLS ;Yes
	CALL	SKPNAM ;Skip over name
	PUSH	AX ;Save VALTYP
	MOV	CL,byte [BX] ;Get length of array
	INC	BX
	MOV	CH,byte [BX] ;Into [B,C]
	INC	BX
	POP	AX ;Get back VALTYP
	PUSH	BX ;Save pointer to array element
	ADD	BX,CX ;Point after array
	CMP	AL,3 ;String array?
	JNZ	CAYVA2 ;No, look at next one
	MOV	[TEMP3],BX ;Save pointer to end of array
	POP	BX ;Get back pointer to array start
	MOV	CL,byte [BX] ;Pick up number of DIMs
	MOV	CH,0 ;Make double with high zero
	ADD	BX,CX ;Go past DIMS
	ADD	BX,CX
	INC	BX ;One more to account for # of DIMs
CAYSTR:	MOV	DX,TEMP3 ;Get end of array
	CMP	BX,DX ;See if at end of array
	JZ	CAYVAR ;Get next array
	MOV	CX,CAYSTR ;Do next str in array
	PUSH	CX ;Save branch address on stack
CDVARS:
	MOV	AL,byte [BX] ;Get length of array entry
	INC	BX ;Also pick up pointer into [D,E]
	MOV	DX,[BX] ;Get data pointer
	INC	BX
	INC	BX
	OR	AL,AL ;Set CC's on length
	JNZ	$+3
	RET ;Ignore null strings
	PUSH	BX ;Save where we are
	MOV	BX,VARTAB ;Is string in program text or disk buffers?
	CMP	BX,DX ;Compare
	POP	BX ;Restore where we are
	JNB	$+3
	RET ;No, must be in string space
	PUSH	BX ;save where we are again.
	MOV	BX,TXTTAB ;is it in buffers?
	CMP	BX,DX ;test
	POP	BX ;Restore where we are
	JNAE	$+3
	RET ;in buffers, do nothing
	PUSH	BX ;Save where we are for nth time
	DEC	BX ;Point to start of descriptor
	DEC	BX
	DEC	BX
	PUSH	BX ;Save pointer to start
	CALL	STRCPY ;Copy string into DSCTMP
	POP	BX ;Destination in [H,L], source in [D,E]
	MOV	CH,3 ;# of bytes to move
	CALL	MOVE1 ;Move em
	POP	BX ;Where we are
	RET
; Step 5 - Move stuff up into string space!
DNCCLS:
	CALL	GARBA2 ;Get rid of unused strings
	MOV	BX,STREND ;Load end of vars
	MOV	CX,BX ;Into [B,C]
	MOV	DX,VARTAB ;Start of simps into [D,E]
	MOV	BX,ARYTAB
	SUB	BX,DX ;Get length of simps in [H,L]
	MOV	[TEMP9],BX ;Save here
	MOV	BX,FRETOP ;Destination of high byte
	MOV	[SAVFRE],BX ;Save FRETOP to restore later
	CALL	BLTUC ;Move stuff up
	MOV	BX,CX ;Now adjust top of memory below saved vars
	DEC	BX ;One lower to be sure
	MOV	[FRETOP],BX ;Update FRETOP to reflect new value
	MOV	AL,byte [MDLFLG] ;MERGE w/ DELETE?
	OR	AL,AL ;Test
	JZ	NTMDLT ;No
	MOV	BX,CMSPTR ;Start of lines to delete
	MOV	CX,BX ;Into [B,C]
	MOV	BX,CMEPTR ;End of lines to delete
	CALL	DEL ;Delete the lines
	MOV	[ARYTAB],BX ;***also set up ARYTAB and STREND
	MOV	[STREND],BX ;in case we get error in CHAIN
;because of file lookup and then have to
;look at variables later (shouldnt be any)
;***PGA 7/7/81
	CALL	LINKER ;Re-link lines just in case
; Step 6 - load new program
NTMDLT:	MOV	AL,1 ;Set CHAIN flag
	MOV	byte [CHNFLG],AL
extern CHNENT
extern OKGETM
	MOV	AL,byte [MRGFLG] ;MERGEing?
	OR	AL,AL ;Set cc'S
	JZ	??L013
	JMP	OKGETM ;Do MERGE
??L013:
	JMP	CHNENT ;Jump to LOAD code
; Step 7 - Move stuff back down
global CHNRET
CHNRET:
	MOV	AL,byte [TOPTVL]
	MOV	byte [OPTVAL],AL ;RESTORE IOTION BASE VALUE
	MOV	AL,byte [TOPTFG]
	MOV	byte [OPTFLG],AL ;LRESTORE OPTION FLG
	XOR	AL,AL ;Clear CHAIN, MERGE flags
	MOV	byte [CHNFLG],AL
	MOV	byte [MRGFLG],AL
	MOV	BX,VARTAB ;Get current VARTAB
	MOV	CX,BX ;Into [B,C]
	MOV	BX,TEMP9 ;Get length of simps
	ADD	BX,CX ;Add to present VARTAB to get new ARYTAB
	MOV	[ARYTAB],BX
	MOV	BX,FRETOP ;Where to start moving
	INC	BX ;One higher
	XCHG	BX,DX ;Into [D,E]
	MOV	BX,SAVFRE ;Last byte to move
	MOV	[FRETOP],BX ;Restore FRETOP from this
MVBKVR:	CMP	BX,DX ;Done?
	MOV	SI,DX
	MOV	AL,[SI] ;Move byte down
	MOV	DI,CX
	STOSB
	LAHF
	INC	DX ;Increment pointers
	SAHF
	LAHF
	INC	CX
	SAHF
	JNZ	MVBKVR
	DEC	CX ;Point to last var byte
	MOV	BX,CX ;[H,L]=last var byte
	MOV	[STREND],BX ;This is new end
extern NLONLY
	XOR	AL,AL ;
	MOV	byte [NLONLY],AL ;allow all files to be closed
extern FINPRT
	CALL	FINPRT ;close file zero and reset PTRFIL to 0
	XOR	AL,AL
	CALL	RESTORE ;Make sure DATA is valid by doing RESTORE
	MOV	DX,CHNLIN ;Get CHAIN line # in [D,E]
	MOV	BX,TXTTAB ;Get prog start in [H,L]
	DEC	BX ;Point at zero before program
	OR	DX,DX ;line number zero?
	JNZ	??L014
	JMP	NEWSTT ;line #=0, go...
??L014:
	CALL	FNDLIN ;Try to find destination line
	JNAE	??L015
	JMP	USERR ;Not there...
??L015:
	DEC	CX ;Point to zero on previous line
	MOV	BX,CX ;Make text pointer for NEWSTT
	JMP	NEWSTT ;Bye...
;
; Convenience routine to skip a variable's name pointed to by HL.
; Returns VALTYP in A with the zero flag set if it is a string.
;
global SKPNAM
SKPNAM:
	MOV	AL,byte [BX] ;Get VALTYP
	INC	BX ;Point to length of long var name
	INC	BX
	INC	BX
	PUSH	AX ;Save VALTYP
	CALL	IADAHL ;Move past long variable name
	POP	AX ;Get back VALTYP
	CMP	AL,3 ;String?
	RET
;
;
BASIC_COMMON:
	JMP	DATA
; SUBTTL  WRITE
extern FINPRT
extern FOUT
extern STRLIT
extern STRPRT
extern OUTDO
extern FACLO
global WRITE
WRITE:
extern FILGET
	MOV	CL,MD_SQO ;Setup output file
	CALL	FILGET
WRTCHR:	DEC	BX
	CALL	CHRGTR ;Get another character
	JZ	WRTFIN ;Done with WRITE
WRTMLP:	CALL	FRMEVL ;Evaluate formula
	PUSH	BX ;Save the text pointer
	CALL	GETYPR ;See if we have a string
	JZ	WRTSTR ;We do
	CALL	FOUT ;Convert to a string
	CALL	STRLIT ;Literalize string
	MOV	BX,FACLO ;Get pointer to string
	INC	BX ;Point to address field
	MOV	DX,[BX]
	INC	BX
	MOV	SI,DX
	MOV	AL,[SI] ;Is number positive?
	CMP	AL," " ;Test
	JNZ	WRTNEG ;No, must be negative
	INC	DX
	MOV	byte [BX],DH
	DEC	BX
	MOV	byte [BX],DL
	DEC	BX
	DEC	byte [BX] ;Adjust length of string (length.LT.255 so OK)
WRTNEG:	CALL	STRPRT ;Print the number
NXTWRV:	POP	BX ;Get back text pointer
	DEC	BX ;Back up pointer
	CALL	CHRGTR ;Get next char
	JZ	WRTFIN ;end
	CMP	AL,59 ;Semicolon?
	JZ	WASEMI ;Was one
	CALL	SYNCHR
db 0o54 ;Only possib left is comma
	DEC	BX ;to compensate for later CHRGET
WASEMI:	CALL	CHRGTR ;Fetch next char
	MOV	AL,0o54 ;put out comma
	CALL	OUTDO
	JMP	WRTMLP ;Back for more
WRTSTR:	MOV	AL,34 ;put out double quote
	CALL	OUTDO ;Send it
	CALL	STRPRT ;print the string
	MOV	AL,34 ;Put out another double quote
	CALL	OUTDO ;Send it
	JMP	NXTWRV ;Get next value
WRTFIN:
extern CMPFBC
extern PTRFIL
	PUSH	BX ;Save text pointer
	MOV	BX,PTRFIL ;See if disk file
	MOV	AL,BH
	OR	AL,BL
	JZ	NTRNDW ;No
	PUSH	BX ;Save FDB pointer
	MOV	CX,F_DEV
	ADD	BX,CX ;HL points to Device Entry in FDB
	MOV	AL,byte [BX] ;[A]=device id
	OR	AL,AL ;if disk [A] will be 0..n
	POP	BX
	JNS	??L016
	JMP	NTRNDW ;branch if special device ([A] is negative)
??L016:
	PUSH	BX
	MOV	CX,F_MODE
	ADD	BX,CX ;HL points to File Mode Byte in FDB
	MOV	AL,byte [BX] ;[A]=file mode
	POP	BX ;Restore FDB pointer
	CMP	AL,MD_RND ;Random?
	JNZ	NTRNDW ;NO
	CALL	CMPFBC ;See how many bytes left
	MOV	AL,BL ;do subtract
	SUB	AL,DL
	MOV	BL,AL
	MOV	AL,BH
	SBB	AL,DH
	MOV	BH,AL
%assign CRLFSQ 2 ;Number of bytes in CR/LF sequence
	MOV	DX,0-CRLFSQ ;Subtract bytes in <cr>
	LAHF
	ADD	BX,DX
	RCR	SI,1
	SAHF
	RCL	SI,1
	JAE	NTRNDW ;Not enough, give error eventually
NXTWSP:	MOV	AL," " ;Put out spaces
	CALL	OUTDO ;Send space
	DEC	BX ;Count down
	MOV	AL,BH ;Count down
	OR	AL,BL
	JNZ	NXTWSP
NTRNDW:	POP	BX ;Restore [H,L]
	CALL	CRDO ;Do crlf
	JMP	FINPRT
