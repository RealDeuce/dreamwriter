; Auto-converted mechanically from ../gw-basic/ibmres.asm
; Edit the converter or the generated source deliberately; do not hand-wave syntax changes.

; [ This translation created 10-Feb-83 by Version 4.3 ]
%include "dwoem.inc"
; .RADIX  8
; TODO include IBMRES.H
; SUBTTL  Equates and External Declarations
; TITLE   IBMRES - IBM compatible reserved words / MLC
; COMMENT *
;
; --------- --- ---- -- ---------
; COPYRIGHT (C) 1982 BY MICROSOFT
; --------- --- ---- -- ---------
;
; This module is used to create GW-BASICs with IBM PC compatible
; reserved word tokens.  The reserved word tables were created by
; cleaning up a copy of the tables from BINTRP.  The code and tables
; to handle the extended reserved words was taken from L2RESS.MAC and
; modified as necessary.
%define GWLEV2 0o0 ;GW BASIC version 2.0 features
; .RADIX	10
extern CHRGTR
extern DATEF
extern LABBCK
extern MAKUPL
extern NOTRFN
extern PARCHK
extern FCERR
extern PLOOP2
extern PPSWRT
extern RENCRN
extern FCERR
extern TIMEF
extern TSTANM
extern FLGOVC
extern TEMPA
;
; THESE MACRO CALLS DEFINE THE RESWRD VALUES
; AND THE TABLE DISPATCH FOR STATEMENTS AND FUNCTIONS
;
; STATEMENTS:
;
global STMDSP
STMDSP: ;MARKS START OF STATEMENT LIST
; %assign QQ 128
extern ENDST
dw ENDST
%assign DOL_END 129
extern FOR
dw FOR
%assign DOL_FOR 130
extern NEXT
dw NEXT
%assign DOL_NEXT 131
extern DATAS
dw DATAS
%assign DOL_DATA 132
extern INPUT
dw INPUT
%assign DOL_INPUT 133
extern DIM
dw DIM
%assign DOL_DIM 134
extern READ
dw READ
%assign DOL_READ 135
extern LET
dw LET
%assign DOL_LET 136
extern GOTO
dw GOTO
%assign DOL_GOTO 137
extern RUN
dw RUN
%assign DOL_RUN 138
extern IFS
dw IFS
%assign DOL_IF 139
extern RESTORE
dw RESTORE
%assign DOL_RESTORE 140
extern GOSUB
dw GOSUB
%assign DOL_GOSUB 141
extern RETURN
dw RETURN
%assign DOL_RETURN 142
extern REM
dw REM
%assign DOL_REM 143
extern STOP
dw STOP
%assign DOL_STOP 144
extern PRINT
dw PRINT
%assign DOL_PRINT 145
extern CLEAR
dw CLEAR
%assign DOL_CLEAR 146
extern LIST
dw LIST
%assign DOL_LIST 147
extern SCRATH
dw SCRATH
%assign DOL_NEW 148
extern ONGOTO
dw ONGOTO
%assign DOL_ON 149
extern FNWAIT
dw FNWAIT
%assign DOL_WAIT 150
extern DEF
dw DEF
%assign DOL_DEF 151
extern POKE
dw POKE
%assign DOL_POKE 152
extern CONT
dw CONT
%assign DOL_CONT 153
extern SNERR
dw SNERR
extern SNERR
dw SNERR
extern FNOUT
dw FNOUT
%assign DOL_OUT 156
extern LPRINT
dw LPRINT
%assign DOL_LPRINT 157
extern LLIST
dw LLIST
%assign DOL_LLIST 158
extern SNERR
dw SNERR
extern WIDTHS
dw WIDTHS
%assign DOL_WIDTH 160
extern ELSES
dw ELSES
%assign DOL_ELSE 161
extern TON
dw TON
%assign DOL_TRON 162
extern TOFF
dw TOFF
%assign DOL_TROFF 163
extern SWAP
dw SWAP
%assign DOL_SWAP 164
extern ERASE
dw ERASE
%assign DOL_ERASE 165
extern EDIT
dw EDIT
%assign DOL_EDIT 166
extern ERRORS
dw ERRORS
%assign DOL_ERROR 167
extern RESUME
dw RESUME
%assign DOL_RESUME 168
extern DELETE
dw DELETE
%assign DOL_DELETE 169
extern AUTO
dw AUTO
%assign DOL_AUTO 170
extern RESEQ
dw RESEQ
%assign DOL_RENUM 171
extern DEFSTR
dw DEFSTR
%assign DOL_DEFSTR 172
extern DEFINT
dw DEFINT
%assign DOL_DEFINT 173
extern DEFREA
dw DEFREA
%assign DOL_DEFSNG 174
extern DEFDBL
dw DEFDBL
%assign DOL_DEFDBL 175
extern LINE
dw LINE
%assign DOL_LINE 176
extern WHILE
dw WHILE
%assign DOL_WHILE 177
extern WEND
dw WEND
%assign DOL_WEND 178
extern CALLS
dw CALLS
%assign DOL_CALL 179
extern SNERR
dw SNERR
extern SNERR
dw SNERR
extern SNERR
dw SNERR
extern WRITE
dw WRITE
%assign DOL_WRITE 183
extern OPTION
dw OPTION
%assign DOL_OPTION 184
extern RANDOM
dw RANDOM
%assign DOL_RANDOMIZE 185
extern OPEN
dw OPEN
%assign DOL_OPEN 186
extern CLOSE
dw CLOSE
%assign DOL_CLOSE 187
extern LOAD
dw LOAD
%assign DOL_LOAD 188
extern NODSKS
dw NODSKS
%assign DOL_MERGE 189
extern SAVE
dw SAVE
%assign DOL_SAVE 190
extern COLOR
dw COLOR
%assign DOL_COLOR 191
extern CLS
dw CLS
%assign DOL_CLS 192
extern FCERR
dw FCERR
%assign DOL_MOTOR 193
extern BSAVE
dw BSAVE
%assign DOL_BSAVE 194
extern BLOAD
dw BLOAD
%assign DOL_BLOAD 195
extern SOUNDS
dw SOUNDS
%assign DOL_SOUND 196
extern BEEPS
dw BEEPS
%assign DOL_BEEP 197
%if GW_ENABLE_GRAPHICS
extern PSET
dw PSET
%else
extern FCERR
dw FCERR
%endif
%assign DOL_PSET 198
%if GW_ENABLE_GRAPHICS
extern PRESET
dw PRESET
%else
extern FCERR
dw FCERR
%endif
%assign DOL_PRESET 199
extern SCREEN
dw SCREEN
%assign DOL_SCREEN 200
extern KEYS
dw KEYS
%assign DOL_KEY 201
%assign DOL_KEY2B 0+201
extern LOCATE
dw LOCATE
%assign DOL_LOCATE 202
%assign NUMCMD 202-DOL_END+1
;
; TOKENS
;
;
;QQ MUST BE SET SO TOKENS START AT RIGHT PLACE
;
; %assign QQ QQ+1
%assign DOL_TO 204
%assign DOL_THEN 205
%assign THENTK 205
%assign DOL_TAB 206
%assign TABTK 206
%assign DOL_STEP 207
%assign STEPTK 207
%assign DOL_USR 208
%assign USRTK 208
%assign DOL_FN 209
%assign FNTK 209
%assign DOL_SPC 210
%assign SPCTK 210
%assign DOL_NOT 211
%assign NOTTK 211
%assign DOL_ERL 212
%assign ERLTK 212
%assign DOL_ERR 213
%assign ERCTK 213
%assign DOL_STRING$ 214
%assign DOL_USING 215
%assign USINTK 215
%assign DOL_INSTR 216
%assign INSRTK 216
%assign SNGQTK 217
%assign DOL_VARPTR 218
%assign DOL_CSRLIN 219
%assign CLINTK 219
%assign DOL_POINT 220
%assign DOL_OFF 221
%assign DOL_INKEY$ 222
;
; OPERATORS
;
; %assign QQ QQ+7
%assign GREATK 230
%assign EQULTK 231
%assign LESSTK 232
%assign PLUSTK 233
%assign MINUTK 234
%assign MULTK 235
%assign DIVTK 236
%assign EXPTK 237
%assign DOL_AND 238
%assign DOL_OR 239
%assign DOL_XOR 240
%assign DOL_EQV 241
%assign DOL_IMP 242
%assign DOL_MOD 243
%assign IDIVTK 244
%assign LSTOPK 244+1-PLUSTK
;
; FUNCTIONS - 2 byte tokens, the 1st byte is FF
;
; %assign QQ 128
global FUNDSP
FUNDSP:
extern LEFT$
dw LEFT$
%assign DOL_LEFT$ 129
%assign ONEFUN 129
extern RIGHT$
dw RIGHT$
%assign DOL_RIGHT$ 130
extern MID$
dw MID$
%assign DOL_MID$ 131
%assign MIDTK 131
extern SGN
dw SGN
%assign DOL_SGN 132
extern VINT
dw VINT
%assign DOL_INT 133
extern ABSFN
dw ABSFN
%assign DOL_ABS 134
extern SQR
dw SQR
%assign DOL_SQR 135
%assign SQRTK 135
extern RND
dw RND
%assign DOL_RND 136
extern SIN
dw SIN
%assign DOL_SIN 137
extern LOG
dw LOG
%assign DOL_LOG 138
extern EXP
dw EXP
%assign DOL_EXP 139
extern COS
dw COS
%assign DOL_COS 140
extern TAN
dw TAN
%assign DOL_TAN 141
extern ATN
dw ATN
%assign DOL_ATN 142
%assign ATNTK 142
extern FRE
dw FRE
%assign DOL_FRE 143
extern FNINP
dw FNINP
%assign DOL_INP 144
extern POS
dw POS
%assign DOL_POS 145
extern LEN
dw LEN
%assign DOL_LEN 146
extern STR$
dw STR$
%assign DOL_STR$ 147
extern VAL
dw VAL
%assign DOL_VAL 148
extern ASC
dw ASC
%assign DOL_ASC 149
extern CHR$
dw CHR$
%assign DOL_CHR$ 150
extern PEEK
dw PEEK
%assign DOL_PEEK 151
extern SPACE$
dw SPACE$
%assign DOL_SPACE$ 152
extern STRO$
dw STRO$
%assign DOL_OCT$ 153
extern STRH$
dw STRH$
%assign DOL_HEX$ 154
extern FCERR
dw FCERR
%assign DOL_LPOS 155
%assign LASNUM 155
extern FRCINT
dw FRCINT
%assign DOL_CINT 156
extern FRCSNG
dw FRCSNG
%assign DOL_CSNG 157
extern FRCDBL
dw FRCDBL
%assign DOL_CDBL 158
extern FIXER
dw FIXER
%assign DOL_FIX 159
extern FCERR
dw FCERR
%assign DOL_PEN 160
%assign DOL_PEN2B 0+(0o400*0o377)+160
extern FCERR
dw FCERR
%assign DOL_STICK 161
extern FCERR
dw FCERR
%assign DOL_STRIG 162
%assign DOL_STR2B 0+(0o400*0o377)+162
extern EOF
dw EOF
%assign DOL_EOF 163
extern LOC
dw LOC
%assign DOL_LOC 164
extern LOF
dw LOF
%assign DOL_LOF 165
;
; THE FOLLOWING TABLES ARE THE ALPHABETIC DISPATCH TABLE
; FOLLOWED BY THE RESERVED WORD TABLE ITSELF
;
global ALPTAB
ALPTAB:
dw ATAB
dw BTAB
dw CTAB
dw DTAB
dw ETAB
dw FTAB
dw GTAB
dw HTAB
dw ITAB
dw JTAB
dw KTAB
dw LTAB
dw MTAB
dw NTAB
dw OTAB
dw PTAB
dw QTAB
dw RTAB
dw STAB
dw TTAB
dw UTAB
dw VTAB
dw WTAB
dw XTAB
dw YTAB
dw ZTAB
global RESLST
RESLST:
ATAB:
db "U"
db "T"
db 207
db DOL_AUTO
db "N"
db 196
db DOL_AND
db "B"
db 211
db DOL_ABS-128
db "T"
db 206
db DOL_ATN-128
db "S"
db 195
db DOL_ASC-128
db 0
BTAB:
db "S"
db "A"
db "V"
db 197
db DOL_BSAVE
db "L"
db "O"
db "A"
db 196
db DOL_BLOAD
db "E"
db "E"
db 208
db DOL_BEEP
db 0
CTAB:
db "O"
db "L"
db "O"
db 210
db DOL_COLOR
db "L"
db "O"
db "S"
db 197
db DOL_CLOSE
db "O"
db "N"
db 212
db DOL_CONT
db "L"
db "E"
db "A"
db 210
db DOL_CLEAR
db "S"
db "R"
db "L"
db "I"
db 206
db DOL_CSRLIN
db "I"
db "N"
db 212
db DOL_CINT-128
db "S"
db "N"
db 199
db DOL_CSNG-128
db "D"
db "B"
db 204
db DOL_CDBL-128
db "O"
db 211
db DOL_COS-128
db "H"
db "R"
db 164
db DOL_CHR$-128
db "A"
db "L"
db 204
db DOL_CALL
db "L"
db 211
db DOL_CLS
db 0
DTAB:
db "E"
db "L"
db "E"
db "T"
db 197
db DOL_DELETE
db "A"
db "T"
db 193
db DOL_DATA
db "I"
db 205
db DOL_DIM
db "E"
db "F"
db "S"
db "T"
db 210
db DOL_DEFSTR
db "E"
db "F"
db "I"
db "N"
db 212
db DOL_DEFINT
db "E"
db "F"
db "S"
db "N"
db 199
db DOL_DEFSNG
db "E"
db "F"
db "D"
db "B"
db 204
db DOL_DEFDBL
db "E"
db 198
db DOL_DEF
db 0
ETAB:
db "L"
db "S"
db 197
db DOL_ELSE
db "N"
db 196
db DOL_END
db "R"
db "A"
db "S"
db 197
db DOL_ERASE
db "D"
db "I"
db 212
db DOL_EDIT
db "R"
db "R"
db "O"
db 210
db DOL_ERROR
db "R"
db 204
db DOL_ERL
db "R"
db 210
db DOL_ERR
db "X"
db 208
db DOL_EXP-128
db "O"
db 198
db DOL_EOF-128
db "Q"
db 214
db DOL_EQV
db 0
FTAB:
db "O"
db 210
db DOL_FOR
db 206
db DOL_FN
db "R"
db 197
db DOL_FRE-128
db "I"
db 216
db DOL_FIX-128
db 0
GTAB:
db "O"
db "T"
db 207
db DOL_GOTO
db "O"
db " "
db "T"
db "O"+128
db TOK_GOTO
db "O"
db "S"
db "U"
db 194
db DOL_GOSUB
db 0
HTAB:
db "E"
db "X"
db 164
db DOL_HEX$-128
db 0
ITAB:
db "N"
db "P"
db "U"
db 212
db DOL_INPUT
db 198
db DOL_IF
db "N"
db "S"
db "T"
db 210
db DOL_INSTR
db "N"
db 212
db DOL_INT-128
db "N"
db 208
db DOL_INP-128
db "M"
db 208
db DOL_IMP
db "N"
db "K"
db "E"
db "Y"
db 164
db DOL_INKEY$
db 0
JTAB:
db 0
KTAB:
db "E"
db 217
db DOL_KEY
db 0
LTAB:
db "O"
db "C"
db "A"
db "T"
db 197
db DOL_LOCATE
db "P"
db "R"
db "I"
db "N"
db 212
db DOL_LPRINT
db "L"
db "I"
db "S"
db 212
db DOL_LLIST
db "P"
db "O"
db 211
db DOL_LPOS-128
db "E"
db 212
db DOL_LET
db "I"
db "N"
db 197
db DOL_LINE
db "O"
db "A"
db 196
db DOL_LOAD
db "I"
db "S"
db 212
db DOL_LIST
db "O"
db 199
db DOL_LOG-128
db "O"
db 195
db DOL_LOC-128
db "E"
db 206
db DOL_LEN-128
db "E"
db "F"
db "T"
db 164
db DOL_LEFT$-128
db "O"
db 198
db DOL_LOF-128
db 0
MTAB:
db "O"
db "T"
db "O"
db 210
db DOL_MOTOR
db "E"
db "R"
db "G"
db 197
db DOL_MERGE
db "O"
db 196
db DOL_MOD
db "I"
db "D"
db 164
db DOL_MID$-128
db 0
NTAB:
db "E"
db "X"
db 212
db DOL_NEXT
db "E"
db 215
db DOL_NEW
db "O"
db 212
db DOL_NOT
db 0
OTAB:
db "P"
db "E"
db 206
db DOL_OPEN
db "U"
db 212
db DOL_OUT
db 206
db DOL_ON
db 210
db DOL_OR
db "C"
db "T"
db 164
db DOL_OCT$-128
db "P"
db "T"
db "I"
db "O"
db 206
db DOL_OPTION
db "F"
db 198
db DOL_OFF
db 0
PTAB:
db "R"
db "I"
db "N"
db 212
db DOL_PRINT
db "O"
db "K"
db 197
db DOL_POKE
db "O"
db 211
db DOL_POS-128
db "E"
db "E"
db 203
db DOL_PEEK-128
db "S"
db "E"
db 212
db DOL_PSET
db "R"
db "E"
db "S"
db "E"
db 212
db DOL_PRESET
db "O"
db "I"
db "N"
db 212
db DOL_POINT
db "E"
db 206
db DOL_PEN-128
db 0
QTAB:
db 0
RTAB:
db "U"
db 206
db DOL_RUN
db "E"
db "T"
db "U"
db "R"
db 206
db DOL_RETURN
db "E"
db "A"
db 196
db DOL_READ
db "E"
db "S"
db "T"
db "O"
db "R"
db 197
db DOL_RESTORE
db "E"
db 205
db DOL_REM
db "E"
db "S"
db "U"
db "M"
db 197
db DOL_RESUME
db "I"
db "G"
db "H"
db "T"
db 164
db DOL_RIGHT$-128
db "N"
db 196
db DOL_RND-128
db "E"
db "N"
db "U"
db 205
db DOL_RENUM
db "A"
db "N"
db "D"
db "O"
db "M"
db "I"
db "Z"
db 197
db DOL_RANDOMIZE
db 0
STAB:
db "C"
db "R"
db "E"
db "E"
db 206
db DOL_SCREEN
db "T"
db "O"
db 208
db DOL_STOP
db "W"
db "A"
db 208
db DOL_SWAP
db "A"
db "V"
db 197
db DOL_SAVE
db "P"
db "C"
db "("+128
db SPCTK
db "T"
db "E"
db 208
db DOL_STEP
db "G"
db 206
db DOL_SGN-128
db "Q"
db 210
db DOL_SQR-128
db "I"
db 206
db DOL_SIN-128
db "T"
db "R"
db 164
db DOL_STR$-128
db "T"
db "R"
db "I"
db "N"
db "G"
db 164
db DOL_STRING$
db "P"
db "A"
db "C"
db "E"
db 164
db DOL_SPACE$-128
db "O"
db "U"
db "N"
db 196
db DOL_SOUND
db "T"
db "I"
db "C"
db 203
db DOL_STICK-128
db "T"
db "R"
db "I"
db 199
db DOL_STRIG-128
db 0
TTAB:
db "H"
db "E"
db 206
db DOL_THEN
db "R"
db "O"
db 206
db DOL_TRON
db "R"
db "O"
db "F"
db 198
db DOL_TROFF
db "A"
db "B"
db "("+128
db TABTK
db 207
db DOL_TO
db "A"
db 206
db DOL_TAN-128
db 0
UTAB:
db "S"
db "I"
db "N"
db 199
db DOL_USING
db "S"
db 210
db DOL_USR
db 0
VTAB:
db "A"
db 204
db DOL_VAL-128
db "A"
db "R"
db "P"
db "T"
db 210
db DOL_VARPTR
db 0
WTAB:
db "I"
db "D"
db "T"
db 200
db DOL_WIDTH
db "A"
db "I"
db 212
db DOL_WAIT
db "H"
db "I"
db "L"
db 197
db DOL_WHILE
db "E"
db "N"
db 196
db DOL_WEND
db "R"
db "I"
db "T"
db 197
db DOL_WRITE
db 0
XTAB:
db "O"
db 210
db DOL_XOR
db 0
YTAB:
db 0
ZTAB:
db 0
global SPCTAB
SPCTAB:
db "+"+128
db PLUSTK
db "-"+128
db MINUTK
db "*"+128
db MULTK
db "/"+128
db DIVTK
db "^"+128
db EXPTK
db "\"+128
db IDIVTK
db "'"+128
db SNGQTK
db 62+128
db GREATK
db "="+128
db EQULTK
db 60+128
db LESSTK
db 0
; SUBTTL  Extended reserved words
;The following are 2 byte tokens, the 1st byte is FE
; %assign QQ 128
STMDSX:
extern NODSKS
dw NODSKS
%assign DOL_FILES 129
extern NODSKS
dw NODSKS
%assign DOL_FIELD 130
extern SYSTEM
dw SYSTEM
%assign DOL_SYSTEM 131
extern NODSKS
dw NODSKS
%assign DOL_NAME 132
extern NODSKS
dw NODSKS
%assign DOL_LSET 133
extern NODSKS
dw NODSKS
%assign DOL_RSET 134
extern NODSKS
dw NODSKS
%assign DOL_KILL 135
extern NODSKS
dw NODSKS
%assign DOL_PUT 136
extern NODSKS
dw NODSKS
%assign DOL_GET 137
extern NODSKS
dw NODSKS
%assign DOL_RESET 138
extern BASIC_COMMON
dw BASIC_COMMON
%assign DOL_COMMON 139
extern NODSKS
dw NODSKS
%assign DOL_CHAIN 140
extern DATES
dw DATES
%assign DOL_DATE$ 141
extern TIMES_STMT
dw TIMES_STMT
%assign DOL_TIME$ 142
extern FCERR
dw FCERR
%assign DOL_PAINT 143
extern FCERR
dw FCERR
%assign DOL_COM 144
%assign DOL_COM2B 0+(0o400*0o376)+144
%if GW_ENABLE_GRAPHICS
extern CIRCLE
dw CIRCLE
%else
extern FCERR
dw FCERR
%endif
%assign DOL_CIRCLE 145
%if GW_ENABLE_GRAPHICS
extern DRAW
dw DRAW
%else
extern FCERR
dw FCERR
%endif
%assign DOL_DRAW 146
extern PLAYS
dw PLAYS
%assign DOL_PLAY 147
extern FCERR
dw FCERR
%assign DOL_TIMER 148
extern FCERR
dw FCERR
%assign DOL_ERDEV 149
extern FCERR
dw FCERR
%assign DOL_IOCTL 150
extern NODSKS
dw NODSKS
%assign DOL_CHDIR 151
extern NODSKS
dw NODSKS
%assign DOL_MKDIR 152
extern NODSKS
dw NODSKS
%assign DOL_RMDIR 153
extern FCERR
dw FCERR
%assign DOL_SHELL 154
extern FCERR
dw FCERR
%assign DOL_ENVIRON 155
extern FCERR
dw FCERR
%assign DOL_VIEW 156
extern FCERR
dw FCERR
%assign DOL_WINDOW 157
extern FCERR
dw FCERR
%assign DOL_PMAP 158
extern FCERR
dw FCERR
%assign DOL_PALETTE 159
extern FCERR
dw FCERR
%assign DOL_LCOPY 160
extern CALLSL
dw CALLSL
%assign DOL_CALLS 161
;*************************************************************************
;*** The DEBUG entry should be the last entry in the FE Dispatch table ***
;*************************************************************************
;The following are 2 byte tokens, the 1st byte is FD
; %assign QQ 128
FUNDSX:
extern FCERR
dw FCERR
%assign DOL_CVI 129
extern FCERR
dw FCERR
%assign DOL_CVS 130
extern FCERR
dw FCERR
%assign DOL_CVD 131
extern FCERR
dw FCERR
%assign DOL_MKI$ 132
extern FCERR
dw FCERR
%assign DOL_MKS$ 133
extern FCERR
dw FCERR
%assign DOL_MKD$ 134
extern FCERR
dw FCERR
%assign DOL_KTN 135
extern FCERR
dw FCERR
%assign DOL_JIS 136
extern FCERR
dw FCERR
%assign DOL_KPOS 137
extern FCERR
dw FCERR
%assign DOL_KLEN 138
global ALPTAX
ALPTAX:
dw ATABX
dw BTABX
dw CTABX
dw DTABX
dw ETABX
dw FTABX
dw GTABX
dw HTABX
dw ITABX
dw JTABX
dw KTABX
dw LTABX
dw MTABX
dw NTABX
dw OTABX
dw PTABX
dw QTABX
dw RTABX
dw STABX
dw TTABX
dw UTABX
dw VTABX
dw WTABX
dw XTABX
dw YTABX
dw ZTABX
RESLSX:
ATABX:
db 0
BTABX:
db 0
CTABX:
db "H"
db "A"
db "I"
db 206
db DOL_CHAIN
db "V"
db 201
db DOL_CVI-128
db "V"
db 211
db DOL_CVS-128
db "V"
db 196
db DOL_CVD-128
db "O"
db "M"
db "M"
db "O"
db 206
db DOL_COMMON
db "O"
db 205
db DOL_COM
db "I"
db "R"
db "C"
db "L"
db 197
db DOL_CIRCLE
db "A"
db "L"
db "L"
db 211
db DOL_CALLS
db 0
DTABX:
db "A"
db "T"
db "E"
db 164
db DOL_DATE$
db "R"
db "A"
db 215
db DOL_DRAW
db 0
ETABX:
db 0
FTABX:
db "I"
db "E"
db "L"
db 196
db DOL_FIELD
db "I"
db "L"
db "E"
db 211
db DOL_FILES
db 0
GTABX:
db "E"
db 212
db DOL_GET
db 0
HTABX:
db 0
ITABX:
db "O"
db "C"
db "T"
db 204
db DOL_IOCTL
db 0
JTABX:
db 0
KTABX:
db "I"
db "L"
db 204
db DOL_KILL
db 0
LTABX:
db "S"
db "E"
db 212
db DOL_LSET
db "C"
db "O"
db "P"
db 217
db DOL_LCOPY
db 0
MTABX:
db "K"
db "I"
db 164
db DOL_MKI$-128
db "K"
db "S"
db 164
db DOL_MKS$-128
db "K"
db "D"
db 164
db DOL_MKD$-128
db 0
NTABX:
db "A"
db "M"
db 197
db DOL_NAME
db 0
OTABX:
db 0
PTABX:
db "U"
db 212
db DOL_PUT
db "A"
db "I"
db "N"
db 212
db DOL_PAINT
db "L"
db "A"
db 217
db DOL_PLAY
db 0
QTABX:
db 0
RTABX:
db "S"
db "E"
db 212
db DOL_RSET
db "E"
db "S"
db "E"
db 212
db DOL_RESET
db 0
STABX:
db "Y"
db "S"
db "T"
db "E"
db 205
db DOL_SYSTEM
db 0
TTABX:
db "I"
db "M"
db "E"
db 164
db DOL_TIME$
db 0
UTABX:
db 0
VTABX:
db 0
WTABX:
db 0
XTABX:
db 0
YTABX:
db 0
ZTABX:
db 0
%define NUMGFN (2*MIDTK)-(2*ONEFUN)+1
%define BOTCON (SQRTK-ONEFUN)*2
%define TOPCON (ATNTK-ONEFUN)*2+1
%define DOL_RNDFN DOL_RND-ONEFUN
%define DOL_DATCO DOL_DATA-":"
%define DOL_REMCO DOL_REM-":"
%define NMREL LESSTK-GREATK+1
%define DOL_CHRFN DOL_CHR$-ONEFUN
%define DOL_CSNGF DOL_CSNG-ONEFUN
%define DOL_CDBLF DOL_CDBL-ONEFUN
; SUBTTL  CRUNCH code to handle extended reserved words
global CRUNCX
CRUNCX:	POP	BX ;GET BACK SOURCE POINTER
	PUSH	BX ;TO TRY AGAIN
	DEC	BX ;POINT AT CHARACTER
	CALL	MAKUPL ;CONVERT TO UPPER CASE
	MOV	BX,ALPTAX ;GET POINTER TO ALPHA DISPATCH TABLE
	SUB	AL,"A" ;SUBTRACT ALPHA OFFSET
	ADD	AL,AL ;MULTIPLY BY TWO
	MOV	CL,AL ;SAVE OFFSET IN [C] FOR DAD.
	MOV	CH,0 ;MAKE HIGH PART OF OFFSET ZERO
	ADD	BX,CX ;ADD TO TABLE ADDRESS
