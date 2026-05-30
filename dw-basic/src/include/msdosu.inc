; NASM port of the constants from gw-basic/msdosu.

%ifndef DW_BASIC_MSDOSU_INC
%define DW_BASIC_MSDOSU_INC

%define C_PRTO 5
%define C_DCIO 6
%define C_REST 13
%define C_SDRV 14
%define C_OPEN 15
%define C_CLOS 16
%define C_SEAR 17
%define C_DELE 19
%define C_READ 20
%define C_MAKE 22
%define C_RENA 23
%define C_GDRV 25
%define C_BUFF 26
%define C_RNDR 33
%define C_RNDW 34
%define C_RBR 39
%define C_PARS 41

%define FNAML 11
%define DATPSC 128
%define FCBSIZ 38

%assign _OFFST 0
%unmacro ROFFST 2
%macro ROFFST 2
    %define %1 _OFFST
    %assign _OFFST _OFFST + %2
%endmacro

ROFFST F_NUL1, 1
ROFFST F_NUM, 1
ROFFST F_NUL2, 2
ROFFST F_NEXT, 2
ROFFST F_MODE, 1

%define MD_SQI 1
%define MD_SQO 2
%define MD_RND 4
%define MD_APP 8

ROFFST F_FCB, FCBSIZ
ROFFST F_CLOC, 2
ROFFST F_ORCT, 1
ROFFST F_BREM, 1
ROFFST F_CODE, 1

%define FC_ASC 0
%define FC_BIN 1

ROFFST F_BAKC, 1
ROFFST F_NUL3, 1
ROFFST F_DEV, 1
ROFFST F_WID, 1
ROFFST F_NUL4, 1
ROFFST F_FLGS, 1

%define FL_BKC 0o200

ROFFST F_POS, 1
ROFFST FDBSIZ, 0
ROFFST DATOFS, DATPSC
ROFFST FD_SIZ, 2
ROFFST FD_PHY, 2
ROFFST FD_LOG, 2
ROFFST F_NUL5, 1
ROFFST FD_OPS, 2
ROFFST FD_DAT, 0

%define FCB_DV F_FCB+0
%define FCB_FN F_FCB+1
%define FCB_FT F_FCB+9
%define FCB_EX F_FCB+12
%define FCB_RC F_FCB+14
%define FCB_FS F_FCB+16
%define FCB_DA F_FCB+20
%define FCB_TM F_FCB+22
%define FCB_NR F_FCB+32
%define FCB_RN F_FCB+33

%endif
