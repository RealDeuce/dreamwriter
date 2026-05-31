; Auto-converted mechanically from ../gw-basic/gwdata.asm
; Edit the converter or the generated source deliberately; do not hand-wave syntax changes.

; [ This translation created 10-Feb-83 by Version 4.3 ]
; .RADIX  8
%include "dwoem.inc"
; TITLE   GWDATA copied from BINTRP.MAC
; .RADIX	10
%assign SLASHI 0 ;Runtime Switch to include IBM Compat.-Features
%assign FETOK 0 ;For FE extended tokens
%assign FDTOK 0 ;For FD tokens too.  (Must have
;FETOK==1.)
;tokens.
%assign INTDEX 0 ;For Intelledex version.
%assign NMPAGE 1 ;Number of text pages (for GW
;Multi-page)
;KPOS, etc.
%assign LNREAD 0 ;For LINE READ statement
%assign MELCO 0 ;Mitsubishi Electronics Co.
%assign SIRIUS 0
%assign MCI 0
%assign ZENITH 0 ;ZENITH 8086
%assign TETRA 0
%assign CPM86 0
%assign HAL 0
%assign GENFLS 0
%assign PANDBL 0
%assign TSHIBA 0
%assign SGS 0
%assign ALPS 0
%assign ALPCPM 0
%assign GENWID 0
%assign NNECBS 0
%assign CAN8 0
%assign PC8A 0
%assign FN2SW 0 ;IBMTOK versions dispatch from IBMRES.MAC
%define LABEL PC8A
%define HLPEDT PC8A
%assign OKI 0
%assign BUBL 0
%assign NORNF 0
%assign IEESLV 0
%assign TRSHHC 0
%assign OLVPPC 0
%assign NECPPC 0
%assign USA 0 ;For HHC-USA version
%assign EUROPE 0 ;For HHC-EUROPE version
;Local Switches
;
%define LTRACE ALPCPM ;trace output selectable
%define LABEL PC8A
%define HLPEDT PC8A
%define UCEMSG NNECBS ;Upper case error messages.
%define OLD86 MELCO & CPM86 ;For "old" 8086 error messages (prior
;to alignment for IBM compatibility).
%define OLDBLD ALPCPM | ALPS | OKI | HAL | PC8A | BUBL | GW | TSHIBA
%include "gio86u.inc"
%include "msdosu.inc" ;MSDOS constants
extern _DVTBL
extern _DVPTR
extern _DVINI
extern _DVTRM
extern INIT
extern INTDIV
%assign BUFOFS 0
%assign BUFOFS 2 ;MUST CRUNCH INTO ERALIER PLACE FOR
; SINGLE QUOTE
%define KBFLEN BUFLEN+(BUFLEN/4) ;MAKE KRUNCH BUFFER SOMEWHAT
; LARGER THAN SOURCE BUFFER (BUF)
extern NAME
extern INLIN
extern CRDO
extern CRDONZ
extern STRCMP
extern FININL
extern PPSWRT
extern OUTDO
extern BLTU
extern BLTUC
extern CLEAR
extern CLEARC
extern GTMPRT
extern ISLET
extern ISLET2
extern PTRGET
extern QINLIN
extern SCRTCH
extern STKINI
extern RUNC
extern RESFIN
extern PTRGT2
extern STPEND
extern DIM
extern DCOMPR
extern SYNCHR
extern SIGN
extern OPEN
extern CLOSE
extern PRGFIN
extern FILIND
extern FILINP
extern CLSALL
extern INDSKC
extern LRUN
extern FILGET
extern INXHRT
extern SGN
extern ABSFN
extern SQR
extern FDIV
extern FSUB
extern FMULT
extern RND ;MATHPK INTERNALS
extern ZERO
extern MOVE
extern FOUT
extern FIN
extern FCOMP
extern FADD
extern PUSHF
extern INT
extern ENDST
extern NEXT
extern RESTORE
extern SCRATH
extern CONT
extern FRE
extern MOVFR
extern MOVRF
extern MOVRM
extern INPRT
extern LINPRT
extern FDIVT
extern MOVFM
extern MOVMF
extern FADDS
extern INRART
extern NEG
extern BSERR
extern CAT
extern FREFAC
extern FRESTR
extern FRETMP
extern FRETMS
extern STRCPY
extern GETSTK
extern STRLIT
extern STRLT2
extern STRLT3
extern STRLTI
extern STROUT
extern STRPRT
extern STROUI
extern GETSPA
extern PUTNEW
extern STOP
extern OMERR
extern REASON
extern GARBA2 ;We have our own G. C.
extern INSTR
extern PRINUS
extern PUTTMP
extern FOUTH
extern FOUTO
extern STRO$
extern STRH$
extern STR$
extern LEN
extern ASC
extern CHR$
extern LEFT$
extern RIGHT$
extern MID$
extern VAL
extern STRNG$
extern TON
extern TOFF
extern SPACE$
extern SIGNS
extern UMULT
extern SIGNC
extern POPHRT
extern FINLPT
extern CONSIH
extern VMOVFA
extern VMOVAF
extern ISIGN
extern CONIA
extern VSIGN
extern VDFACS
extern VMOVMF
extern VMOVFM
extern FRCINT
extern FRCSNG
extern FRCDBL
extern VNEG
extern PUFOUT
extern DCXBRT
extern IADD
extern ISUB
extern IMULT
extern ICOMP
extern INEG
extern DADD
extern DSUB
extern DMULT
extern DDIV
extern DCOMP
extern VINT
extern FINDBL
extern INEG2
extern IDIV
extern IMOD
extern VMOVE
extern VALINT
extern VALSNG
extern FRCSTR
extern CHKSTR
extern MAKINT
extern MOVE1
extern SCNSEM
extern WHILE
extern WEND
extern CALLS
extern PROCHK
extern WRITE
extern CHAIN
extern BASIC_COMMON
;
; This label must be the first one in the code segment as it is
; where the SYSTEM command will jump to
;
global BEGCSG
BEGCSG:
global CPMWRM
CPMWRM:
; org 0o5
global CPMENT
CPMENT:
; org 0o400
global DOL_START
DOL_START:
global START
START:
JMPINI:	JMP	INIT ;INIT IS THE INTIALIZATION ROUTINE
;IT SETS UP CERTAIN
;LOCATIONS DELETES FUNCTIONS IF
;DESIRED AND
;CHANGES THIS TO JMP READY
;IFE    <I8086-1>!<LENGTH-2>,<> ;Seems to be a relic, screws up
;conditional nesting. 16-Feb-82/NGT
; SUBTTL ROM VERSION INITALIZATION, AND CONSTANTS
;
; The reserved word tables are in another module.  Consequently
; many things must be declared external.  All of these things
; are in the code segement or are absolutes (like tokens).
; I.e., they are not in the data segment.
;
extern ALPTAB
extern FUNDSP
extern STMDSP
extern POS
extern PRINT
extern RESLST
extern SPCTAB
global OPTAB
OPTAB: db 121 ;OPERATOR TABLE CONTAINS
;PRECEDENCE FOLLOWED BY
;THE ROUTINE ADDRESS
db 121
db 124
db 124
db 127
db 80
db 70
db 60 ;PRECEDENCE OF "XOR"
db 50 ;PRECEDENCE OF "EQV"
db 40 ;PRECEDENCE OF "IMP"
db 122 ;PRECEDENCE OF "MOD"
db 123 ;PRECEDENCE OF "IDIV"
;
; USED BY ASSIGNMENT CODE TO FORCE THE RIGHT HAND VALUE
; TO CORRESPOND TO THE VALUE TYPE OF THE VARIABLE BEING
; ASSIGNED TO.
;
global FRCTBL
FRCTBL:	dw FRCDBL
db 2 dup (?)
dw FRCINT
dw CHKSTR
dw FRCSNG
;
; THESE TABLES ARE USED AFTER THE DECISION HAS BEEN MADE
; TO APPLY AN OPERATOR AND ALL THE NECESSARY CONVERSION HAS
; BEEN DONE TO MATCH THE TWO ARGUMENT TYPES (APPLOP)
;
global DBLDSP
DBLDSP:	dw DADD ;DOUBLE PRECISION ROUTINES
dw DSUB
dw DMULT
dw DDIV
dw DCOMP
global OPCNT
OPCNT equ (($-DBLDSP)/2)-1
global SNGDSP
SNGDSP:	dw FADD ;SINGLE PRECISION ROUTINES
dw FSUB
dw FMULT
dw FDIV
dw FCOMP
global INTDSP
INTDSP:	dw IADD ;INTEGER ROUTINES
dw ISUB
dw IMULT
dw INTDIV
dw ICOMP
; SUBTTL  ERROR MESSAGE TABLE
; Error-message table generated from gw-basic/gwdata.asm.
global ERRTAB
ERRTAB:
db 0
db "NEXT without FOR", 0
db "Syntax error", 0
db "RETURN without GOSUB", 0
db "Out of DATA", 0
db "Illegal function call", 0
global DOL_OVMSG
DOL_OVMSG:
global DOL_OVMSG
DOL_OVMSG:
global OVRMSG
OVRMSG:
global OVRMSG
OVRMSG:
db "Overflow", 0
db "Out of memory", 0
db "Undefined line number", 0
db "Subscript out of range", 0
db "Duplicate Definition", 0
global DOL_DIV0M
DOL_DIV0M:
global DOL_DIV0M
DOL_DIV0M:
global DIVMSG
DIVMSG:
global DIVMSG
DIVMSG:
db "Division by zero", 0
db "Illegal direct", 0
db "Type mismatch", 0
db "Out of string space", 0
db "String too long", 0
db "String formula too complex", 0
db "Can't continue", 0
db "Undefined user function", 0
db "No RESUME", 0
db "RESUME without error", 0
db "Unprintable error", 0
db "Missing operand", 0
db "Line buffer overflow", 0
db "Device Timeout", 0
db "Device Fault", 0
db "FOR Without NEXT", 0
db "Out of Paper", 0
db "?", 0
db "WHILE without WEND", 0
db "WEND without WHILE", 0
db "FIELD overflow", 0
db "Internal error", 0
db "Bad file number", 0
db "File not found", 0
db "Bad file mode", 0
db "File already open", 0
db "?", 0
DSKLOC equ $+6
db "Device I/O Error", 0
db "File already exists", 0
db "?", 0
db "?", 0
db "Disk full", 0
db "Input past end", 0
db "Bad record number", 0
db "Bad file name", 0
db "?", 0
db "Direct statement in file", 0
db "Too many files", 0
db "Device Unavailable", 0
db "Communication buffer overflow", 0
db "Disk write protected", 0
db "Disk not Ready", 0
db "Disk media error", 0
db "Advanced Feature", 0
db "Rename across disks", 0
%define LSTERR ERRC_LSTERR

