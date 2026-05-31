; Auto-converted mechanically from ../gw-basic/giokyb.asm
; Edit the converter or the generated source deliberately; do not hand-wave syntax changes.

; [ This translation created 10-Feb-83 by Version 4.3 ]
; .RADIX  8
%include "dwoem.inc"
; TITLE   GIOKYB - Machine Independent Keyboard Device Driver Code
; COMMENT *
; 
; --------- --- ---- -- ---------
; COPYRIGHT (C) 1982 BY MICROSOFT
; --------- --- ---- -- ---------
; 
%include "gio86u.inc"
;Generic Switches
;
%define CPM86 0o0
%define IBMCSR IBMLIK ;IBM compatible cursor interface
;OEM Switches
;
%define MELCO 0o0
%define COMPAQ 0o0
;Local switches
%define INTHND SCP & GW
%include "msdosu.inc"
global KYBDSP
global KYBINI
global KYBTRM
extern SCNSWD
extern SCNGWD
extern SCNSOT
extern SCNGPS
extern SCNGCW
extern SCNSCW
extern MAKINT
extern INIFDB
extern DERBFM
extern INITQ
extern GETQ
extern PUTQ
extern DEVBIN
extern DEVBOT
extern SCNBRK
extern EDTBRK
%assign CTLBRK 65283 ;&HFF03 is Ctl-Break
%assign CTLPAS 65299 ;&HFF13 is Ctl-Pause
; Keyboard Data-Flow/Control-Structure for GIO86:
;
;    PLAY, LIST, NEWSTT                                            INCHRI
;    --------+---------                                      (fixed length input)
;            !                                   INLIN               !
;            !                              (Screen Editor)     KYBSIN/CHGET
;         CHKINT                                   !        (Device Indep. input)
;     +-------------+                              !                 !
;     !             !                              +-----------------+
;     !             !                                       !
;     !             !                  INKEY$             KEYIN
;     !           POLKEY                 !                  !
;     !             !                    +--------------+---+
;     !        +----+--------+-------+                  !
;     !        !    !        !       !                CHSNS (get 1 KEY {may be 2 bytes}
;     !        !  CNTCCN  KEYTRP  PKEYQ                 !    function key expansion)
;     !        !    !                !      ------+     !
;     !        +----+              PUTQ --> ! ! ! !--> CONIN (get 1 byte from queue)
;     !             !                       ------+
;  POLLEV         KEYINP(OEM supplied)      (queue)
;(OEM supp.)      (maps to MS Univ keyboard)
;(test for trapable event)
;Keyboard Dispatch Table
;
KYBDSP:
dw (KYBEOF) ;test EOF for file opened to this device
dw (KYBLOC) ;LOC
dw (KYBLOF) ;LOF
dw (KYBCLS) ;perform special CLOSE functions for this device
dw (SCNSWD) ;set device width
dw (DERBFM) ;GET/PUT random record from/to this device
dw (KYBOPN) ;perform special OPEN functions for this device
dw (KYBSIN) ;input 1 byte from file opened on this device
dw (SCNSOT) ;output 1 byte to file opened on this device
dw (SCNGPS) ;POS
dw (SCNGWD) ;get device width
dw (SCNSCW) ;set device comma width
dw (SCNGCW) ;get device comma Width
dw (DEVBIN) ;block input from file opened on this device
dw (DEVBOT) ;block output to file opened on this device
; SUBTTL Keyboard Primitive I/O Routines
extern BCHRSI
;KYBINI puts the keyboard device server in an initial state.
; It is called at initialization time and after CTL-C.
; On exit, all registers are preserved.
;
extern FINPRT
extern PDCBAX
extern KYBQDS
extern KYBQUE
extern KYBQSZ
KYBINI:
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSHF
	PUSH	SI
	XOR	AX,AX
	MOV word [CMDOFF], AX ;[CMDOFF]=0 (no soft key)
	MOV	SI,KYBQDS ;SI = keyboard queue descriptor
	MOV	BX,KYBQUE ;BX points to 1st byte of queue buff
	MOV	AX,KYBQSZ ;AX = size of keyboard queue
	CALL	INITQ ;Initialize keyboard queue
	CALL	FINPRT ;reset PTRFIL to Keyboard/CRT
	POP	SI
	POPF
	JMP	PDCBAX ;POP DX, CX, BX, AX and return
