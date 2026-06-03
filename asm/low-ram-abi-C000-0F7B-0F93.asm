; Generated from disasm: C000:0F7B-0F93
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x0F7B


; file 0x40F7B
    push ds
    mov  di,0x0200
    mov  ax,ds
    mov  es,ax
    mov  si,0x0f94
    mov  ax,0xc000
    mov  ds,ax
    mov  cx,0x0052       ; 164 bytes
    nop
    rep  movsw
    pop  ds
    pop  es
    ret
