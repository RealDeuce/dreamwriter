; Auto-converted mechanically from ../gw-basic/call86.asm
; Edit the converter or the generated source deliberately; do not hand-wave syntax changes.

; [ This translation created 10-Feb-83 by Version 4.3 ]
; .RADIX  8
%include "dwoem.inc"
; TITLE   CALL86  8086 CALL Statement
; .RADIX	8
extern VMOVFM
extern FRQINT
extern PTRGET
extern GETSTK
extern CHRGTR
extern SYNCHR
extern CHRGT2
extern FCERR
extern SUBFLG
extern SARYFL
extern TEMP
extern TEMPA
extern SAVSEG
extern ARYTAB
; This is the CALL <simple var>[(<simple var>[,<simple var>]..)]
; Stragegy:
;
; 1.) Make sure suboutine name is simple var, get value & save it
;
; 2.) Evaluate params & stuff pointers on stack
;
; 3.) CALL suboutine with return address on stack
;
; The CALLS statement is the same as CALL, except for each parameter
; it pushes Segment and Offset, not just Offset.
global CALLS
global CALLSL
CALLSL:	CLC ;Clear-carry, (PUSH Segment adr of parms)
	JMP	CALLS1
CALLS:	STC ;Set-carry, (don't PUSH Segment adr of parms)
CALLS1:	PUSHF
extern PRODIR ;Don't allow CALL as direct statement in
	CALL	PRODIR ;protected environment
	MOV byte [SUBFLG], 0o200 ;say we want to scan only a simple
	CALL	PTRGET ;scan var and search symbol table
	MOV byte [SARYFL], 0o0 ;clear Scanned-Array-Element-Flag
	PUSH	BX ;save text pointer
	MOV	BX,DX ;get pointer to var in BX
	CALL	VMOVFM ;load variable into FAC
	CALL	FRQINT ;make it an integer
	MOV word [TEMPA], BX ;save text pointer
	MOV	CL,32 ;get max # of parameters
	CALL	GETSTK ;see if there is that much stack space
	POP	BX ;get back text pointer
	CALL	CHRGT2 ;eat character after var name
	JZ	CALLST ;end of statement, no parameter list
	CALL	SYNCHR ;check for open paren
db 0o50 ; (
GETPAR:	PUSH	word [ARYTAB] ;save pointer to start of array var data
	CALL	PTRGET ;scan parameter variable
	POP	CX ;[CX]=old value of ARYTAB
	CMP CX, word [ARYTAB] ;if = old, no undefined simples were referenced
	JE	NONEWS ;Branch if New Simple Var not encountered
	CMP byte [SARYFL], 0o0 ;Z-FLAG if no Array elements have been parsed
; by PTRGET
	JZ	NONEWS
	JMP	FCERR ;Undefined scalers can't be passed after array
;elements since the addr of the array element
;changes when the new scaler is added.
NONEWS:	POPF ;restore Carry=CALL/CALLS flag
	JB	SHTPRM ;Branch if CALL (not CALLS)
	PUSH	DS ;save Segment of Parameter on stack
SHTPRM:	PUSH	DX ;save Offset of parameter on stack
	PUSHF ;re-save CALL/CALLS flag
	MOV	AL,byte [BX+0o0] ;get terminator
	CMP	AL,"," ;comma?
	JNZ	ENDPAR ;no, must be end of the param list
	CALL	CHRGTR ;scan next char
	JMP	GETPAR ;scan next parm
ENDPAR:	CALL	SYNCHR ;check for terminating right paren
db 0o51 ; )
CALLST:	MOV word [TEMP], BX ;save text pointer
	POPF ;discard CALL/CALLS flag
	PUSH	CS ;save BASIC code segment
	MOV	AX,CALLRT ;where to return to
	PUSH	AX
	PUSH	word [SAVSEG] ;save subroutine segment
	PUSH	word [TEMPA] ;save subroutine address
db 0o313 ; Do a long return to call the subroutine
;
CALLRT:	MOV BX, word [TEMP] ;get back text pointer
	RET ;return to newstt
;
