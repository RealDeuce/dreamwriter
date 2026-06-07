; Generated from disasm: 3000:6B6C-6ECD
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x6B6C


candidate_record_formatter_entry_C3000_6B6C:
; file 0x36B6C
    push bp
    mov  bp,sp
    sub  sp,byte +0x2
    mov  ax,[bp+0xa]
    mov  [0x7134],ax
    or   ax,ax
    jnz  loc_6B82
loc_6B7C:
    sub  ax,ax
    mov  sp,bp
    pop  bp
    ret
loc_6B82:
    push word [bp+0x4]
    push word [bp+0x6]
    call 0x960a
    add  sp,byte +0x4
    mov  bx,[0x7134]
    mov  ax,[bx+0x6]
    mov  [bp-0x2],ax
    cmp  ax,0x1d
    jz   loc_6BA2
    cmp  ax,0x1f
    jnz  loc_6BAA
loc_6BA2:
    mov  ax,0x1
    mov  sp,bp
    pop  bp
    ret
    nop
loc_6BAA:
    mov  ax,0x20
    push ax
    push word [bp+0x6]
    call 0x963a
    add  sp,byte +0x4
    or   ax,ax
    jz   loc_6BE4
    cmp  word [bp-0x2],byte +0x13
    jz   loc_6B7C
    cmp  word [bp-0x2],byte +0xf
    jz   loc_6B7C
    cmp  word [bp-0x2],byte +0x11
    jz   loc_6B7C
    cmp  word [bp-0x2],byte +0x9
    jz   loc_6B7C
    push word [bp+0x8]
    push word [bp+0x6]
    call candidate_record_space_formatter_C3000_6BF0
loc_6BDC:
    add  sp,byte +0x4
    mov  sp,bp
    pop  bp
    ret
    nop
loc_6BE4:
    push word [bp+0x8]
    push word [bp+0x6]
    call candidate_record_no_space_formatter_C3000_6CEC
    jmp  loc_6BDC
candidate_record_space_formatter_C3000_6BF0:
; file 0x36BF0
    push bp
    mov  bp,sp
    sub  sp,byte +0x7e
    push si
    mov  bx,[0x7134]
    mov  ax,[bx+0x6]
    mov  [bp-0x66],ax
    push ax
    lea  ax,[bp-0x64]
    push ax
    push word [bp+0x4]
    call 0xb116
    add  sp,byte +0x6
    mov  [bp-0x1c],ax
    inc  ax
    jz   loc_6C34
    cmp  word [bp-0x1c],byte +0x0
    jnz  loc_6C1E
    jmp  loc_6CE4
loc_6C1E:
    lea  ax,[bp-0x64]
loc_6C21:
    push ax
    push word [bp+0x4]
    call 0x960a
    add  sp,byte +0x4
    mov  ax,0x1
    pop  si
    mov  sp,bp
    pop  bp
    ret
    nop
loc_6C34:
    cmp  word [bp-0x66],byte +0x1
    jnz  loc_6C82
    mov  ax,0x3
    push ax
    lea  ax,[bp-0x4c]
    push ax
    push word [bp+0x4]
    call 0xb116
    add  sp,byte +0x6
    or   ax,ax
    jng  loc_6C82
    mov  ax,0x5
    push ax
    lea  ax,[bp-0x18]
    push ax
    push word [bp+0x4]
    call 0xb116
    add  sp,byte +0x6
    or   ax,ax
    jng  loc_6C82
    lea  ax,[bp-0x4c]
    push ax
    push word [bp+0x4]
    call 0x960a
    add  sp,byte +0x4
    mov  [bp+0x4],ax
    mov  bx,ax
    inc  word [bp+0x4]
    mov  byte [bx],0x2f
    lea  ax,[bp-0x18]
    jmp  loc_6C21
    nop
loc_6C82:
    cmp  word [bp+0x6],byte +0xa
    jnz  loc_6CAA
    mov  ax,0x20
    push ax
    push word [bp+0x4]
    call 0x963a
    add  sp,byte +0x4
    mov  si,ax
    push si
    lea  ax,[bp-0x7e]
    push ax
    call 0x960a
    add  sp,byte +0x4
    mov  byte [si],0
    mov  si,[bp+0x4]
    jmp  loc_6CC4
loc_6CAA:
    cmp  word [bp+0x6],byte +0x5
    jnz  loc_6CE4
    mov  byte [bp-0x7e],0
    mov  ax,0x20
    push ax
    push word [bp+0x4]
    call 0x9666
    add  sp,byte +0x4
    mov  si,ax
    inc  si
loc_6CC4:
    push word [bp+0x6]
    push si
    call candidate_record_no_space_formatter_C3000_6CEC
    add  sp,byte +0x4
    or   ax,ax
    jz   loc_6CE4
    lea  ax,[bp-0x7e]
    push ax
    push word [bp+0x4]
    call 0x78ce
    add  sp,byte +0x4
    pop  si
    mov  sp,bp
    pop  bp
    ret
loc_6CE4:
    sub  ax,ax
    pop  si
    mov  sp,bp
    pop  bp
    ret
candidate_record_no_space_formatter_C3000_6CEC:
; file 0x36CEC
    push bp
    mov  bp,sp
    sub  sp,0x80
    push si
    push word [bp+0x4]
    lea  ax,[bp-0x80]
    push ax
    call 0x960a
    add  sp,byte +0x4
    mov  bx,[0x7134]
    mov  ax,[bx]
    mov  [bp-0x1a],ax
    push word [bp+0x4]
    call 0x9626
    add  sp,byte +0x2
    mov  si,ax
    mov  bx,[0x7134]
    mov  ax,[bx+0x6]
    mov  [bp-0x66],ax
    cmp  ax,0x3
    jz   loc_6D29
    cmp  ax,0x5
    jnz  loc_6D48
