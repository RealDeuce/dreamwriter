; Auto-converted mechanically from ../gw-basic/gwram.asm
; Edit the converter or the generated source deliberately; do not hand-wave syntax changes.

; [ This translation created 10-Feb-83 by Version 4.3 ]
; .RADIX  8
%include "dwoem.inc"
; TITLE   GWRAM - GW BASIC OEM Independent RAM Declarations
; COMMENT *
;         --------- --- ---- -- ---------
;         COPYRIGHT (C) 1981 BY MICROSOFT
;         --------- --- ---- -- ---------
%include "gio86u.inc"

; GWRAM RAM-declaration macros reconstructed from the MASM source.
%macro RINIT 2
global %1
%1:
%endmacro

%macro R 2
global %1
%1:
%if %2
times %2 db 0
%endif
%endmacro

%macro R1 2
global %1
%1:
%if %2
times %2 db 0
%endif
%endmacro

%macro PDIRAM 0
%ifndef DW_BASIC_GWRAM_PDIRAM_DONE
%define DW_BASIC_GWRAM_PDIRAM_DONE 1
	RINIT	KEYSW,1
db 0
%endif
%endmacro

%macro PDURAM 0
	R	LINLEN,1
	R	LINCNT,1
	R	CRTWID,1
	R	WDOTOP,1
	R	WDOBOT,1
	R	WDOLFT,1
	R	WDORGT,1
	R	WDTFLG,1
	R	LINTTB,2*(NMLINE+1)
	R	TRMCUR,2
	R	FSTLIN,1
	R	FSTCOL,1
	R	LSTLIN,1
	R	LSTCOL,1
	R	CSRY,1
	R	CSRX,1
%endmacro

; .RADIX	10
%define MUSIC PLAYSW | BEEPSW
%assign GRPMCL 1
%assign NMPAGE 1
global HEDING
global CERMSG
%define QUOTE 0o42
%define CR 0o15
;
; SUBTTL Sign on message and other data to be discarded after INIT
HEDING:	db 13, 10
db "(C) Copyright Microsoft 1982"
DOL_DATE: db "         " ;$DATE
db 13, 10
db 0o00 ;Terminate previous string.
CERMSG:	db 13, 10 ;Command line error message
db "Error detected in command line"
db 13, 10
db 0o00
; End of code segment constants
; Start of data segment GW variables
;
; ASM86 version don't need to fool around with offsets into OEMBAS,
; as the linker can preload segments with data.  Thus, the R macros
; need only define the label and a size if the variable is not intitalized.
;
%assign Q 0
%assign QDS 0
	RINIT	MOVDAT,0
	RINIT	FREFLG,1 ;Flag to print BYTES FREE message
db 0
	RINIT	INITFG,1 ;Initialization complete flag
db 0 ;INITFG
	RINIT	ESCFLG,1 ;Escape seq. in progress flag
db 0
	RINIT	TWOBYT,1 ;Save location for collecting two byte chars
db 0
;
; Keyboard Support Variables
;
	RINIT	STRTAB,16*NMKEYF ;SOFTKEY table
;
;** The following line is used by a source maint. tool - do not remove
;** (OEM FUNCTION KEY DEFINITIONS) **************
;
db "LIST" ;FUNCTION 1
db 0
db 11 dup (?)
db "RUN" ;FUNCTION 2
db CR,0
db 11 dup (?)
db "LOAD" ;FUNCTION 3
db QUOTE,0
db 10 dup (?)
db "SAVE" ;FUNCTION 4
db QUOTE,0
db 10 dup (?)
db "CONT" ;FUNCTION 5
db CR,0
db 10 dup (?)
db "," ;FUNCTION 6
db QUOTE
db "LPT1:"
db QUOTE,0
db 7 dup (?)
db "TRON" ;FUNCTION 7
db CR,0
db 10 dup (?)
db "TROFF" ;FUNCTION 8
db CR,0
db 9 dup (?)
db "KEY" ;FUNCTION 9
db 0
db 12 dup (?)
db "SCREEN 0,0,0" ;FUNCTION :
db CR,0
db 2 dup (?)
;**(END OF DEFINITIONS) *************************
;The preceding line is used by a source maint. tool - do not remove.
;
	RINIT	ENDTAB,0
%define DIST ENDTAB-STRTAB-(16*NMKEYF)
%if DIST
	%OUT/++++BAD SOFTKEY PADDING+++++/
%endif
	RINIT	CMDOFF,2 ;Index into ESCBUFF or STRTAB
dw 0
	RINIT	FKCNUM,1 ;Number of chars. per fun. key to display