; SUBTTL CONSTANTS FOR ROM BASIC I/O, RNDX, FDIV, USRGO
;********************************************************************
;
;       NOTE!!!         THIS RAM CODE IS REPRODUCED LATER IN THIS
;                       LISTING WITHOUT LABELS AND TARGETED
;                       FOR ROM. THIS ALLOWS THE CODE TO BE COPIED
;                       INTO RAM FOR EXECUTION. IF THERE IS A CHANGE
;                       TO BE MADE TO THE RAM CODE MAKE THE SIMULAR
;                       CHANGE TO THE ROM AREA CODE WITHOUT LABELS.
;                       THE ROM CODE IS BRACKETED BY AN IFN CONVRT
;                       AND A COMMENT INDICATING THE CODE IS FOR
;                       TARGET MACHINE COMPILATIONS.
;
;******************************************************************
global CONSTR
global RAMLOW
global CNSLEN
CNSLEN equ ENDCNS-CONSTR
;FOR ON-MACHINE COMPILATIONS
global CONSTR
CONSTR:
;************************************************************
;****** BEGDSG: is the begining of the data segment.  *******
;****** It MUST be the first label in DSEG, as it is  *******
;****** used by GWINIT to insert the OS control block *******
;************************************************************
global BEGDSG
BEGDSG:
; org 2
global CPMMEM
CPMMEM:
; ======== Code Phase ========
RAMLOW:
db 0o352 ;INTER-SEGMENT DIRECT JUMP
db 4 dup (?)
;
;THE FOLLOWING IS THE LAST RANDOM NUMBER GENERATED BY RND
;IT MUST NOT BE ZERO, IT MUST BE BETWEEN 0 AND 1.
;
; .RADIX	8
db 0o0
; RNDCNT:
db 0o0
db 0o0
	RET ;THIS IS A KLUDGE TO MAKE CHRGET WORK