db 0o56
	MOV	DX,[BX] ;GET POINTER IN [D,E]
	POP	BX ;GET BACK SOURCE POINTER
TRYAGA:	PUSH	BX ;SAVE TXTPTR TO START OF SEARCH AREA
LOPPSI:
	CALL	MAKUPL ;TRANSLATE THIS CHAR TO UPPER CASE
	MOV	CL,AL ;SAVE CHAR IN [C]
db 0o213
db 0o362
db 0o56
db 0o254 ;FETCH FROM CODE SEGMENT
	AND	AL,127 ;GET RID OF HIGH BIT
	JNZ	??L000
	JMP	NOTRFN ;IF=0 THEN END OF THIS CHARS RESLT
??L000:
	INC	BX ;BUMP SOURCE POINTER
	CMP	AL,CL ;COMPARE TO CHAR FROM SOURCE LINE
	JNZ	LOPSKP ;IF NO MATCH, SEARCH FOR NEXT RESWRD
db 0o213
db 0o362
db 0o56
db 0o254 ;FETCH FROM CODE SEGMENT
	INC	DX ;BUMP RESLST POINTER
	OR	AL,AL ;SET CC'S
	JS	??L001
	JMP	LOPPSI ;SEE IF REST OF CHARS MATCH
??L001:
db 0o213
db 0o362
db 0o56
db 0o254 ;FETCH FROM CODE SEGMENT
	CALL	MAKUPL ;GET NEXT CHAR IN LINE (MC 6/22/80)
	CMP	AL,"." ;IS IT A DOT
	JZ	ISVARS ;YES
	CALL	TSTANM ;IS IT A LETTER IMMEDIATELY