global KYBCLR
;KYBCLR - Clear the keyboard buffer
;This routine has been documented to OEMs.  The routine is intended to support
;the IBM poke which clears the keyboard buffer.
;Entry - none
;Exit  - none
;        Segment registers and stack preserved.
;
KYBCLR:	CALL	KYBINI ;Initialize the keyboard buffer
	RET
;KYBEOF - test for End-Of-File on device.
; Entry - SI points to File-Data-Block.
; Exit  - [BX] = -1 if EOF, 0 if not EOF
;
extern INCHSI
KYBEOF:	XOR	BX,BX ;0 means not at eof
	OR	SI,SI
	JZ	KBEOFX ;branch if not pseudo keyboard FDB
	CALL	INCHSI ;[AL]=next byte from keyboard
	JB	YKYEOF ;branch if next key = CTL-Z
	CALL	BCHRSI ;put this back in queue
KBEOFX:	RET
YKYEOF:	DEC	BX ;BX=-1, end-of-file is true
KYBTRM:	RET
;KYBLOC - Number of Bytes in input buffer for KEYBOARD device.
; Entry - SI points to File-Data-Block.
; Exit  - [BX] = result.
;
KYBLOC:	PUSH	SI ;save FDB pointer
	MOV	SI,KYBQDS ;SI points to KYB queue descriptor
extern NUMQ
	CALL	NUMQ ;[AX]=number of bytes queued in KYB Q
	POP	SI
	MOV	BX,AX ;return result in BX
	TEST	byte [F_FLGS+SI],FL_BKC
	JZ	KYLOCX ;branch if char not backed up
	INC	BX
KYLOCX:	RET
;KYBLOF - number of bytes free in KEYBOARD input buffer.
; Entry - SI points to File-Data-Block.
; Exit  - [Floating-Point-Accumulator] = result.
;
KYBLOF:	MOV	SI,KYBQDS ;SI points to KYB queue descriptor
extern LFTQ
	CALL	LFTQ ;[AX]=number of bytes free in KYB Q
	MOV	BX,AX
	JMP	MAKINT ;return result in FAC
;KYBCLS - perform any device dependent close functions.
; Entry - SI points to File-Data-Block.
; Exit  - All registers preserved.
;         This routine is called before BASIC releases the
;         file-data-block associated with this file.
;
KYBCLS:
RET11:	RET
;KYBOPN - perform any device dependent open functions.
; Entry - [AL]=  device id
;                0 if default device,
;                1..n for Disk A:, B:, ...
;                -1..-n for non-disk devices
;         [BX] = file number (0..n)
;         [CX] = random record size if [FILMOD] = random
;                (if [CX] = 0, use default record size)
;         [DI] = device offset (2=KYBD, 4=SCRN, etc.)
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
KYBOPN:
	MOV	AH,MD_SQI ;allow input only
extern FILMOD
	CMP byte [FILMOD], MD_RND
	JNZ	KYBOPX ;Leave the mode as it is
	MOV byte [FILMOD], AH ;Force the mode to INPUT
KYBOPX:
	JMP	INIFDB
;KYBSIN - Sequential Input.
; Entry - SI points to File-Data-Block.
; Exit  - [AL] = next byte from Keyboard File
;         carry set if EOF (CTL-Z read) (only if SI points to FDB (non 0))
;         (Note: SI must be preserved for KYBEOF to work)
;         All other registers preserved
;
global KYBSIN
global INCHRI
global CHGET
extern SAVKEY
extern SAVKYF
extern SCNPOS
INCHRI:
extern INFMAP
	MOV AL, byte [SAVKEY]
	CMP byte [SAVKYF], 0
	MOV byte [SAVKYF], 0
	JNZ	KBSINX ;Send second bytes through unfiltered
KEYGET:
	STC
	CALL	STCTYP ;Set new cursor type to user mode (PSW.C set)
	CALL	KEYSIN ;Read a key from the OS (could be a null fkey)
	CALL	INFMAP ;OEM fixed length input map routine
	JZ	KEYGET ;OEM filtered out the key - get the next
	JMP	KYBSI2 ;Process as other keys
CHGET:
KYBSIN:	MOV AL, byte [SAVKEY]
	CMP byte [SAVKYF], 0
	MOV byte [SAVKYF], 0o0 ;clear 2nd-byte of 2-byte sequence flag
	JNZ	KBSINX ;branch if 2nd-key of 2-byte sequence
	CALL	STCTYP ;Set to insert or overwrite cursor (PSW.C reset)
	CALL	KEYIN ;[AX]=next character from keyboard