global NUMCON
; NUMCON:
db CONCON ;THESE FAKE TOKENS FORCE CHRGET
db CONCN2 ;TO EFFECTIVELY RE-SCAN THE EMBEDED CONSTANT
global DSEGZ
; DSEGZ:
db 0o0 ;DATA SEGMENT-LOCATED ZERO
global RNDCOP
; RNDCOP:
db 0o122 ;COPY OF THE RANDOM NUMBER SEED
db 0o307 ;BETWEEN 0 AND 1
db 0o117
db 0o200
global DOL_RNDX
; $RNDX:
global RNDX
; RNDX:
db 0o122 ;LAST RANDOM NUMBER GENERATED
db 0o307 ;BETWEEN 0 AND 1
db 0o117
db 0o200
; .RADIX	10
; STAINP:
	IN	AL,0
db 0o313 ;"LONG" RETURN
global ENDPRG
; ENDPRG:
db ":"
db 0,0,0,0 ;FAKE END OF PROGRAM FOR RESUME NEXT
; SUBTTL LOW SEGMENT -- RAM-- IE THIS STUFF IS NOT CONSTANT
;
; THIS IS THE "VOLATILE" STORAGE AREA AND NONE OF IT
; CAN BE KEPT IN ROM. ANY CONSTANTS IN THIS AREA CANNOT
; BE KEPT IN A ROM, BUT MUST BE LOADED IN BY THE
; PROGRAM INSTRUCTIONS IN ROM.
;
global USRTAB
; USRTAB:
times 10 dw 65535
; NULCNT:
db 1 ;STORE HERE THE NUMBER OF NULLS
;TO PRINT AFTER CRLF
global MSDCCF
; MSDCCF:
db 0 ;Ctl-C flag set by Ctl-C int handler
global CTLCAD
; CTLCAD:
db 4 dup (?) ;Store pre-BASIC CTL-C int vector
global DINTAD
; DINTAD:
db 4 dup (?) ;Store BASIC Disk error int vector
global LSTCHR
; LSTCHR:
db 0 ;used by SCNSOT to remember last chr out
global ERRFLG
; ERRFLG:
db 0 ;USED TO SAVE THE ERROR NUMBER
; SO EDIT CAN BE CALLED ON "SN" ERR.
global LPTLST
; LPTLST:
db 0 ;LAST LINE PRINTER OPERATION. ZERO
;MEANS LINEFEED. NON-ZERO MEANS PRINT
;COMMAND (OKIA ONLY)
global LPTPOS
; LPTPOS:
db 0 ;POSITION OF LPT PRINT HEAD -initially 0
global PRTFLG
; PRTFLG:
db 0 ;WHETHER OUTPUT GOES TO LPT
%define LNCMPS (((LPTLEN/CLMWID)-1)*CLMWID) ;LAST COMMA FIELD POSIT
global NLPPOS
; NLPPOS:
db LNCMPS ;LAST COL # BEYOND WHICH NO MORE COMMA FIELDS
global LPTSIZ
; LPTSIZ:
db LPTLEN ;DEFAULT LINE PRINTER WIDTH
global DAYSPM
; DAYSPM:
db 31,28,31,30,31,30
db 31,31,30,31,30,31
%define NCMPOS (((LINLN/CLMWID)-1)*CLMWID) ;POSITION BEYOND WHICH THERE ARE
;NO MORE COMMA FIELDS
; CLMLST:
db NCMPOS ;POSITION OF LAST COMMA COLUMN
global RUBSW
; RUBSW:
db 0 ;RUBOUT SWITCH =1 INSIDE
;THE PROCESSING OF A RUBOUT (INLIN)
global CNTOFL
; CNTOFL:
db 0 ;SUPRESS OUTPUT FLAG
;NON-ZERO MEANS SUPRESS
;RESET BY "INPUT",READY AND ERRORS
;COMPLEMENTED BY INPUT OF ^O
global PTRFIL
; PTRFIL:
dw 0
;POINTER TO DATA BLOCK OF CURRENT FILE
;USED BY DISK AND NCR CASSETTE CODE
global TOPMEM
; TOPMEM:
dw TSTACK+100 ;TOP LOCATION TO USE FOR THE STACK
;INITIALLY SET UP BY INIT
;ACCORDING TO MEMORY SIZE
;TO ALLOW FOR 50 BYTES OF STRING SPACE.
;CHANGED BY A CLEAR COMMAND WITH
;AN ARGUMENT.
global CURLIN
; CURLIN:
dw 0+65534 ;CURRENT LINE #
;SET TO 65534 IN PURE VERSION DURING INIT EXECUTION
;SET TO 65535 WHEN DIRECT STATEMENTS EXECUTE
global TXTTAB
; TXTTAB:
dw TSTACK+1 ;POINTER TO BEGINNING OF TEXT
;DOESN'T CHANGE AFTER BEING
;SETUP BY INIT.
global OVERRI
; OVERRI:
dw OVRMSG ;ADDRESS OF MESSAGE TO PRINT (OVERFLOW)
global CSRTYP
; CSRTYP:
db 0 ;Type of next cursor
global CSRFLG
; CSRFLG:
db 0 ;Type of current cursor
;
;Generalized I/O initialized data definitions
;
; EXTERN        .DVTBL, .DVPTR, .DVINI, .DVTRM
; INTERNs and EXTERNs moved out of the PHASE block for ASM86 translator.
; 9/2/82/NGT
global DEVTBL
; DEVTBL:
dw _DVTBL ;points to array of device names
global DEVPTR
; DEVPTR:
dw _DVPTR ;points to array of device dispatch tables
global DEVINI
; DEVINI:
dw _DVINI ;points to array of device initalize routines
global DEVTRM
; DEVTRM:
dw _DVTRM ;points to array of device termination routines
global SAVKEY
; SAVKEY:
db 0 ;for saving 2nd byte of 2-byte seq.
global SAVKYF
; SAVKYF:
db 0 ;Flag nonzero when SAVKEY is active (SAVKEY may be 0)
global FREFDB
; FREFDB:
dw 0 ;Used by Device Open Routines to release FDB
;if error occurs after FDB is allocated but
;before File actually becomes OPEN.
;FDB is Freed by routine FINPRT.
%define DATSTR $
;
; ======== Data Phase ========
;
; org 0+0o400
; duplicate RAMLOW phase marker
db 0o352 ;INTER-SEGMENT DIRECT JUMP
db 4 dup (?)
;
;THE FOLLOWING IS THE LAST RANDOM NUMBER GENERATED BY RND
;IT MUST NOT BE ZERO, IT MUST BE BETWEEN 0 AND 1.
;
; .RADIX	8
db 0o1 dup (?)
RNDCNT:
db 0o1 dup (?)
db 0o1 dup (?)
	RET ;THIS IS A KLUDGE TO MAKE CHRGET WORK