db 6 ; on the last line
	RINIT	ACTPAG,1 ;Active page
db 1 dup (?)
	RINIT	F_EDPG,1 ; Flag - =^O377 indicates program statement edit
db 0
	RINIT	SEMFLG,1 ; Flag - non-zero indicates INPUT; statement(no
db 0 ;        CRLF at end of input)
	RINIT	F_CRET,1 ;Zero indicates last character output was CR
db 0o377
	RINIT	F_INST,1 ; Flag - =^O377 indicates insert mode
db 0
	RINIT	F_EDIT,1 ; Flag - non-zero indicates INLIN active
db 0
;
;MACLNG variables for DRAW
;
	RINIT	DRWSCL,1 ;DRAW: SCALE
db 0o00 ;DRAW POS,2 ling factor
	RINIT	DRWFLG,1 ;OPTION FLAGS
db 0o00 ;DRAW flag
	RINIT	DRWANG,1 ;DRAW "ANGLE" (0..3)
db 0o00 ;DRAW translation angle
	RINIT	MCLPTR,2 ;MAC LANG PTR
db 2 dup (?) ;Other DRAW vars. not initialized
	RINIT	MCLLEN,1 ;STRING LENGTH
db 1 dup (?)
	RINIT	MCLTAB,2 ;PTR TO COMMAND TABLE
db 2 dup (?)
;OEM Independent Music Locations
	RINIT	OCTAVE,1 ;PLAY: OCTAVE
db 4 ;OCTAVE
	RINIT	BEATS,1 ;BEATS
db 120 ;BEATS (default = 120 L4 notes per minute)
	RINIT	NOTELN,1 ;NOTE LENGTH
db 4 ;NOTELN
	RINIT	NOTE1L,1 ;One (current) Note Length
db 4 ;NOTE1L
	RINIT	MSCALE,1 ;Note Length Scale Factor (ML,MN,MS)
db 3 ;MSCALE (default = 7/8 time)
	RINIT	MMODE,1 ;Music Mode (Foreground/Background)
db 0 ;MMODE (default = forground)
	RINIT	SNDTIC,1 ;Sound/Clock tick modulo counter
db 1 dup (?)
	RINIT	SNDBAS,2 ;Base addr of Sound Queue Cells
db 2 dup (?)
	RINIT	SNDOUT,2 ;Base addr of Sound Queue Buffer
db 2 dup (?)
; SUBTTL  Page Dependent OEM Independent Variables
; Page Dependent variables arranged as follows:
; Variables which are initialized by block move are declared using the RINIT
; macro.  These declarations are made within the definition of macro PDIRAM
; (page dependent initialized RAM).
; Variables which are not initialized by block move are declared using the R
; macro.  These declarations are made within the definition of macro PDURAM
; (page dependent uninitialized RAM).
; The memory map for multi page page dependent variables is as follows:
;--------------------------------------------------------------------------
;
; CS: resident initialization values are copied to DS: by the same copy
;     as usual.
;
;--------------------------------------------------------------------------
;
; DS:PDIDS1:              ;Beginning of ini value block copied from CS:
;                         ; This block is used to initialize pages at
;                         ; various times during execution.
;
;           (initialization values set by CS: to DS: block move)
;
; DS:FPDVAR:              ;First page dependent variable
;
;           (first come vars initializable by block move from PDIDS1.
;            Then come all other vars. which are page dependent.)
;
; DS:LPDVAR:              ;Address of end of variables for active page
;                         ; The variables between FPDVAR and LPDVAL are the
;                         ; ones that are labeled as per RINIT and R macros.
;
; (Lastly comes (LPDVAR-FPDVAR)*NMPAGE RAM locations used to store the state
;   of each page while it is not active.)
;
;In systems where only one page is available label FPDVAL is made to
; coincide with label PDIDS1 and there are no locations reserved to store
; the state of the page while it is not active.
;
global PDIDS1 ;Start of DS: init block.
global FPDVAR
global LPDVAR ;Addresses of first and last active page vars in DS:
%define QDS Q
	R	PDIDS1,0 ;Page Dependent DS: init. value block start
	PDIRAM ;Insert Ini values
FPDVAR equ PDIDS1 ;INI area and First Page Dependent VARiable
; are overlaid in this case
;Although RINIT is used subsequently there are no more CS: RAM locations
; to declare.   The RINIT will be used for DS: declaration only
;
;
; Now declare the labeled DS: for 1 page systems.  This area is the
;       labeled active page for multi-page systmes
;
	PDIRAM ;Declare Active Page Inited RAM
