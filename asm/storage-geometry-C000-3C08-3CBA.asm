; Generated from disasm: C000:3C08-3CBA
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x3C08


card_capacity_probe_C000_3C08:
; file 0x43C08
    call card_access_check_C000_0AC4
    jnc  card_present_C000_3C14
    mov  byte [0x6ec1],0x08
    stc
    ret
    xor  bx,bx
    mov  cx,0x0010
    mov  dx,0
probe_window_C000_3C1D:
    call card_bank_helper_C000_0239
    add  ax,0x4000
    mov  es,ax
    mov  ax,0x5ea6
    mov  [es:0],ax
    cmp  [es:0],ax
    mov  ax,0xffff
    mov  [es:0],ax
    inc  bx
    add  dx,0x0800
    mov  cx,bx
    xor  bx,bx
verify_window_C000_3C50:
    call card_bank_helper_C000_0239
    mov  ax,[es:0]
    cmp  ax,0xffff
    mov  [es:0],bx
    add  dx,0x0800
    inc  bx
    mov  [0x6fad],bl
finish_card_geometry_C000_3C76:
    or   bx,bx
    jz   no_card_space_C000_3C89
    mov  ax,0x0020
    mul  bx
    mov  [0x6f21],ax
    call C000:23D9
    clc
    ret
local_sector_geometry_C000_3C90:
; file 0x43C90
    mov  bx,[0x6f54]
    mov  ax,0x0004
    mul  bx
    mov  [0x6f21],ax
    mov  byte [0x6f23],0x0e
    call C000:23DE
storage_write_check_C000_3CA7:
; file 0x43CA7
    cmp  byte [0x6fa5],0x08
    jz   write_ok_C000_3CB3
    call card_write_protect_C000_0ACE
    jc   write_protected_C000_3CB5
    clc
    ret
    mov  byte [0x6ec1],0x0b
    ret