KYBSI2:
	JB	KBSIN2 ;branch if got 2-byte sequence (f-key/KANJI)
	PUSHF
	OR	SI,SI
	JZ	KB1X ;branch if no FDB
	CMP	AL,ASCCTZ ;CTL-Z=eof for keyboard
	JNE	KB1X ;branch if not EOF
	POPF
	STC ;return EOF indication
	JMP	KBSINX
KB1X:	POPF
	JMP	KBSINX
KBSIN2:
	MOV byte [SAVKEY], AL ;save 2nd byte of 2-byte sequence
	MOV byte [SAVKYF], 255 ;Set saved key flag
	XCHG	AH,AL ;return 1st byte to user
	CLC ;clear carry (not EOF)
KBSINX:	RET
;KEYIN turns cursor on if no key is available.
; It then waits for key from keyboard (if one wasn't already there).
; Exit - if Z is true, no key was ready, else [AX]=key
;        if C is true, returns 16 bit character
;        Soft keys are expanded if not being trapped, and not null.
;        if NZ AND NC AND [AL] = FF then a two byte character is returned
;               in DX.  The character is an OEM specific special character.
;        All other registers are preserved.
;
global KEYIN
KEYIN:
IGNNFK:	CALL	KEYSIN ;Get a key (possibly a null function key)
	PUSHF
	JAE	NOTNFK ;branch if not 2-byte key code
	CMP	AH,0o200
	JNE	NOTNFK ;branch if definitely not a null Function key
	CMP	AL,0o40
	JB	NOTNFK ;branch if definitely not a null Function key
	CMP	AL,0o101
	JAE	NOTNFK ;branch if definitely not a null Function key
	POPF
	JMP	IGNNFK ;ignore null Function key
NOTNFK:	POPF
	RET
;KEYSIN - Get a key.  This routine will return null function keys.
;Entry - none
;Exit  - PSW.C set indicates a two byte key code
;
KEYSIN:	CALL	CHSNS ;try to get next key
	JNE	KEYINX ;Return with key if there is one.
	PUSH	DX
	CALL	SCNPOS ;[DH]=1 relative column (cursor position)
;[DL]=1 relative line
	CALL	SETCSR ;Set the cursor
	POP	DX
CHWAIT:	CALL	CHSNS ;Has a key been typed?
	JE	CHWAIT ;No, wait
KEYINX:	PUSHF
	PUSH	AX
	MOV byte [CSRTYP], 3 ;Indicate user cursor
	CALL	SETCSR ;Set the cursor
	POP	AX
	POPF
	RET
; SUBTTL  Keyboard Interrupt/Trap Checking in an Operating System Environment
;POLKEY is called from several places in BASIC to "poll" the keyboard.
; Exit - DI is used.  All other registers are preserved.
;        If CTL C was typed, Control does not return to caller.
;
; Function:
;       get key from operating system
;       while keyboard data is ready to be read begin
;         get key
;         if key is CTL-C, reset soft-key pointer, key-queue, AUTFLG, SEMFLG
;            call SNDRST to reset background sound,
;            and exit to CNTCCN (resets stack and jumps to STOP)
;         if key is CTL-S, pause until non-CTL-S key is pressed
;         if key is 1st byte of Function Key, continue getting keys
;            until it definitely is or is not a function key.
;         if it was a function key then begin
;            if trapping is enabled then
;               trap it
;            else
;               queue function key code for CHSNS
;            end {it was a function key}
;         else {it was not a function key}
;           queue key for CHSNS
;       end {while keyboard data ready}
;
global POLKEY
extern KEYTRP
extern KEYINP
extern AUTFLG
extern SEMFLG
extern SAVSTK
extern SAVTXT
POLKEY:	PUSH	DI
	PUSHF
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
GETKLP:
extern MSDCCF ;MSDOS Ctl-C Interrupt flag
	TEST byte [MSDCCF], 255
	JNZ	ITSCTC ;Branch if Ctl-C interrupt detected
	CALL	KEYINP ;[AX]=next key from keyboard if one exists
	JE	POLKXI ;branch if no key present
	JAE	NOTTWO ;branch if not 2-byte key sequence
	CMP	AH,255 ;Test for control function range
	JNZ	NTCTLFN ;Not a control function
	CALL	TRPCHK ;Check for trapping in this range
	JNZ	GETKLP ;Trap set - get next key
NTCTLFN:
	CMP	AH,128
	JNE	NOTFUN ;branch if not function key
	PUSH	AX ;save key-code
	SUB	AL,32 ;[AL]=0 for 1st function key
	CMP	AL,NMKEYT ;see if its a trapable function key
	JAE	NOFUN1 ;branch if not
	CALL	KEYTRP ;Trap key if event is ON
	POP	AX ;restore key code
	JNZ	GETKLP ;branch if Key was trapped (don't queue)
	JMP	NOTFUN ;Not trapped function key (queue key)
POLKXI:	JMP	POLKYX
NOFUN1:	POP	AX ;Restore key code
NOTFUN:
	CMP	AX,CTLBRK ;check for Ctl-Break
	JE	ITSCTC ;branch if CTL C
	CMP	AX,CTLPAS
	JE	ITSINT ;branch if CTL S
NOTRAP:
	PUSH	AX
	CALL	LFTQ ;[AX]=number of bytes free in KYB Q
	CMP	AX,3 ;Test for space in keyboard queue
	POP	AX ;Restore key code
	JB	GETKLP ;Loop for next key (interrupt?)
	XCHG	AH,AL
	CALL	PKQUE ;append 1st byte of sequence to key queue
	XCHG	AH,AL
	JMP	QUEKEY ;append 2nd byte of sequence to key queue
NOTTWO:
	CMP	AL,254 ;Test for three byte char (IBM "scan codes")
	JNZ	QONEBT ;Queue a one byte character
	PUSH	AX
	CALL	LFTQ ;[AX]=number of bytes free in KYB Q
	CMP	AX,4 ;Test for space in keyboard queue
	POP	AX ;Restore key code
	JB	GETKLP ;Loop for next key (interrupt?)
	CALL	PKQUE ;Queue the first byte
	MOV	AX,DX ;Get second and third bytes
	JMP	NOTRAP ;Go queue the second and third bytes
QONEBT:
	JMP	QUEKEY ;else queue the key for CHSNS
ITSCTC:
	CALL	KYBINI ;clear keyboard queue, reset PTRFIL
	MOV byte [MSDCCF], 0 ;Reset Ctl-Break interrupt flag
extern SNDRST
	CALL	SNDRST ;reset background music
	MOV SP, word [SAVSTK] ;[SP]=SP of interrupted statement
	MOV BX, word [SAVTXT] ;[BX]=text pointer of interrupted stmt
	MOV	AX,CTLBRK ;[AX]=Key Code for BREAK (CTL-C)
ITSINT:	CALL	CNTCCN ;process CTL C or S
	JMP	GETKLP ;dont queue CTL-S or CTL-C
QUEKEY:	CALL	PKQUE ;queue key [AL] for CHSNS
	JMP	GETKLP ;get next key
;At this point, Keyboard input queue from OS is flushed.
;
POLKYX:	POP	DX ;restore caller's registers
	POP	CX
	POP	BX
POLKXX:	POP	AX
	POPF
	POP	DI
RET8:	RET
;TRPCHK - Check for key trapping
;Entry - AX = key code
;Exit  - PSW.Z set indicates key was not trapped
;
TRPCHK:	PUSH	AX ;Save key code
	MOV	BX,TRPKTB-0o1 ;BX points before 1st byte of key trap table
CHKTRP:	INC	BX
	MOV	AH,byte [CS:BX+0o0]
	INC	BX ;BX points to Trap Key ID for key [AH]
	OR	AH,AH ;test for end-of-table
	JE	NTRAP ;branch if not a trappable key
	CMP	AH,AL
	JNE	CHKTRP ;branch if they don't match (continue search)
	MOV	AL,byte [CS:BX+0o0] ;[AL]=key-trap id
	CALL	KEYTRP ;Trap key if event is ON
NTRAP:	POP	AX ;Restore key code
	RET
; SUBTTL  CHKKYB - OEM Version of POLKEY
;CHKKYB - This is the OEM version of POLKEY.  It is documented to the OEM as
;the way to check for keyboard interrupts.
;Entry - All segment registers must be set
;        to the BASIC configuration
;Exit  - All registers and PSW preserved
;
global CHKKYB
CHKKYB:	PUSH	SI
	PUSH	BP ;For safety
	CALL	POLKEY
	POP	BP
	POP	SI
	RET
; SUBTTL  CNTCCN, PKQUE, TRPKTB
;CNTCCN performs special action upon receipt of CTL-S or CTL-C
;
extern CTRLPT
extern STOP
CNTCCN:
	CMP	AX,CTLPAS ;check for PAUSE
	JNZ	NOTCTS ;branch if not
GOTCTS:	CALL	KEYINP
	JZ	GOTCTS ;wait for resume key (anything but CTL S)
	CMP	AX,CTLPAS ;check for PAUSE
	JE	GOTCTS ;branch if got another CTL-S
NOTCTS:
	CMP	AX,CTLBRK ;check for Ctl-Break
	JNE	RET8 ;return if not CTL-C
	CALL	EDTBRK ;Clear editor flags and position cursor
	CALL	SCNBRK ;Clear flags associated with screen driver
	PUSH	AX
	CALL	FINPRT ;Reset I/O
	POP	AX
	MOV AX, word [CURLIN] ;Print "BREAK" message in program mode only
	AND	AL,AH ;AL=^D255 if direct mode
	XOR	AH,AH ;Set PSW.Z so STOP won't give Syntax Error
	JMP	STOP
;PKQUE appends [AL] to the keyboard circular queue
;
PKQUE:	PUSH	SI
	MOV	SI,KYBQDS ;SI = keyboard queue descriptor
	CALL	PUTQ ;append [AL] to keyboard queue (read by CHSNS)
	POP	SI
	RET
;Keyboard Trap Table (for KEY TRAPPING of non-soft keys)
; Referenced by POLKEY
;
TRPKTB:
db 30,NMKEYF+0o0 ;ON KEY (Cursor Up)
db 29,NMKEYF+0o1 ;ON KEY (Cursor Left)
db 28,NMKEYF+0o2 ;ON KEY (Cursor Right)
db 31,NMKEYF+0o3 ;ON KEY (Cursor Down)
db 0o0 ;end-of-table
; SUBTTL  Machine independent Keyboard input routines CHSNS, INKEY$
global CHSNS
extern CMDOFF
extern STRTAB
;Get key from keyboard if one is ready.
;Exit  - if Z is true, no key was ready, else [AX]=key
;        if C is true, returns 16 bit character
;        Soft keys are expanded if not being trapped, and not null.
;        if NZ AND NC AND [AL] = FF then a two byte character is returned
;               in DX.  The character is an OEM specific special character.
;        All other registers are preserved.
;
CHSNS:	PUSH	BX ;save caller's registers
	PUSH	CX
	PUSH	SI
	PUSH	DI
CHSNSI:	XOR	DL,DL ;clear high byte of 2-byte sequence
CHSNS0:	CALL	CONIN ;check for SOFTKEY
	JNZ	CHSNSS ;BRIF key found
	OR	DL,DL
	JZ	CHSNSX ;BRIF no key sensed and not 2nd of 2 bytes
	JMP	CHSNS0 ;BRIF need 2nd byte of 2 byte character
CHSNSS:	OR	DL,DL
	JNZ	CHSNS2 ;BRIF 2nd byte of 2 byte character
	CALL	CKDBLK ;see if this is the 1st byte of 2-byte seq
	JAE	CHSNG1 ;branch not
	MOV	DL,AL ;Put first byte in [DL]
	JMP	CHSNS0 ;Go get 2nd byte
CHSNS2:	MOV	AH,DL ;Put 1st byte in [AH]
	CMP	AH,0o200 ;Check for 8080 code which represents single 80
	JNZ	CHSN2A
	CMP	AH,AL
	JZ	CHSNG1 ;Return 80 for 8080 char code
CHSN2A:	CALL	CHKFKY ;see if AX is a non-null function key
	JZ	CHSNS3 ;BRIF not a string key that needs expansion
	JB	CHSNG1 ;BRIF is super shift key(return first byte now)
	MOV byte [F_SUPR], 0o0
	JMP	CHSNSI ;Is string key, get first expansion and return
CHSNS3:
	OR	AH,AH ;else NZ, C Indicates 2 byte character
	STC
	JMP	CHSNSX
CHSNG1:	OR	AL,AL ;set NZ, no-carry (got 1 byte)
	MOV	AH,0o0 ;high-byte = 0 for single byte characters
;Check for 3 byte sequence case
	PUSHF
	CMP	AL,254 ;Test for three byte sequence
	JNZ	CHSNG2 ;Not a three byte sequence
	PUSH	AX ;Save first byte
	CALL	CONIN ;Get second byte
	MOV	DH,AL
	CALL	CONIN ;Get third byte
	MOV	DL,AL
	POP	AX ;Restore third byte
CHSNG2:	POPF
CHSNSX:	POP	DI
	POP	SI
	POP	CX
	POP	BX
	RET
CKDBLK:
;Check for function key (80,nn)
	CMP	AL,0o200 ;First check for 80,nn key
	STC
	JE	CKDBLX ;branch if 1st of 2-byte sequence
	CMP	AL,255
	STC
	JE	CKDBLX ;BRIF 1st byte of two byte control function
	CLC
CKDBLX:	RET
;CONIN gets the next key from the soft-key being expanded (if any).
; If no soft-key is active, it calls POLKEY to get and queue key from OS,
; afterwhich it trys to get a key from the keyboard queue.
; On exit, Flags.Z is set if no key is ready, else [AL]=key
;
CONIN:	PUSH	BX
	CALL	GETFKY ;expand soft-key if active
	JNZ	CONINX ;branch if expanding soft-key
	PUSH	SI
	CALL	POLKEY ;try to get and queue key from OS
	MOV	SI,KYBQDS
	CALL	GETQ ;[AL]=next key from keyboard queue
	POP	SI
CONINX:	POP	BX
	RET
;Returns with FLAGS.NZ if AX is Universal key code for non-null Soft-key
;Also sets FLAGS.NC for softkey and FLAGS.C for super shift key
;       (note that for super shift the first character is in AL and must
;           be returned)
;
CHKFKY:	CMP	AH,0o200
	JNE	NTFKYX ;branch if not soft-key
	PUSH	AX
	SUB	AL,32
	JB	NTFKY1 ;branch if not soft-key
	CMP	AL,NMKEYF
	JAE	NTFKY1 ;branch if not soft-key
	MOV	BL,16 ;else, tell CHSNS to expand soft-key
	MUL	BL ;[AX]=16 * function-key id
	ADD	AX,STRTAB ;Get soft-key address
	MOV word [CMDOFF], AX ;save soft-key pointer for soft-key expansion
	MOV	BX,AX
	POP	AX
	CMP	byte [BX+0o0],0o0 ;set FLAGS.Z if null soft-key (and FLAGS.NC
	RET ; not super shift)
NTFKY1:
	JB	NTFKY9 ;BRIF not super shift key
	POP	AX
	PUSH	AX
	CMP	AL,"A"
	JB	NTFKY9 ;BRIF not super shift key
	CMP	AL,"Z"+0o1
	JB	SUPRKY ;BRIF is super shift key
NTFKY9:
	POP	AX
NTFKYX:	XOR	BL,BL ;set FLAGS.Z - not soft-key(and FLAGS.NC not
	RET ;super shift)
extern MAPSUP
extern ALPTAB
extern F_SUPR
SUPRKY:
extern CURLIN
	CMP word [CURLIN], 65535 ;Test for direct mode
	JNZ	NTFKY9 ;Not direct mode - don't expand Supershift key
	PUSH	CX
	CALL	MAPSUP ;Map super shift key to letter in AL and count
	XOR	CL,CL ;Interface doc says CH contains count
	JCXZ	SUPKY9 ;Request to inhibit SKey expansion
	SUB	AL,"A" ; in CH
;Scan for CHth reserved word in table that includes words starting with letter
;in AL
;Set up for CONIN to return the reserved word letters one at a time and return
;AL now.
	MOV	BH,0o0
	MOV	BL,AL
	ADD	BL,AL
	PUSH	BX ;Save ALPTAB offset
	ADD	BX,ALPTAB
SUPKY0:
	MOV	BX,word [CS:BX+0o0] ;Get start of reserved words for this letter
SUPKY1:
	TEST	byte [CS:BX+0o0],0o377
	JZ	SUPKYZ ;BRIF did not find super key definition(abort)
	DEC	CH
	JZ	SUPKYX ;BRIF found the reserved word
	DEC	BX
SUPKY2:	INC	BX
	TEST	byte [CS:BX+0o0],0o377
	JNS	SUPKY2 ;BRIF not at the end of this reserved word
	INC	BX ;Skip end of string
	INC	BX ;Skip token value
	JMP	SUPKY1 ;Check next reserved word
;Found the reserved word
SUPKYX:	MOV word [CMDOFF], BX ;Set up for string key input
	DEC	CH
	MOV byte [F_SUPR], CH ;Set super shift key flag
	POP	BX
SUPKY9:	POP	CX
	POP	AX
	OR	AX,AX ;Set FLAGS.NZ
	STC ;Else return AL=first char, FLAGS.NZ and
	RET ;FLAGS.C When key not found then single char
; returned as first expansion character.  No
;expansion takes place since expansion table
;not initialized.
;Did not find reserved word in ALPTAB, perhaps its in ALPTAX
extern ALPTAX
SUPKYZ:	POP	BX
	OR	BH,BH
	JNZ	SUPKY9 ;BRIF already checked ALPTAX, exit
	PUSH	CX ;Put non-zero high byte on stack(so above
; branch is taken)
	ADD	BX,ALPTAX
	JMP	SUPKY0 ;Continue scan of reserved words
;GETFKY: Called to retrieve a character from the SOFTKEY buffer.
;Supershift key strings are expanded to end in a space unless the last character
; is a "(" or if the token is $FN or $USR.
;
; Entry - CMDOFF is the index into the buffer
;         F.SUPR = ^O0   - not a supershift softkey
;                  ^O377 - Supershift (CMDOFF points to character)
;                  Other - Supershift (F.SUPR is the next character)
; Exit  - flags.Z set   - no key available
;                 reset - AL contains character
;         BX is used.
;
GETFKY:	CMP word [CMDOFF], 0 ;Softkey available?
	JZ	GETFKX ;No special key available
	CALL	GTSFKY ;Get a softkey
	CALL	EOKTST ;Test for end of softkey
GETFKX:	RET
GTSFKY:	MOV BX, word [CMDOFF] ;Get char. offset
	MOV AL, byte [F_SUPR] ;Get super-shift flag
	TEST	AL,0o377 ;Super-shift key in progress?
	JZ	NOTSUP ;Not a super-shift key
	CMP	AL,0o377 ;F.SUPR is ^O377 or current character
	JNZ	GTSFKX ;Got the key
;Super-shifts are in the CS:
db 2EH ; Code segment override
NOTSUP:	MOV	AL,byte [BX+0o0] ;Get next character
	XOR	AH,AH ;Clear high byte
	INC	BX ;Index to next key
GTSFKX:	RET
EOKTST:
	TEST byte [F_SUPR], 0o377 ;Super-shift key expansion?
	JZ	EFKTST ;No - testing end of function key
	OR	AL,AL ;Test highbit (indicates end of key word)
	JNS	NOHGBT ;Not highbit terminated
	AND	AL,0o177 ;Map out high bit
	CMP	AL,"(" ;Supershift key ending in "("?
	JZ	EOKTRU ;Yes, don't end in space
	CMP	byte [CS:BX+0o0],TOK_USR ;$USR token?
	JZ	EOKTRU ;Yes, don't end in space
	CMP	byte [CS:BX+0o0],TOK_FN ;$FN token?
	JZ	EOKTRU ;Yes, don't end in space
	MOV	BL," " ;End in a space
	JMP	EOKSSX ; and exit
NOHGBT:	INC	byte [F_SUPR] ;Test for last char. in F.SUPR
	DEC	byte [F_SUPR] ;(Depends on 128 chars in keyword char. set)
	JS	EOKTSX ;Last char NOT from F.SUPR (F.SUPR was 377)
	JMP	EOKTRU ;Last char from F.SUPR - end of supershift
;Test must always leave FLAGS.Z reset
EFKTST:	OR	AL,AL ;Test for null function key
	JZ	EOKTRU ;Null F key incountered
	TEST	byte [BX+0o0],0o377 ;Test for end of function key
	JNZ	EOKTSX ;Not end of function key
	OR	SP,SP ;There is always a character at this point
EOKTRU:	MOV	BX,0 ;Prepare to turn off CMDOFF
EOKSSX:
extern F_SUPR
	MOV byte [F_SUPR], BL ;Turn off current supershift key expansion
EOKTSX:	MOV word [CMDOFF], BX ;Store new softkey expansion index
	RET
;SFTOFF - Turn off softkey expansion for the current softkey.  This routine
;         has been documented to OEMs for use in implementing PEEK/POKE
;         filters for addresses documented to IBM BASIC users.
;
global SFTOFF
SFTOFF:	MOV word [CMDOFF], 0 ;Stop soft key expansion
	MOV byte [F_SUPR], 0 ;Turn off super shift flag
	RET
;KYBSNS - Detect whether keys are available in the keyboard buffer.
;         This routine has been documented to OEMs for use in implementation
;         of PEEK/POKE filters for addresses documented to IBM BASIC users.
;Entry - none
;Exit  - PSW.Z set indicates that the keyboard buffer is empty.
;        all registers preserved
;
global KYBSNS
extern NUMQ
KYBSNS:	PUSH	AX
	PUSH	SI
	MOV	SI,KYBQDS ;SI = keyboard queue descriptor
	CALL	NUMQ ;Get the number of keys available
	OR	AX,AX ;Set flags
	POP	SI
	POP	AX
	RET
;FKYSNS - Sense the availability of a softkey.  This routine is documented to
;         IBMLIK OEMs for support of a PEEK/POKE address documented by IBM.
;Entry - none
;Exit  - PSW.C set indicates softkey expansion is in progress
;        PSW.Z set indicates that the next softkey is not the last key
;              of a supershift key.
;        All registers preserved
;
global FKYSNS
FKYSNS:	CMP byte [CMDOFF], 0 ;Test for expansion in progress
	JZ	FKYSNX ;Expansion not in progress
	CMP byte [F_SUPR], 255 ;Test for super-shift expansion
	JZ	FKYSNW ;SS key but not last key
	CMP byte [F_SUPR], 0 ;Test for super-shift expansion
	JZ	FKYSNW ;Function key expansion in progress
FKYSNW:
	STC
FKYSNX:	RET
;INKEY$ - get key from key-queue if one exists, else return null string.
; Returns 2-byte string for DBLCHR.  For function keys, returns next char
; of function key if key is not null.  If F-key is null, it returns
; 2-byte string which identifies function key.
;
global INKEY
extern INKMAP
extern INFMAP
extern STRINI
extern STRIN1
extern SETSTR
extern PUTNEW
extern CHRGTR
extern DSCPTR
extern VALTYP
extern FACLO
INKEY:	CALL	CHRGTR
	PUSH	BX ;save text pointer
INKGET:	CALL	CHSNS ;get next key from queue
	JZ	NULRT ;branch if no key is queued
	CALL	INKMAP ;OEM map routine for INKEY$
	JZ	INKGET ;OEM has no associated character
	JAE	INKEY1 ;branch if not 2-byte sequence
	PUSH	AX ;save char code
	MOV	AL,0o2
	CALL	STRINI ;initialize 2-byte string
	MOV BX, word [DSCPTR]
	POP	DX ;restore char code
	XCHG	DH,DL ;return high-byte in left end of string
	MOV	word [BX+0o0],DX
	JMP	PUTNEW
INKEY1:	PUSH	AX
	CALL	STRIN1 ;MAKE ONE CHAR STRING
	POP	AX
	MOV	DL,AL
	XCHG	AH,AL ;put bytes in correct order
	CALL	SETSTR ;STUFF IN DESCRIPTOR AND GOTO PUTNEW
extern DSEGZ
NULRT:	MOV	BX,DSEGZ ;GUARANTEED ZERO IN DATA SEGMENT
	MOV word [FACLO], BX
	MOV byte [VALTYP], 0o3
	POP	BX ;restore text pointer
	RET
; SUBTTL  Cursor Support
;STCTYP Set the new cursor type
;       This routine determines the next cursor type.
;Entry - PSW.C set indicates the cursor must be the user cursor
;        PSW.C reset indicates the cursor must be the insert mode
;              cursor or the overstrike cursor.
;EXIT  - All registers preserved
;
global STCTYP
extern CSRTYP
extern F_INST
STCTYP:	PUSH	AX
	MOV	AL,3 ;Assume user cursor
	JB	CSRSET ;Assumption correct
	DEC	AL ;Assume overwrite mode cursor
	TEST byte [F_INST], 255 ;Test for insert mode
	JZ	CSRSET ;Ovewrite mode discovered
	DEC	AL ;Set for insert mode
CSRSET:	MOV byte [CSRTYP], AL ;Save the type
	POP	AX
	RET
;SETCSR - Set the cursor to the new cursor type.
;         This routine ensures that the cursor is set to the new cursor type.
;Entry - none
;Exit  - all registers preserved
;
extern CSRTYP
extern CSRFLG
extern CSRDSP
global SETCSR
SETCSR:	PUSH	AX
	MOV AL, byte [CSRTYP] ;Get cursor type
	CMP byte [CSRFLG], AL ;Test for cursor change
	MOV byte [CSRFLG], AL ;Remember the new cursor type
	JZ	CSROK ;Cursor already set properly
	CALL	CSRDSP ;Display the cursor
CSROK:	POP	AX
	RET
