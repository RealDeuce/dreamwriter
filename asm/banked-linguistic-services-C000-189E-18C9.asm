; Generated from disasm: C000:189E-18C9
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x189E


linguistic_ah05_adjust_C000_189E:
; file 0x4189E
    add  dl,0x3c

banked_linguistic_mapper_C000_18A1:
    xor  dh,dh
    call 0x1949
    cli
    mov  al,0x2
    out  0x11,al
    mov  ah,al
    mov  al,0x17
    out  0x12,al
    mov  [0x6d8d],ax
    mov  al,0x3
    out  0x13,al
    mov  ah,al
    mov  al,0x2
    out  0x14,al
    mov  [0x6d8f],ax
    call far [cs:0x189a]
    push ax
    mov  al,0xe
    out  0x11,al
banked_linguistic_dispatch_C3000_4AA6:
; file 0x34AA6
