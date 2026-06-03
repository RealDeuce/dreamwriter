; Generated from disasm: DC98:2807-53F5
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x2807


wp_top_menu_DC98_2807:
; file 0x5F187
    push cx
    xor  cx,cx
    mov  word [0x6d81],0xffff
    mov  ax,0x000c
    mov  bx,0xefa7
    call DC98:124C
    mov  word [0x6d81],0
    cmp  ax,0x31
    jnz  DC98:282A
    xor  ax,ax
    jmp  DC98:2885
    cmp  ax,0x32
    jnz  DC98:2843
    call DC98:275A
...
    call C688:EB46
...
    call DC98:265D
...
    call DC98:26B8
...
    call DC98:2D2B
...
    pop  cx
    retf
organizer_top_menu_DC98_53C3:
; file 0x61D43
    push cx
    cmp  byte [0x8a50],0x4f
    jnz  DC98:53D9
    cmp  byte [0x8a51],0x39
    jnz  DC98:53D9
    cmp  byte [0x8a52],0x32
    jz   DC98:53DE
    call DC98:539E
    mov  word [0x6d81],0xffff
    mov  ax,0x000c
    mov  bx,0xf08b
    mov  cx,[0x82a6]
    call DC98:124C
    mov  cx,ax
    mov  word [0x6d81],0