global NUMCON
NUMCON:
db 0o1 dup (?) ;THESE FAKE TOKENS FORCE CHRGET
db 0o1 dup (?) ;TO EFFECTIVELY RE-SCAN THE EMBEDED CONSTANT
global DSEGZ
DSEGZ:
db 0o1 dup (?) ;DATA SEGMENT-LOCATED ZERO
global RNDCOP
RNDCOP:
db 0o1 dup (?) ;COPY OF THE RANDOM NUMBER SEED
db 0o1 dup (?) ;BETWEEN 0 AND 1
db 0o1 dup (?)
db 0o1 dup (?)
global DOL_RNDX
DOL_RNDX:
global RNDX
RNDX:
db 0o1 dup (?) ;LAST RANDOM NUMBER GENERATED
db 0o1 dup (?) ;BETWEEN 0 AND 1
db 0o1 dup (?)
db 0o1 dup (?)
; .RADIX	10
STAINP:
	IN	AL,0
db 0o313 ;"LONG" RETURN
global ENDPRG
ENDPRG:
db 1 dup (?)
db 4 dup (?) ;FAKE END OF PROGRAM FOR RESUME NEXT
; SUBTTL LOW SEGMENT -- RAM-- IE THIS STUFF IS NOT CONSTANT
;
; THIS IS THE "VOLATILE" STORAGE AREA AND NONE OF IT
; CAN BE KEPT IN ROM. ANY CONSTANTS IN THIS AREA CANNOT
; BE KEPT IN A ROM, BUT MUST BE LOADED IN BY THE
; PROGRAM INSTRUCTIONS IN ROM.
;
global USRTAB
USRTAB:
times 10 dw 0
global NULCNT
NULCNT:
db 1 dup (?) ;STORE HERE THE NUMBER OF NULLS
;TO PRINT AFTER CRLF
global MSDCCF
MSDCCF:
db 1 dup (?) ;Ctl-C flag set by Ctl-C int handler
global CTLCAD
CTLCAD:
db 4 dup (?) ;Store pre-BASIC CTL-C int vector
global DINTAD
DINTAD:
db 4 dup (?) ;Store BASIC Disk error int vector
global LSTCHR
LSTCHR:
db 1 dup (?) ;used by SCNSOT to remember last chr out
global ERRFLG
ERRFLG:
db 1 dup (?) ;USED TO SAVE THE ERROR NUMBER
; SO EDIT CAN BE CALLED ON "SN" ERR.
global LPTLST
LPTLST:
db 1 dup (?) ;LAST LINE PRINTER OPERATION. ZERO
;MEANS LINEFEED. NON-ZERO MEANS PRINT
;COMMAND (OKIA ONLY)
global LPTPOS
LPTPOS:
db 1 dup (?) ;POSITION OF LPT PRINT HEAD -initially 0
global PRTFLG
PRTFLG:
db 1 dup (?) ;WHETHER OUTPUT GOES TO LPT
%define LNCMPS (((LPTLEN/CLMWID)-1)*CLMWID) ;LAST COMMA FIELD POSIT
global NLPPOS
NLPPOS:
db 1 dup (?) ;LAST COL # BEYOND WHICH NO MORE COMMA FIELDS
global LPTSIZ
LPTSIZ:
db 1 dup (?) ;DEFAULT LINE PRINTER WIDTH
global DAYSPM
DAYSPM:
db 6 dup (?)
db 6 dup (?)
%define NCMPOS (((LINLN/CLMWID)-1)*CLMWID) ;POSITION BEYOND WHICH THERE ARE
;NO MORE COMMA FIELDS
CLMLST:
db 1 dup (?) ;POSITION OF LAST COMMA COLUMN
global RUBSW
RUBSW:
db 1 dup (?) ;RUBOUT SWITCH =1 INSIDE
;THE PROCESSING OF A RUBOUT (INLIN)
global CNTOFL
CNTOFL:
db 1 dup (?) ;SUPRESS OUTPUT FLAG
;NON-ZERO MEANS SUPRESS
;RESET BY "INPUT",READY AND ERRORS
;COMPLEMENTED BY INPUT OF ^O
global PTRFIL
PTRFIL:
dw 1 dup (?)
;POINTER TO DATA BLOCK OF CURRENT FILE
;USED BY DISK AND NCR CASSETTE CODE
global TOPMEM
TOPMEM:
dw TSTACK+100 ;TOP LOCATION TO USE FOR THE STACK
;INITIALLY SET UP BY INIT
;ACCORDING TO MEMORY SIZE
;TO ALLOW FOR 50 BYTES OF STRING SPACE.
;CHANGED BY A CLEAR COMMAND WITH
;AN ARGUMENT.
global CURLIN
CURLIN:
dw 0+65534 ;CURRENT LINE #
;SET TO 65534 IN PURE VERSION DURING INIT EXECUTION
;SET TO 65535 WHEN DIRECT STATEMENTS EXECUTE
global TXTTAB
TXTTAB:
dw TSTACK+1 ;POINTER TO BEGINNING OF TEXT
;DOESN'T CHANGE AFTER BEING
;SETUP BY INIT.
global OVERRI
OVERRI:
dw OVRMSG ;ADDRESS OF MESSAGE TO PRINT (OVERFLOW)
global CSRTYP
CSRTYP:
db 1 dup (?) ;Type of next cursor
global CSRFLG
CSRFLG:
db 1 dup (?) ;Type of current cursor
;
;Generalized I/O initialized data definitions
;
; EXTERN        .DVTBL, .DVPTR, .DVINI, .DVTRM
; INTERNs and EXTERNs moved out of the PHASE block for ASM86 translator.
; 9/2/82/NGT
global DEVTBL
DEVTBL:
dw _DVTBL ;points to array of device names
global DEVPTR
DEVPTR:
dw _DVPTR ;points to array of device dispatch tables
global DEVINI
DEVINI:
dw _DVINI ;points to array of device initalize routines
global DEVTRM
DEVTRM:
dw _DVTRM ;points to array of device termination routines
global SAVKEY
SAVKEY:
db 1 dup (?) ;for saving 2nd byte of 2-byte seq.
global SAVKYF
SAVKYF:
db 1 dup (?) ;Flag nonzero when SAVKEY is active (SAVKEY may be 0)
global FREFDB
FREFDB:
dw 1 dup (?) ;Used by Device Open Routines to release FDB
;if error occurs after FDB is allocated but
;before File actually becomes OPEN.
;FDB is Freed by routine FINPRT.
%define DATSTR $
;
;========== End of Phase ==========
;
ENDCNS:
;Start the data segment
;
;
;GIO86 uninitialized data definitions:
;
global FILDEV
FILDEV equ FILNAM
global FILNM
FILNM equ FILNAM+1
global FILEXT
%define FILEXT FILNM+FNAML-3
global IOJUMP
IOJUMP:
db 2 dup (?)
global FILTAB
FILTAB:
db 2 dup (?) ;points to 1st FDB (=STKLOW if no FDB's)
global STKLOW
STKLOW:
db 2 dup (?) ;lowest legal value of [SP]
global FILMOD
FILMOD:
db 1 dup (?)
global NLONLY
NLONLY:
db 1 dup (?)
global RUNFLG
RUNFLG:
db 1 dup (?)
F_PCOM:
db 1 dup (?) ;Flags comma terminator for number print
global DATIME
DATIME:
db 5 dup (?) ;days(2), hours(1), minutes(1), secs(1)
global CPMEXT
CPMEXT:
db 4 dup (?) ;Exit jump vector.  Set to DS:0 at INIT.
;MSDOS 2.0 exit must be made through the
;initialization segment prefix - not at CS:0
;for .EXE files.
global NAMCNT
NAMCNT:
db 1 dup (?) ;THE NUMBER OF CHARACTER BEYOND #2 IN A VAR NAME
global NAMBUF
NAMBUF:
times NAMLEN-2 db 0 ;STORAGE FOR CHARS BEYOND #2. USED IN PTRGET
global NAMTMP
NAMTMP:
db 2 dup (?) ;TEMP STORAGE DURING NAME SAVE AT INDLOP
global DIRTMP
%define DIRTMP CPMWRM+128 ;USE CPM DEFAULT BUFFER IN LOW MEMORY
global FILNA2
FILNA2:
db 16 dup (?) ;USED BY NAME CODE
db 17 dup (?) ;this is used for FILES in SCP version
global FILNAM
FILNAM:
db 33 dup (?) ;BECAUSE CPM MUST HAVE BUFFER FOR DIRECTORY READS
;
;       CP/M 1.4 and 2.x Support
;
global CPMVRN
CPMVRN:
db 1 dup (?) ;CP/M Version Number (#0 is 2.x)
global CPMREA
CPMREA:
db 1 dup (?) ;CP/M Read Call
global CPMWRI
CPMWRI:
db 1 dup (?) ;CP/M Write Call
db ":" ;a colon for restarting input
global KBUF
KBUF:
times KBFLEN db 0 ;THIS IS THE KRUNCH BUFFER
global BUFMIN
BUFMIN:
db 44 ;A COMMA (PRELOAD OR ROM)
;USED BY INPUT STATEMENT SINCE THE
;DATA POINTER ALWAYS STARTS ON A
;COMMA OR TERMINATOR
global BUF
BUF:
times BUFLEN+1 db 0 ;TYPE IN STORED HERE
;DIRECT STATEMENTS EXECUTE OUT OF
;HERE. REMEMBER "INPUT" SMASHES BUF.
;MUST BE AT A LOWER ADDRESS
;THAN DSCTMP OR ASSIGNMENT OF STRING
;VALUES IN DIRECT STATEMENTS WON'T COPY
;INTO STRING SPACE -- WHICH IT MUST
db 2 dup (?) ;ALLOW FOR SINGLE QUOTE IN BIG LINE
global ENDBUF
ENDBUF:
db 1 dup (?) ;PLACE TO STOP BIG LINES
global TTYPOS
TTYPOS:
db 1 dup (?) ;STORE TERMINAL POSITION HERE
global DIMFLG
DIMFLG:
db 1 dup (?) ;IN GETTING A POINTER TO A VARIABLE
;IT IS IMPORTANT TO REMEMBER WHETHER IT
;IS BEING DONE FOR "DIM" OR NOT
;DIMFLG AND VALTYP MUST BE
;CONSECUTIVE LOCATIONS
global DOL_VALTP
DOL_VALTP:
global VALTYP
VALTYP:
db 1 dup (?) ;THE TYPE INDICATOR
;IN THE 8K 0=NUMERIC 1=STRING
global OPRTYP
OPRTYP: ;USED TO STORE OPERATOR NUMBER
;IN THE EXTENDED MOMENTARILY BEFORE
;OPERATOR APPLICATION (APPLOP)
global DORES
DORES:
db 1 dup (?) ;WHETHER CAN OR CAN'T CRUNCH RES'D WORDS
;TURNED ON IN THE 8K WHEN "DATA"
;BEING SCANNED BY CRUNCH SO UNQUOTED
;STRINGS WON'T BE CRUNCHED.
global DONUM
DONUM:
db 1 dup (?) ;FLAG FOR CRUNCH =0 MEANS
;NUMBERS ALLOWED, (FLOATING,INT, DBL)
;1 MEANS NUMBERS ALLOWED, KRUNCH BY CALLING LINGET
;-1 (377) MEANS NUMBERS DISALLOWED
;(SCANNING VARIABLE NAME)
global CONTXT
CONTXT:
db 2 dup (?) ;SAVED TEXT POINTER USED BY CHRGET
;TO SAVE THE TEXT POINTER AFTER CONSTANT
;HAS BEEN SCANNED.
global CONSAV
CONSAV:
db 1 dup (?) ;THE SAVED TOKEN FOR A CONSTANT
;AFTER CHRGET HAS BEEN CALLED
global CONTYP
CONTYP:
db 1 dup (?) ;SAVED CONSTANT VALTYPE
global CONLO
CONLO:
db 4 dup (?) ;SAVED CONSTANT VALUE
db 4 dup (?) ;EXTRA 4 BYTES FOR DBL PRECISION
global MAXMEM
MAXMEM:
db 2 dup (?) ;Maximum size of BASIC's Data Segment
global MEMSIZ
MEMSIZ:
db 2 dup (?) ;HIGHEST LOCATION IN MEMORY
global TEMPPT
TEMPPT:
db 2 dup (?) ;POINTER AT FIRST FREE TEMP DESCRIPTOR
;INITIALIZED TO POINT TO TEMPST
global TEMPST
TEMPST:
times STRSIZ*NUMTMP db 0 ;STORAGE FOR NUMTMP TEMP DESCRIPTORS
global DSCTMP
DSCTMP:
db 0 ;string descriptor length
global DSCPTR
DSCPTR:
times STRSIZ-1 db 0 ;string descriptor pointer/type
;MUST BE AFTER TEMPST AND BEFORE PARM1
global FRETOP
FRETOP:
db 2 dup (?) ;TOP OF STRING FREE SPACE
global TEMP3
TEMP3:
db 2 dup (?) ;USED TO STORE THE ADDRESS OF THE END OF
;STRING ARRAYS IN GARBAGE COLLECTION
;AND USED MOMENTARILY BY FRMEVL
;USED IN EXTENDED BY FOUT AND
;USER DEFINED FUNCTIONS
;ARRAY VARIABLE HANDLING TEMPORARY
global TEMP8
TEMP8:
db 2 dup (?) ;7/3/79 Now used by garbage collection
;not TEMP3 due to conflict
global ENDFOR
ENDFOR:
db 2 dup (?) ;SAVED TEXT POINTER AT END OF "FOR" STATEMENT
global DATLIN
DATLIN:
db 2 dup (?) ;DATA LINE # -- REMEMBER FOR ERRORS
global SUBFLG
SUBFLG:
db 1 dup (?) ;FLAG WHETHER SUBSCRIPTED VARIABLE ALLOWED
;"FOR" AND USER-DEFINED FUNCTION
;POINTER FETCHING TURN
;THIS ON BEFORE CALLING PTRGET
;SO ARRAYS WON'T BE DETECTED.
;STKINI AND PTRGET CLEAR IT.
global SARYFL
SARYFL:
db 1 dup (?) ;SCANED-ARRAY-FLAG: SET BY PTRGET WHEN
;IT SCANS AN ARRAY ELEMENT.  TESTED BY
;CALL86 SO UNDEFINED SCALERS WON'T
;BE PERMITED AFTER ARRAY REFERENCES
;IN CALL PARAMETER LIST.
global USFLG
USFLG:
global FLGINP
FLGINP:
db 1 dup (?) ;FLAGS WHETHER WE ARE DOING "INPUT"
;OR A READ
global TEMP
TEMP:
db 2 dup (?) ;TEMPORARY FOR STATEMENT CODE
;NEWSTT SAVES [H,L] HERE FOR INPUT AND ^C
;"LET" SAVES VARIABLE
;POINTERS HERE FOR "FOR"
;"NEXT" SAVES ITS TEXT POINTER HERE
;CLEARC SAVES [H,L] HERE
global PTRFLG
PTRFLG:
db 1 dup (?) ;=0 IF NO LINE NUMBERS CONVERTED
;TO POINTERS, NON ZERO IF POINTERS EXIST
global AUTFLG
AUTFLG:
db 1 dup (?) ;FLAG TO INICATE AUTO COMMAND IN
;PROGRESS =0 IF NOT, NON-ZERO IF SO.
global AUTLIN
AUTLIN:
db 2 dup (?) ;CURRENT LINE BEING INSERTED BY AUTO
global AUTINC
AUTINC:
db 2 dup (?) ;THE AUTO INCREMENT
global SAVTXT
SAVTXT:
db 2 dup (?) ;PLACE WHERE NEWSTT SAVES TEXT POINTER
;FOR "RESUME" STATEMENT
global SAVSTK
SAVSTK:
db 2 dup (?) ;NEWSTT SAVES STACK HERE BEFORE
;SO THAT ERROR RECOVERY CAN
;RESTORE THE STACK WHEN AN
;ERROR OCCURS
global ERRLIN
ERRLIN:
db 2 dup (?) ;LINE NUMBER WHERE LAST ERROR OCCURED.
global DOT
DOT:
db 2 dup (?) ;KEEPS CURRENT LINE FOR EDIT & LIST
global ERRTXT
ERRTXT:
db 2 dup (?) ;TEXT POINTER FOR USE BY "RESUME"
global ONELIN
ONELIN:
db 2 dup (?) ;THE LINE TO GOTO WHEN AN ERROR
;OCCURS
global ONEFLG
ONEFLG:
db 1 dup (?) ;ONEFLG=1 IF WERE ARE EXECUTING
;AN ERROR TRAP ROUTINE, OTHERWISE 0
global SAVSEG
SAVSEG:
db 2 dup (?) ;SEGMENT Number Save Area.
global DOL_DPADR
DOL_DPADR:
global TEMP2
TEMP2:
db 2 dup (?) ;FORMULA EVALUATOR TEMP
;MUST BE PRESERVED BY OPERATORS
;USED IN EXTENDED BY FOUT AND
;USER-DEFINED FUNCTIONS
;ARRAY VARIABLE HANDLER TEMPORARY
global OLDLIN
OLDLIN:
db 2 dup (?) ;OLD LINE NUMBER (SETUP BY ^C,"STOP"
;OR "END" IN A PROGRAM)
global OLDTXT
OLDTXT:
db 2 dup (?) ;OLD TEXT POINTER
;POINTS AT STATEMENT TO BE EXECUTED NEXT
global VARTAB
VARTAB:
db 2 dup (?) ;POINTER TO START OF SIMPLE
;VARIABLE SPACE
;UPDATED WHENEVER THE SIZE OF THE
;PROGRAM CHANGES, SET TO [TXTTAB]+2
;BY SCRATCH ("NEW").
global ARYTAB
ARYTAB:
db 2 dup (?) ;POINTER TO BEGINNING OF ARRAY
;TABLE
;INCREMENTED BY 6 WHENEVER
;A NEW SIMPLE VARIABLE IS FOUND, AND
;SET TO [VARTAB] BY CLEARC.
global STREND
STREND:
db 2 dup (?) ;END OF STORAGE IN USE
;INCREASED WHENEVER A NEW ARRAY
;OR SIMPLE VARIABLE IS ENCOUNTERED
;SET TO [VARTAB] BY CLEARC.
global DATPTR
DATPTR:
db 2 dup (?) ;POINTER TO DATA. INITIALIZED TO POINT
;AT THE ZERO IN FRONT OF [TXTTAB]
;BY "RESTORE" WHICH IS CALLED BY CLEARC
;UPDATED BY EXECUTION OF A "READ"
global DEFTBL
DEFTBL:
db 26 dup (?) ;THIS GIVES THE DEFAULT VALTYP FOR EACH
;LETTER OF THE ALPHABET
;IT IS SET UP BY "CLEAR" AND CHANGED BY
;"DEFSTR" "DEFINT" "DEFSNG" "DEFDBL" AND USED
;BY PTRGET WHEN ! # % OR $ DON'T FOLLOW
;A VARAIBLE NAME
;
; RAM STORAGE FOR USER DEFINED FUNCTION PARAMETER INFORMATION
;
global PRMLEN
global PRMLN2
global PRMFLG
global NOFUNS
global PARM1
global TEMP9
global FUNACT
%assign PRMSIZ 100 ;NUMBER OF BYTES FOR DEFINITION BLOCK
PRMSTK:
db 2 dup (?) ;PREVIOUS DEFINITION BLOCK ON STACK
;BLOCK (FOR GARBAGE COLLECTION)
PRMLEN:
db 2 dup (?) ;THE NUMBER OF BYTES IN THE ACTIVE TABLE
PARM1:
times PRMSIZ db 0 ;THE ACTIVE PARAMETER DEFINITION TABLE
global PRMPRV
global PRMSTK ;ALLOW INIT TO INITIALIZE THIS CONSTANT
PRMPRV:
db 2 dup (?) ;INIIALLY PRMSTK,THE POINTER AT THE PREVIOUS PARAMETER
;BLOCK (FOR GARBAGE COLLECTION)
PRMLN2:
db 2 dup (?) ;SIZE OF PARAMETER BLOCK BEING BUILT
global PARM2
PARM2:
times PRMSIZ db 0 ;PLACE TO KEEP PARAMETERS BEING MADE
PRMFLG:
db 1 dup (?) ;USED BY PTRGET TO FLAG IF PARM1 HAS BEEN SEARCHED
global ARYTA2
ARYTA2:
db 2 dup (?) ;STOPPING POINT FOR SIMPLE SEARCH
;(EITHER [ARYTAB] OR PARM1+[PRMLEN])
NOFUNS:
db 1 dup (?) ;ZERO IF NO FUNCTIONS ACTIVE. SAVES TIME IN SIMPLE SEARCH
TEMP9:
db 2 dup (?) ;GARBAGE COLLECTION TEMP TO CHAIN THROUGH PARAMETER BLOCKS
FUNACT:
db 2 dup (?) ;COUNT OF ACTIVE FUNCTIONS
global INPPAS
INPPAS:
db 1 dup (?) ;FLAG TELLING WHETHER INPUT IS SCANNING FIRST OR
;SECOND TIME. ZERO IF FIRST.
global NXTTXT
NXTTXT:
db 2 dup (?) ;USED TO SAVE TEXT POINTER AT START OF NEXT
global NXTFLG
NXTFLG:
db 1 dup (?) ;ZERO IF "FOR" IS USING NEXT CODE
;TO CHECK FOR EMPTY LOOP
global FVALSV
FVALSV:
db 4 dup (?) ;USE TO STORE THE START VALUE OF THE LOOP VARIABLE
;SINCE ANSI SAYS START AND END ARE EVALUATED
;BEFORE ASSIGNMENT TAKES PLACE.
global NXTLIN
NXTLIN:
db 2 dup (?) ;THE LINE NUMBER DURING SCAN FOR "NEXT"
global OPTVAL
OPTVAL:
db 1 dup (?) ;ZERO FOR OPTION BASE 0 ONE FOR OPTION BASE 1
global OPTFLG
OPTFLG:
db 1 dup (?) ;NON-ZERO IF "OPTION BASE" HAS BEEN SCANNED
global TOPTVL
TOPTVL:
db 1 dup (?) ;temp- holds OPTVAL during Chain
global TOPTFG
TOPTFG:
db 1 dup (?) ;temp- holds OPTFLG during Chain
global TEMPA
TEMPA:
db 2 dup (?) ;MISC TEMP USED BY CALL AND LIST
global SAVFRE
SAVFRE:
db 2 dup (?) ;FRETOP SAVED HERE BY CHAIN
global PROFLG
PROFLG:
db 1 dup (?) ;NON-ZERO IF WE HAVE LOADED A PROTECTED FILE W/O PASSWRD
global MRGFLG
MRGFLG:
db 1 dup (?) ;NON-ZERO IF CHAIN W/ MERGE IN PROGRESS
global MDLFLG
MDLFLG:
db 1 dup (?) ;NON-ZERO I CHAIN W/ MERGE AND DELETE IN PROGRESS
global CMEPTR
CMEPTR:
db 2 dup (?) ;POINTER TO END LINE TO DELETE
global CMSPTR
CMSPTR:
db 2 dup (?) ;POINTER TO START LINE TO DELETE
global CHNFLG
CHNFLG:
db 1 dup (?) ;NON-ZERO IF CHAIN IN PROGRESS
global CHNLIN
CHNLIN:
db 2 dup (?) ;DESTINATION LINE IN NEW PROGRAM
global SWPTMP
SWPTMP:
db 4 dup (?) ;VALUE OF FIRST "SWAP" VARIABLE STORED HERE
db 4 dup (?) ;ENOUGH ROOM FOR DBL PRECISION
global TRCFLG
TRCFLG:
db 1 dup (?) ;ZERO MEANS NO TRACE IN PROGRESS
;-------------------------------------------------------------
; THIS IS THE RAM TEMPORARY AREA FOR THE MATH PACKAGE ROUTINES
;-------------------------------------------------------------
global EXPAF
EXPAF:
db 1 dup (?) ;Exponent adjustment factor
;used during E format to adjust exp
;if field overflow occurs
global EXPTMP
EXPTMP:
db 8 dup (?) ;Temp FAC save area used while
;testing FAC for field overflow
;of E formated output
global TEMPB
TEMPB: ;Used by FIELD
global RECRD
RECRD:
db 2 dup (?) ;Record #
global LBUFF
LBUFF:
db 2 dup (?) ;Logical buffer address
global PBUFF
PBUFF:
db 2 dup (?) ;Physical buffer address
global PGTFLG
PGTFLG:
db 1 dup (?) ;PUT/GET flag (Non zero=PUT)
db 1 dup (?) ;DOUBLE PRECISION BUFFER
global DOL_DBUFF
DOL_DBUFF:
db 9 dup (?)
global DOL_FMTCX
DOL_FMTCX:
db 2 dup (?)
global DOL_FMTAX
DOL_FMTAX:
global DOL_FMTAL
DOL_FMTAL:
db 2 dup (?)
db 1 dup (?)
global DOL_ZLO
DOL_ZLO:
db 0
db 6 dup (?)
global DOL_ZX
DOL_ZX:
db 0
global DOL_Z1LO
DOL_Z1LO:
db 7 dup (?)
global DOL_Z1
DOL_Z1:
db 0
; .RADIX	10
;
;THE FLOATING ACCUMULATOR
;
db 1 dup (?) ;[TEMPORARY LEAST SIGNIFICANT BYTE]
db 8 dup (?) ;EXTRA STORAGE FOR D.P. MULTIPLY
global DOL_DFACL
DOL_DFACL:
global DFACLO
DFACLO:
db 4 dup (?) ;FOUR LOWEST ORDERS FOR DOUBLE PRECISION
global DOL_FACLO
DOL_FACLO:
global FACLO
FACLO:
db 2 dup (?)
global DOL_FACM1
DOL_FACM1:
db 1 dup (?)
;[MIDDLE ORDER OF MANTISSA]
;[HIGH ORDER OF MANTISSA]
global DOL_FAC
DOL_FAC:
global FAC
FAC:
db 2 dup (?) ;[EXPONENT]
;[TEMPORARY COMPLEMENT OF SIGN IN MSB]
global DOL_FLGOV
DOL_FLGOV:
global FLGOVC
FLGOVC:
db 1 dup (?) ;OVERFLOW PRINT FLAG,=0,1 PRINT
;FURTHER =1 CHANGE TO 2
global OVCSTR
OVCSTR:
db 1 dup (?) ;PLACE TO STORE OVERFLOW FLAG AFTER FIN
global FLGSCN
FLGSCN:
db 1 dup (?) ;FLAGS INPUT CODE EXECUTING FOR SCNVAL
db 1 dup (?) ;[TEMPORARY LEAST SIGNIFICANT BYTE]
global DOL_ARGLO
DOL_ARGLO:
global ARGLO
ARGLO:
db 7 dup (?) ;[LOCATION OF SECOND ARGUMENT FOR DOUBLE
; PRECISION]
global DOL_ARG
DOL_ARG:
global ARG
ARG:
db 1 dup (?)
global DOL_FBUFF
DOL_FBUFF:
global FBUFFR
FBUFFR:
db 13 dup (?) ;BUFFER FOR FOUT
db 43-13 dup (?) ;THE LAST 3 LOCATIONS ARE TEMP FOR ROM FMULT
global FMLTT1
%define FMLTT1 FBUFFR+40
global FMLTT2
%define FMLTT2 FBUFFR+41
global TSTACK
TSTACK:
; End of the data segment
%assign __RET 0 ;SO WE DON'T GET PHASE ERRORS IN 8086 VERSION
; SUBTTL TEXT CONSTANTS FOR PRINT OUT
;
; NEEDED FOR MESSAGES IN ALL VERSIONS
;
global INTXT
INTXT:	DB" in "
db 0
global REDDY
REDDY:
	DB"Ok"
db 0o377 ;FLAG AS NOT BEING USER INPUT
db 13, 10
db 0
global BRKTXT
BRKTXT:	DB"Break"
db 0
;
; The reserve word tables have dispatch address the could be external.
; ASM86 can only output external declarations during pass 1, so we
; have to construct a chain of possible externals and check each one.
; The following macro runs through the chain and declares any undefined
; addresses as external :NEAR.  For more information, see the file
; PS1:<BASIC.ASM86>BINTRP.H
;
; DO_EXT handled by explicit extern declarations
;