;FOLLOWING RESWRD
ISVARS:	MOV	AL,0 ;SET DONUM TO -1
	JNAE	??L002
	JMP	NOTRFN ;IF ALPHA, CANT BE RESERVED WORD
??L002:
	POP	AX ;GET RID OF SAVED [H,L]
db 0o213
db 0o362
db 0o56
db 0o254 ;FETCH FROM CODE SEGMENT
	OR	AL,AL ;SET CC'S
	POP	CX ;GET CHAR COUNT OFF STACK
	POP	DX ;GET DEPOSIT POINTER OFF STACK
	JNS	??L003
	JMP	NOTFNT ;IF MINUS, WASNT FUNCTION TOKEN
??L003:
	OR	AL,0o200 ;MAKE HIGH ORDER BIT ONE
	STC ;AND FORCE LEADER BYTE TO BE 375
NOTFNT:	PUSH	AX ;SAVE FN CHAR
	MOV	AL,0o376 ;GET BYTE WHICH PRECEEDS FNS
	SBB	AL,0 ;MAKE FUNCTION LEADER 375
	JMP	RENCRN ;REENTER CRUNCH WITH NEW RESERVED WORD
LOPSKP:	POP	BX ;RESTORE UNDEFILED TEXT POINTER
LOPSK2:
db 0o213
db 0o362
db 0o56
db 0o254 ;FETCH FROM CODE SEGMENT
	INC	DX ;BUMP RESLST POINTER
	OR	AL,AL ;SET CC'S
	JS	??L004
	JMP	LOPSK2 ;NOT END OF RESWRD, KEEP SKIPPING
