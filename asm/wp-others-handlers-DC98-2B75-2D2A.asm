; Generated from disasm: DC98:2B75-2D2A
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x2B75


rom_card_loader_DC98_2B75:
; file 0x5F4F5
    push bp
    mov  bp,sp
    sub  sp,0x44
    push cx
    push dx
    push si
    push di
    call DC98:0E70
    lea  bx,[bp-0x14]
    mov  word [bp-0x18],0
    mov  word [bp-0x16],0xef7a ; EF7A:0000
    mov  ax,0
    mov  es,ax
    mov  al,[es:0x6805]
    inc  al
    mov  [bx],al
    inc  bx
    mov  byte [bx],':'
...
    call DC98:EF7B        ; find first
    test ax,ax
    jz   DC98:2C1B        ; found
    mov  ax,0
    mov  es,ax
    mov  al,[es:0x6805]
    mov  [bp-0x14],al
...
    call DC98:EF7B        ; fallback find first
    test ax,ax
    jz   DC98:2C1B        ; found
    mov  ax,0
    mov  bx,0xef96
    mov  cx,0x00a2
    mov  dx,0x0014
    call DC98:0E81
    mov  ax,0x000c
    mov  bx,0xef97
    mov  cx,0x00b7
    mov  dx,0x0028
    call DC98:0E81
    call DC98:0CF9
    call C688:01E6
    mov  di,ax           ; byte work-memory limit
    xor  bx,bx
    mov  ax,di
    sub  ax,[bp-0x29]    ; file size low
    sbb  bx,[bp-0x27]    ; file size high
    jnl  DC98:2C69
    call C688:020C
...
    xor  ax,ax
    push ax              ; mode 0
    lea  ax,[bp-0x14]
    push ax
    call DC98:E946        ; open
    mov  si,ax           ; handle
    cmp  si,0
    jnl  DC98:2C9F
...
    mov  ax,si
    mov  bx,0xa4f0
    mov  cx,[bp-0x29]
    call DC98:EE08        ; read
...
    mov  ax,si
    call DC98:EE2E        ; close
    mov  bx,[0xa4f0]
    mov  ax,[0xa4f2]
    cmp  ax,0x1997
    jnz  DC98:2CF2
    cmp  bx,0xa4f0
    jz   DC98:2D13
    call C688:020C
    mov  ax,0x0006
    mov  bx,0xef9d
    mov  cx,0x00bd
    mov  dx,0x0014
    call DC98:0E81
    mov  ax,di
    call C688:022B        ; call far [0xA4F4]
    mov  cx,ax
    call C688:020C
    mov  ax,cx
    pop  di
    pop  si
    pop  dx
    pop  cx
    mov  sp,bp
    pop  bp
    ret