loc_6D29:
    mov  ax,0x1
    push ax
    push word [bp+0x4]
    push word [bp+0x4]
    call 0xb116
    add  sp,byte +0x6
    mov  [bp-0x1c],ax
    or   ax,ax
    jng  loc_6D48
loc_6D40:
    mov  ax,0x1
    pop  si
    mov  sp,bp
    pop  bp
    ret
loc_6D48:
    push word [bp-0x66]
    push word [bp+0x4]
    push word [bp+0x4]
    call 0xb116
    add  sp,byte +0x6
    mov  [bp-0x1c],ax
    inc  ax
    jz   loc_6D66
    mov  ax,[bp-0x1c]
    pop  si
    mov  sp,bp
    pop  bp
    ret
    nop
loc_6D66:
    cmp  word [bp-0x66],byte +0x19
    jnz  loc_6D86
    mov  ax,0x1
    push ax
    push word [bp+0x4]
    push word [bp+0x4]
    call 0xb116
    add  sp,byte +0x6
    mov  [bp-0x1c],ax
    or   ax,ax
    jng  loc_6DA3
    jmp  loc_6D40
    nop
loc_6D86:
    cmp  word [bp-0x66],byte +0x1b
    jnz  loc_6DA3
    mov  ax,0x7
    push ax
    push word [bp+0x4]
    push word [bp+0x4]
    call 0xb116
    add  sp,byte +0x6
    mov  [bp-0x1c],ax
    or   ax,ax
    jg   loc_6D40
loc_6DA3:
    cmp  word [bp-0x66],byte +0x1
    jnz  candidate_record_variant_dispatch_C3000_6E04
    mov  ax,0x3
    push ax
    lea  ax,[bp-0x4c]
    push ax
    push word [bp+0x4]
    call 0xb116
    add  sp,byte +0x6
    mov  [bp-0x1c],ax
    or   ax,ax
    jng  candidate_record_variant_dispatch_C3000_6E04
    lea  ax,[bp-0x4c]
    push ax
    call 0x9626
    add  sp,byte +0x2
    mov  si,ax
    mov  ax,0x5
    push ax
    lea  ax,[bp-0x18]
    push ax
    push word [bp+0x4]
    call 0xb116
    add  sp,byte +0x6
    mov  [bp-0x1c],ax
    or   ax,ax
    jng  loc_6DF4
    mov  byte [si],0x2f
    inc  si
    lea  ax,[bp-0x18]
    push ax
    push si
    call 0x960a
    add  sp,byte +0x4
loc_6DF4:
    lea  ax,[bp-0x4c]
    push ax
    push word [bp+0x4]
    call 0x960a
    add  sp,byte +0x4
    jmp  loc_6D40
candidate_record_variant_dispatch_C3000_6E04:
; file 0x36E04
    mov  bx,[0x7134]
    mov  al,[bx+0x3]
    sub  ah,ah
    cmp  ax,0x9
    jna  loc_6E15
    jmp  loc_6E95
loc_6E15:
    add  ax,ax
    xchg ax,bx
    jmp  [cs:bx+0x6e9c]
    nop
    push word [bp-0x1a]
    push si
    push word [bp+0x4]
    call 0x7164
    jmp  loc_6E8E
    cmp  word [bp-0x66],byte +0xb
    jz   loc_6E36
    cmp  word [bp-0x66],byte +0xd
    jnz  loc_6E42
loc_6E36:
    push word [bp-0x1a]
    push si
    push word [bp+0x4]
    call 0x7724
    jmp  loc_6E8E
loc_6E42:
    push word [bp-0x1a]
    push si
    push word [bp+0x4]
    call 0x721c
    add  sp,byte +0x6
    or   ax,ax
    jz   loc_6E95
    jmp  candidate_record_final_confirm_C3000_6EB0
    nop
    push word [bp-0x1a]
    push si
    push word [bp+0x4]
    call 0x7432
    jmp  loc_6E8E
    mov  ax,0x25a2
    push ax
    push si
    push word [bp+0x4]
    call 0x748e
    add  sp,byte +0x6
    or   ax,ax
    jz   loc_6E95
    push word [bp+0x4]
    call 0x5260
    add  sp,byte +0x2
    cmp  ax,0x6
    jnl  candidate_record_final_confirm_C3000_6EB0
    jmp  loc_6E95
    push word [bp+0x6]
    push si
    push word [bp+0x4]
    call 0x6ece
loc_6E8E:
    add  sp,byte +0x6
    or   ax,ax
    jnz  candidate_record_final_confirm_C3000_6EB0
loc_6E95:
    sub  ax,ax
    pop  si
    mov  sp,bp
    pop  bp
    ret
candidate_record_final_confirm_C3000_6EB0:
; file 0x36EB0
    mov  ax,0xff
    push ax
    lea  ax,[bp-0x64]
    push ax
    push word [bp+0x4]
    call 0xb116
    add  sp,byte +0x6
    mov  [bp-0x1c],ax
    or   ax,ax
    jz   loc_6ECB
    jmp  loc_6D40
loc_6ECB:
    jmp  loc_6E95