;
	PDURAM ;Declare Active Page Uninit RAM
	R	LPDVAR,0 ;End of active page vars in DS:
;
;Now put back the R macro for use by Page Independent Uninitialized RAM
; declarations.
;
;P.I.U. RAM MUST be declared after all P.D.U. RAM, P.D.I. RAM,
; and P.I.I. RAM.
;
; SUBTTL  Page Independent Uninitialized RAM Location Definitions
;OEM Independent Graphics Locations
;
	R	GRPACX,2 ; Previous X Coordinate
	R	GRPACY,2 ; Previous Y Coordinate
	R	ATRBYT,1 ;Attribute Byte to Store
	R	GXPOS,2 ;X Position of Second Coordinate
	R	GYPOS,2 ;Y Position of Second Coordinate
	R1	MAXUPD,2 ;Address of Major Axis Move Update
	R1	MINUPD,2 ;Address of Minor Axis Move Update
	R	MAXDEL,2 ;Largest Delta for Line
	R	MINDEL,2 ;Smaller of 2 Deltas for Line
	R	ASPECT,2 ;ASPECT RATIO
	R	CENCNT,2 ;END CIRCLE POINT COUNT
	R	CLINEF,1 ;LINE-TO-CENTER FLAG
	R	CNPNTS,2 ;1/8 NO. OF PTS IN CIRCLE
	R	CPLOTF,1 ;PLOT FLAG
	R	CPCNT,2 ;1/8 NO. OF PTS IN CIRCLE
	R	CPCNT8,2 ;NO. OF PTS IN CIRCLE
	R	CRCSUM,2 ;CIRCLE SUM
	R	CSTCNT,2 ;START COUNT
	R	CSCLXY,1 ;FLAG WHETHER ASPECT WAS .GT. 1
	R	CSAVEA,2 ;ADVGRP C save area
	R	CSAVEM,1 ;ADVGRP C save area
	R	CXOFF,2 ;X OFFSET FROM CENTER SAVE LOC
	R	CYOFF,2 ;Y OFFSET SAVE LOCATION
	R	LOHMSK,1 ;RAM SAVE AREA FOR LEFT OVERHANG
	R	LOHDIR,1 ;*** LOHMSK & LOHDIR MUST BE CONTIG !
	R	LOHADR,2
	R	LOHCNT,2
	R	LFPROG,1 ;PAINT: SCAN LINE ALREADY PAINTED FLAGS
	R	RTPROG,1
	R	SKPCNT,2 ;SKIP COUNT
	R	MOVCNT,2 ;MOVE COUNT
	R	PDIREC,1 ;PAINT DIRECTION
	R	PUTFLG,1 ;WHETHER DOING PUT() OR GET()
	R	QUEINP,2
	R	QUEOUT,2
	R	PSNLEN,2 ;Queue present length
	R	QUELEN,2 ;Maximum queue length
	R	SAVLEN,2 ;used by BLOAD, BSAVE
;
;Device Variables
;
global FOPTSZ
%assign FOPTSZ 64 ;size of file open options buffer
	R	FILOPT,FOPTSZ ;buffer for Special-Device Open Options
;
;Line Printer variables
;
;       note: If size of LPT Device Control Block changes,
;             routine GLPDCB in GIOLPT must be changed.
;
	R	LP1DCB,4*NMLPT ;LPT1 device control block
;2 bytes (width, position)
;
;Keyboard variables
;
global KYBQSZ
KYBQSZ equ 32
	R	KYBQDS,8 ;queue descriptor (for format see GIO86)
	R	KYBQUE,KYBQSZ ;buffer circular key queue
;
;RS232C variables
;
	R	MSWSIZ,2 ;/M: value
	R	MSWFLG,1 ;/M: exists flag
	R	CSWSIZ,2 ;/C: value
	R	CSWFLG,1 ;/C: exists flag
	R	NEWDS,2 ;New DS:
	R	COMDSC,18 ;buffer used to communicate RS232 requests to OS
	R	CM1DCB,24*NMCOMT ;COM1 device control block (24 bytes per device)
	R	LSTIOB,1 ;Contains Last RS232 unit accessed (0..15)
;2 bytes (width, position)
;2 bytes (width, position)
;
; RAM USED FOR EVENT TRAPPING
;
	R	TRPTBL,3*NUMTRP ;trap table - see GWSTS
	R	ONGSBF,1 ;see NEWSTT
	R	SOFTKY,1 ;used by key trapping in GWSTS
	R	F_SUPR,1 ; Flag - non-zero =  super shift expansion