??L004:
	INC	DX ;POINT AFTER TOKEN
	JMP	TRYAGA ;TRY ANOTHER RESWRD
; SUBTTL  LIST code for extended reserved words
BUFRET:	RET
NEWFUN:	MOV	AL,byte [BX] ;GET FUNCTION NUMBER
	AND	AL,0o177 ;TAKE OFF HIGH BIT
	JMP	BUFCON
global LISTX
LISTX:	CMP	AL,0o375 ;IS IT A NEW FUNCTION
	JZ	NEWFUN
	CMP	AL,0o376 ;IS IT A NEW STATEMENT
	JNZ	BUFRET ;NO, JUST CONTINUE NORMAL PATH
	MOV	AL,byte [BX] ;GET NUMBER OF STATEMENT
BUFCON:	POP	BX ;Get rid of the return address.
	MOV	BX,RESLSX-1 ;GET PTR TO START OF RESERVED WORD LIST
	MOV	CH,AL ;SAVE THIS CHAR IN [B]
	MOV	CL,"A"-1 ;INIT LEADING CHAR VALUE
RESSR3:	INC	CL ;BUMP LEADING CHAR VALUE.
RESSR1:	INC	BX ;BUMP POINTER INTO RESLST
RESSRC:	MOV	DH,BH ;SAVE PTR TO START OF THIS RESWRD
	MOV	DL,BL
