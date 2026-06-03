; Generated from disasm: 3000:6964-A393
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x6964


candidate_formatter_callsite_C3000_A374:
; file 0x3A374
    push word [bp+0x8]
    mov  ax,[bp+0x6]
    inc  ax
    push ax
    lea  ax,[bp-0xce]
    push ax
    mov  ax,0x7767
    push ax
    call candidate_row_formatter_C3000_6964
    add  sp,byte +0x8
    lea  ax,[bp-0xce]
    push ax
    push word [bp+0x8]
    call loc_960A
candidate_row_formatter_C3000_6964:
; file 0x36964
    push bp
    mov  bp,sp
    sub  sp,byte +0xa
    push di
    push si
    mov  si,[bp+0x6]
    mov  al,[bp+0x8]
    add  al,0x30
    mov  [si],al
    inc  si
    mov  byte [si],0x29
    inc  si
    mov  byte [si],0x20
    inc  si
    mov  bx,[bp+0xa]
    inc  word [bp+0xa]
    mov  al,[bx]
    sub  ah,ah
    dec  ax
    mov  [bp-0x2],ax
    mov  bx,[bp+0xa]
    inc  word [bp+0xa]
    mov  al,[bx]
    sub  ah,ah
    mov  di,ax
    or   di,di
    jnz  loc_69CA
    push word [bp-0x2]
    push si
    call candidate_selector_label_C3000_6B40
    add  sp,byte +0x4
    mov  si,ax
    jmp  loc_69B0
    nop
loc_69AC:
    mov  byte [si],0x20
    inc  si
loc_69B0:
    mov  ax,si
    sub  ax,[bp+0x6]
    cmp  ax,0xe
    jl   loc_69AC
    push word [bp+0xa]
    push si
    call loc_960A
    add  sp,byte +0x4
    pop  si
    pop  di
    mov  sp,bp
    pop  bp
    ret
loc_69CA:
    mov  ax,[bp+0xa]
    mov  [bp-0xa],ax
    push ax
    call loc_9626
    add  sp,byte +0x2
    inc  ax
    mov  [bp+0xa],ax
    mov  word [bp-0x6],0
    mov  ax,[bp-0x2]
    cmp  ax,0xb
    ja   candidate_formatter_row_bodies_C3000_6A36
    add  ax,ax
    xchg ax,bx
    jmp  [cs:bx+0x6a1e]
candidate_formatter_selector_tests_C3000_69F0:
; file 0x369F0
    cmp  di,byte +0x7
    jz   loc_6A0A
    cmp  di,byte +0x1b
    jz   loc_6A0A
loc_69FA:
    mov  ax,0x1
    jmp  loc_6A0C
    nop
    cmp  di,byte +0xf
    jz   loc_69FA
    cmp  di,byte +0x9
    jz   loc_69FA
loc_6A0A:
    sub  ax,ax
loc_6A0C:
    mov  [bp-0x6],ax
    jmp  candidate_formatter_row_bodies_C3000_6A36
    nop
    cmp  di,byte +0xb
    jz   loc_6A0A
    cmp  di,byte +0xd
    jnz  loc_69FA
    jmp  loc_6A0A
candidate_formatter_row_bodies_C3000_6A36:
; file 0x36A36
    cmp  word [bp-0x6],byte +0x0
    jz   loc_6A3F
    jmp  loc_6AC4
loc_6A3F:
    push word [bp-0x2]
    push si
    call candidate_selector_label_C3000_6B40
    add  sp,byte +0x4
    mov  si,ax
    jmp  loc_6A52
    nop
loc_6A4E:
    mov  byte [si],0x20
    inc  si
loc_6A52:
    mov  ax,si
    sub  ax,[bp+0x6]
    cmp  ax,0xe
    jl   loc_6A4E
    cmp  di,byte +0x7
    jnz  loc_6A96
    cmp  word [bp-0x2],byte +0xa
    jz   loc_6A6D
    cmp  word [bp-0x2],byte +0xb
    jnz  loc_6A96
loc_6A6D:
    push word [0x256e]
    push si
    call loc_960A
    add  sp,byte +0x4
    mov  si,ax
loc_6A7A:
    mov  ax,0x2584
    push ax
    push si
    call loc_960A
    add  sp,byte +0x4
    mov  si,ax
    push word [bp-0xa]
    push si
    call loc_960A
    add  sp,byte +0x4
    mov  si,ax
    jmp  loc_6B26
loc_6A96:
    mov  bx,di
    shl  bx,1
    push word [bx+0x2544]
    push si
    call loc_960A
    add  sp,byte +0x4
    mov  si,ax
    push word [bp-0xa]
    push word [bp+0x4]
    call loc_969E
    add  sp,byte +0x4
    or   ax,ax
    jnz  loc_6A7A
    cmp  di,byte +0x7
    jz   loc_6B26
    cmp  di,byte +0x1b
    jz   loc_6B26
    jmp  loc_6A7A
    nop
loc_6AC4:
    mov  bx,di
    shl  bx,1
    push word [bx+0x2544]
    push si
    call loc_960A
    add  sp,byte +0x4
    mov  si,ax
    jmp  loc_6ADC
    nop
loc_6AD8:
    mov  byte [si],0x20
    inc  si
loc_6ADC:
    mov  ax,si
    sub  ax,[bp+0x6]
    cmp  ax,0xd
    jl   loc_6AD8
    mov  ax,0x2584
    push ax
    push si
    call loc_960A
    add  sp,byte +0x4
    mov  si,ax
    push word [bp-0xa]
    push si
    call loc_960A
    add  sp,byte +0x4
    mov  si,ax
    mov  ax,0x24f4
    push ax
    push si
    call loc_960A
    add  sp,byte +0x4
    mov  si,ax
    mov  bx,[bp-0x2]
    shl  bx,1
    push word [bx+0x2508]
    push si
    call loc_960A
    add  sp,byte +0x4
    mov  si,ax
    mov  byte [si],0x29
    inc  si
    mov  byte [si],0x20
    inc  si
loc_6B26:
    mov  byte [si],0x3a
    inc  si
    mov  byte [si],0x20
    inc  si
    push word [bp+0xa]
    push si
    call loc_960A
    add  sp,byte +0x4
    mov  si,ax
    pop  si
    pop  di
    mov  sp,bp
    pop  bp
    ret
candidate_selector_label_C3000_6B40:
; file 0x36B40
    push bp
    mov  bp,sp
    cmp  word [bp+0x6],byte +0x0
    jl   loc_6B51
    mov  ax,[0x2522]
    cmp  [bp+0x6],ax
    jl   loc_6B60
loc_6B51:
    mov  ax,0x2589
    push ax
loc_6B55:
    push word [bp+0x4]
    call loc_960A
    add  sp,byte +0x4
    pop  bp
    ret
loc_6B60:
    mov  bx,[bp+0x6]
    shl  bx,1
    push word [bx+0x2508]
    jmp  loc_6B55
