; Generated from disasm: C000:12F8-15FD
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x12F8


; file 0x412F8
    mov  dl,0x58
    push bx
    call C000:18A1
    pop  bx
    jmp  C000:1306

; file 0x41301
    mov  dl,0x59
    call C000:15F0
    mov  byte [0x6ebb],0x50
    mov  dx,0x3000
    mov  [0x6eb9],dx
    mov  dx,0
    mov  [0x6eb7],dx
    jmp  C000:13A1
; file 0x415F0
    push bx
    call C000:18A1
    mov  al,0x03
    out  0x13,al
    mov  al,0x02
    out  0x14,al
    pop  bx
    ret
; file 0x34BF2