RESSR2:
db 0o56 ;FETCH FROM CODE SEGMENT
	MOV	AL,byte [BX] ;GET CHAR FROM RESLST
	OR	AL,AL ;SET CC'S
	JZ	RESSR3 ;IF END OF THIS CHARS TABLE,
;GO BACK & BUMP C
	LAHF
	INC	BX ;BUMP SOURCE PTR
	SAHF
	JS	??L005
	JMP	RESSR2 ;IF NOT END OF THIS RESWRD,
??L005:
;THEN KEEP LOOKING
db 0o56 ;FETCH FROM CODE SEGMENT
	MOV	AL,byte [BX] ;GET PTR TO RESERVED WORD VALUE
	CMP	AL,CH ;SAME AS THE ONE WE SEARCH FOR?
	JNZ	RESSR1 ;NO, KEEP LOOKING.
	XCHG	BX,DX ;SAVE FOUND PTR IN [H,L]
	MOV	AL,CL ;GET LEADING CHAR
	POP	DX ;RESTORE LINE CHAR COUNT
	POP	CX ;RESTORE DEPOSIT PTR
	MOV	DL,AL ;SAVE LEADING CHAR IN [E]
;
; CODE BELOW NOT NEEDED SINCE NO SPECIAL REVERVED WORDS IN HOOK TABLE
;
;       CPI     "Z"+1           ;WAS IT A SPECIAL CHAR?
;       JRNZ    NTSPCH          ;NON-SPECIAL CHAR
;       XRA     A               ;SET NON-SPECIAL
;       STA     TEMPA
;       JMPR    MORPUR          ;PRINT IT
NTSPCH:	MOV AL, byte [TEMPA] ;WHAT DID WE DO LAST?
	OR	AL,AL ;SPECIAL?
	MOV	AL,255 ;FLAG IN RESERVED WORD
	MOV byte [TEMPA], AL ;CLEAR FLAG
