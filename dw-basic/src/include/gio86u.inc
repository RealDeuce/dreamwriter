; NASM port of the constants from gw-basic/gio86u.

%ifndef DW_BASIC_GIO86U_INC
%define DW_BASIC_GIO86U_INC

%define ASCCTC 3
%define ASCBS 8
%define ASCTAB 9
%define ASCLF 10
%define ASCCR 13
%define ASCCTS 19
%define ASCCTZ 26
%define ASCESC 27
%define ASCSPC 32

%define BINFID 255
%define PROFID 254
%define BSVFID 253

%assign _OFFST 0
%macro ROFFST 2
    %define %1 _OFFST
    %assign _OFFST _OFFST + %2
%endmacro

ROFFST G_EOF, 2
ROFFST G_LOC, 2
ROFFST G_LOF, 2
ROFFST G_CLS, 2
ROFFST G_SWD, 2
ROFFST G_RND, 2
ROFFST G_OPN, 2
ROFFST G_SIN, 2
ROFFST G_SOT, 2
ROFFST G_GPS, 2
ROFFST G_GWD, 2
ROFFST G_SCW, 2
ROFFST G_GCW, 2
ROFFST G_BIN, 2
ROFFST G_BOT, 2

%endif
