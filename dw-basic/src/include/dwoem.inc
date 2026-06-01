; DreamWriter GW-BASIC OEM configuration for the NASM port.
;
; This is intentionally not a literal translation of gw-basic/oem.h. The
; original file mixes feature switches, target switches, and MASM helper macros.
; Keep this file limited to build-time feature policy; add syntax-conversion
; macros only when a converted module actually needs them.

%ifndef DW_BASIC_DWOEM_INC
%define DW_BASIC_DWOEM_INC

%include "dwloader.inc"

; Target shape.
%define DW_TARGET_DREAMWRITER 1
%define I8086 1
%define MULSEG 0
%define TRUROM 1
%define PURE 1
%define REALIO 1
%define RSTLES 0
%define SHORTJ 1
%ifndef GW_ENABLE_GRAPHICS
%define GW_ENABLE_GRAPHICS 0
%endif
%ifndef GW_KEEP_DISABLED_STUBS
%define GW_KEEP_DISABLED_STUBS 0
%endif
%ifndef GW_ENABLE_POINTING_DEVICES
%define GW_ENABLE_POINTING_DEVICES (NMPENT | NMSTRT)
%endif
%ifndef DW_DEFAULT_FILE_DRIVE
%define DW_DEFAULT_FILE_DRIVE 0x49 ; "I"
%endif

; Core interpreter policy. These are the features this port is trying to keep.
%define GW 1
%define GIO86 1
%define SCRNIO 1
%define SCRN86 1
%define STRING 1
%define LNGVAR 1
%define FIVEO 1
%define FIVMEM 1
%define FAST 1
%define HEXOCT 1
%define INKEYF 1
%define SWAPSW 1
%define CONTRO 1
%define CONTO 15
%define CLMWID 14
%define LINLN 80
%define LPTLEN 132
%define BUFLEN 255
%define NAMLEN 40
%define NUMLEV 110
%define STRSIZ 3
%define NUMTMP 10
%define T_ON 1
%define T_STOP 2
%define T_REQ 4
%define CONCN2 16
%define CONCON 30
%define OCTCON 11
%define HEXCON 12
%define PTRCON 13
%define LINCON 14
%define IN2CON 15
%define ONECON 17
%define INTCON 28
%define SNGCON 29
%define DBLCON 31
%define DBLCN1 (DBLCON+1)
%define PRMSIZ 100

; GIO device-code absolutes from giotbl's default non-disk device order.
%define DOL__KYBD 0o377
%define DOL__SCRN 0o376
%define DOL__CONS 0o375
%define DOL__LPT1 0o374
%define DOL__NDEV 4

; Screen/editor policy: one 80x8 LCD text page.  The DreamWriter has no
; physical GW-BASIC function-key row, so do not reserve soft-key string slots.
; Use low KEY event slots for DreamWriter key-shaped special keys, but keep the
; classic KEY(11)..KEY(14) cursor-key trap numbering. Pure modifiers are not
; represented by the ROM translated-key API used by KEYINP.
%define NMLINE 8
%define NMPAGE 1
%define SCROLT 0
%define FKEYON 0
%define LABKEY 0
%define NMKEYF 0
%define DW_KEY_EVENT_ESCAPE 0
%define DW_KEY_EVENT_TAB 1
%define DW_KEY_EVENT_ORGN 2
%define DW_KEY_EVENT_INSERT 3
%define DW_KEY_EVENT_BACKSPACE 4
%define DW_KEY_EVENT_RETURN 5
%define DW_KEY_EVENT_WP 6
%define DW_CURSOR_KEY_EVENT_BASE 10
%define NMKEYT 14
%define SUPRSH 0
%define HLPEDT 0
%define DBLCHR 0
%define KANABS 0
%define KANJFN 0
%define JISKTN 0
%define HGHBIT 1
%define ESCCTL 0
%define IBMCSR 0
%define IBMEOL 0
%define IBMLIK 0
%define IBMTOK 0
%define ANSI 0
%define TRUANS 0

; Graphics are deliberately disabled for the first interpreter bring-up.
%define NBANKS 0
%define PALSIZ 0
%define QUEUE 0
%define VIEW 0
%define TILE 0
%define WINDOW 0
%define LINEST 0
%define CLIPPL 0

; File/device backends are deferred. Console and keyboard are provided by the
; DreamWriter shim layer, not by DOS/CP/M device files.
%define DISK 0
%define FIVDSK 0
%define GENDSK 0
%define DOS 0
%define CPM 0
%define CPM2 0
%define CPM86 0
%define SCP 0
%define TIMSHR 0
%define TSDISK 0
%define SPCDSK 0
%define SPCNDS 0
%define BLODSW 0
%define MEMIMG 0
%define GENBIN 0
%define NMLPT 0
%define LPTSW 0
%define FIVLPT 0
%define NCRLPT 0
%define LPT3 0
%define NMCOMT 0
%define DYNCOM 0
%define CONSSW 0
%define GWCASS 0
%define CASSW 0
%define NCRCAS 0

; Optional hardware and event surfaces.
%define PLAYSW 1
%define BEEPSW 1
%define NMPENT 0
%define NMSTRT 0
%define NUMTRP NMKEYT
%define LISTEN 0
%define KEYSTA 0
%define I8251 0

; User machine-access statements. Leave off until we decide how much raw
; DreamWriter hardware access a BASIC program should have.
%define NOIOS 1
%define NOPEKS 1
%define NOUSR 1
%define NOVARP 1

; Compatibility/size switches.
%define LENGTH 2
%define LEN2 1
%define LEN3 0
%define SHORT 0
%define SHTERR 0
%define SHTINS 0
%define SHTLHM 0
%define SHTCHN 0
%define SHTPRO 0
%define SHTLIN 0
%define SHTREN 0
%define SIXDIG 0
%define BINCSW 0
%define NOCTLA 0
%define NORUBT 0
%define NOROMP 1
%define NOATDL 0
%define NODOT 0
%define NOEDIT 0
%define CRONLY 0
%define NONULL 0

; OEM/vendor switches default off.
%define ALPCPM 0
%define ALPS 0
%define BUBL 0
%define CAN8 0
%define CANON 0
%define CMPUTN 0
%define DMC 0
%define DUPONT 0
%define EDIT80 0
%define EXIDY 0
%define GENFLS 0
%define GENWID 0
%define GESBC 0
%define HAL 0
%define HEATH 0
%define IEESLV 0
%define INTDEX 0
%define INTEL 0
%define INTFSW 0
%define INTFHW 0
%define ISC 0
%define ISIS 0
%define LOKHED 0
%define MCI 0
%define MDS 0
%define MDSISS 0
%define MELCO 0
%define MODEL3 0
%define MOSTEK 0
%define NASCOM 0
%define NATROM 0
%define NCRBAS 0
%define NCRDEB 0
%define NCRELS 0
%define NECBAS 0
%define NECPPC 0
%define NNECBS 0
%define OKI 0
%define OLVPPC 0
%define ONTEL 0
%define PANBAS 0
%define PANDBL 0
%define PC8A 0
%define PCS 0
%define RMX 0
%define SBC 0
%define SBC86 0
%define SGS 0
%define SGSATS 0
%define SIRIUS 0
%define TEK 0
%define TETRA 0
%define TRSER2 0
%define TRSHHC 0
%define TSHIBA 0
%define USA 0
%define EUROPE 0
%define XTNSYS 0
%define Z80 0
%define Z80MAC 0
%define ZENITH 0

%include "gwtokens.inc"
%include "gwerrors.inc"

%endif