MORLNZ:	JZ	MORLN0 ;GET CHAR AND PROCEED
	MOV	AL," " ;PUT SPACE IN BUFFER
	MOV	DI,CX
	STOSB
	INC	CX
	DEC	DH ;ANY SPACE LEFT IN BUFFER
	JNZ	??L006
	JMP	PPSWRT ;NO, RETURN
??L006:
MORLN0:	MOV	AL,DL
	JMP	MORLN1 ;CONTINUE
MORPUR:
db 0o56 ;FETCH FROM CODE SEGMENT
	MOV	AL,byte [BX] ;GET BYTE FROM RESWRD
	INC	BX ;BUMP POINTER
MORLNP:	MOV	DL,AL ;SAVE CHAR
MORLN1:	AND	AL,0o177 ;AND OFF HIGH ORDER BIT FOR DISK & EDIT
	MOV	DI,CX
	STOSB ;STORE THIS CHAR
	INC	CX ;BUMP PTR
	DEC	DH ;BUMP DOWN REMAINING CHAR COUNT
	JNZ	??L007
	JMP	PPSWRT ;IF END OF LINE, JUST RETURN
??L007:
	OR	AL,DL ;SET CC'S
	JS	??L008
	JMP	MORPUR ;END OF RESWRD?
??L008:
	POP	BX ;RESTORE SOURCE PTR.
	INC	BX ;SKIP OVER RESERVED WORD
	JMP	PLOOP2 ;GET NEXT CHAR FROM LINE
