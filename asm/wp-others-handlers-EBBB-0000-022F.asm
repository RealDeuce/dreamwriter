; Generated from disasm: EBBB:0000-022F
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x0000


typin_time_entry_EBBB_0000:
; file 0x6BBB0
    push ds
    push es
    push ss
    mov  [0x8e40],ds
    mov  [0x8e42],es
    mov  [0x8e44],ss
    call EBBB:00CC
    mov  bx,0x0000
    mov  ds,bx
    mov  ss,[0x8e44]
    pop  ss
    pop  es
    pop  ds
    mov  word [0x7119],0
    retf
typin_time_init_EBBB_00CC:
    mov  word [0x8e6e],1
    mov  word [0x8e74],0x003c
    mov  ax,0x003c
    mov  [0x8e72],ax
    mov  word [0x8e70],0
    mov  byte [0x9364],0
    mov  word [0x8e52],0
    mov  word [0x8e54],6
    mov  word [0x8e58],0
    mov  ax,0
    mov  [0x8e56],ax
    call EBBB:012E
typin_time_dispatcher_EBBB_012E:
    add  word [0x8e52],1
    mov  ax,[0x8e52]
    cmp  ax,0x0010
    mov  word [0x8e52],0
...
    mov  cx,0x0004
    mov  dx,0xf87b
    call EBBB:0116        ; read far word
    mov  [0x8e54],ax
...
    call DC98:F200
    call DC98:F198
    mov  [0x8e90],ax
    mov  ax,[0x8e54]
    sub  ax,1
    cmp  ax,0x0014
    shl  ax,1
    mov  bx,ax
    jmp  [cs:bx+0x0234]
rom_card_loader_DC98_2B75:
; file 0x5F4F5