; SUBTTL  Extended Statement Dispatching
SNERRS:	JMP	SNERR
global NEWSTX
NEWSTX:	CMP	AL,0o376-0o201 ;CHECK FOR NEW STATEMENT PREFIX
	JZ	GONE4 ;IF SO, DISPATCH
	CMP	AL,0o377-0o201 ;FUNCTION?
	JNZ	GIIRET
	POP	CX ;Put return address into B.
	INC	BX
	MOV	AL,byte [BX]
	CMP	AL,TOK_PEN ; PEN as stmt?
	JNZ	??L009
	JMP	PENV ; Brif so.
??L009:
	CMP	AL,TOK_STRIG ;STRIG as stmt?
	JNZ	??L010
	JMP	STRIGV ; Brif so.
??L010:
	DEC	BX
	MOV	AL,0o377-0o201
	PUSH	CX ;Put the return address back on.
GIIRET:	RET ;MID$ OR SYNTAX ERROR
PENV:	CALL	CHRGTR
	JMP	FCERR
STRIGV:	CALL	CHRGTR
	JMP	FCERR
GONE4:	POP	CX ;Get rid of the return address.
	INC	BX ;LOOK AT NEXT CHAR
	MOV	AL,byte [BX] ;FETCH IT
	SUB	AL,0o201 ;GET RELATIVE POSITION IN STMDSX
	JB	SNERRS ;IF TOO SMALL, SYNTAX ERROR
	ADD	AL,AL ;TURN BYTE INTO OFFSET
db 0o62, 0o344 ;XOR AH,AH
db 0o213, 0o360 ;MOV SI,AX - GET OFFSET INTO [SI]
db 0o56 ;CODE SEGMENT OVERRIDE
db 0o377
db 0o264
dw STMDSX ;PUSH STMDSP(SI) - PUSH ADDRESS
	JMP	CHRGTR ;START STATEMENT
; SUBTTL  EVAL code for extended functions
global EVALX
EVALX:	CMP	AL,0o376
	JZ	EVALNS ;Brif possible stmt as function
	CMP	AL,0o375
	JZ	EVALNF ;NEW FUNCTION IF 375 IN FRONT
	RET
EVALNS:	INC	BX
	MOV	AL,byte [BX]
	CMP	AL,DOL_DATE$
	JZ	DATEV ;Brif DATE$
	CMP	AL,DOL_TIME$
	JZ	TIMEV ;Brif TIME$
	DEC	BX
	MOV	AL,byte [BX]
	RET
DATEV:	POP	CX ;Get rid of the hook return address.
	JMP	DATEF ;Do DATE function.
TIMEV:	POP	CX ;Get rid of the hook return address.
	JMP	TIMEF ;Do TIME$ function.
EVALNF:	POP	CX ;Get rid of the return address.
	INC	BX
	MOV	AL,byte [BX]
	SUB	AL,0o201
	MOV	CH,0
	ROL	AL,1
	MOV	CL,AL
	PUSH	CX
	CALL	CHRGTR
	CALL	PARCHK
	POP	SI ;XTHL
	XCHG	SI,BX
	PUSH	SI
	MOV	DX,LABBCK
	PUSH	DX
	MOV	AL,1
	MOV byte [FLGOVC], AL
db 0o213, 0o363 ;MOV SI,BX (GET FUNCTION OFFSET IN SI)
db 0o56
db 0o377
db 0o264
dw FUNDSX
	RET
