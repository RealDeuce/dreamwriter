; Generated from disasm: 3000:7164-742E
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x7164


; helper call targets covered by later slices
suffix_compound_builder_C3000_7686equ 0x7686

suffix_cely_helper_C3000_7164:
; file 0x37164
    push bp
    mov  bp,sp
    push di
    push si
    mov  si,[bp+0x4]
    mov  di,[bp+0x6]
    mov  al,[di-0x1]
    sub  ah,ah
    cmp  ax,0x63
    jz   loc_71EE
    cmp  ax,0x65
    jz   loc_71CE
    cmp  ax,0x6c
    jz   loc_71BA
    cmp  ax,0x79
    jnz  loc_71C1
    mov  byte [di-0x1],0x69
    push word [bp+0x8]
    push di
    call 0x960a
    add  sp,byte +0x4
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jz   loc_71AA
loc_71A1:
    mov  ax,0x1
    pop  si
    pop  di
    pop  bp
    ret
    nop
    nop
loc_71AA:
    mov  byte [di-0x1],0x79
loc_71AE:
    push si
    call 0xb0e6
    add  sp,byte +0x2
    pop  si
    pop  di
    pop  bp
    ret
    nop
loc_71BA:
    cmp  byte [di-0x2],0x6c
    jnz  loc_71C1
    dec  di
loc_71C1:
    push word [bp+0x8]
loc_71C4:
    push di
    call 0x960a
    add  sp,byte +0x4
    jmp  loc_71AE
    nop
loc_71CE:
    cmp  byte [di-0x2],0x6c
    jnz  loc_71C1
    cmp  byte [di-0x3],0x62
    jnz  loc_71C1
    mov  byte [di-0x1],0x79
    mov  byte [di],0
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jnz  loc_71A1
    jmp  loc_71C1
loc_71EE:
    push word [bp+0x8]
    push di
    call 0x960a
    add  sp,byte +0x4
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jnz  loc_71A1
    cmp  byte [di-0x2],0x69
    jz   loc_720F
    cmp  byte [di-0x2],0x61
    jnz  loc_7216
loc_720F:
    mov  ax,0x25b3
    push ax
    jmp  loc_71C4
    nop
loc_7216:
    sub  ax,ax
    pop  si
    pop  di
    pop  bp
    ret
suffix_ay_dispatch_C3000_721C:
; file 0x3721C
    push bp
    mov  bp,sp
    sub  sp,byte +0x30
    push di
    push si
    mov  si,[bp+0x4]
    mov  di,[bp+0x6]
    mov  bx,[0x7134]
    cmp  word [bx+0x6],byte +0x13
    jnz  loc_7272
    push word [bp+0x8]
    push di
    call 0x960a
    add  sp,byte +0x4
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jz   loc_7252
loc_7249:
    mov  ax,0x1
    pop  si
    pop  di
    mov  sp,bp
    pop  bp
    ret
loc_7252:
    cmp  byte [di-0x1],0x79
    jnz  loc_726A
    mov  byte [di-0x1],0x69
loc_725C:
    push si
    call 0xb0e6
    add  sp,byte +0x2
    pop  si
    pop  di
    mov  sp,bp
    pop  bp
    ret
    nop
loc_726A:
    sub  ax,ax
    pop  si
    pop  di
    mov  sp,bp
    pop  bp
    ret
loc_7272:
    mov  al,[di-0x1]
    sub  ah,ah
    sub  ax,0x61
    cmp  ax,0x18
    jna  loc_7282
    jmp  loc_73D4
loc_7282:
    add  ax,ax
    xchg ax,bx
    jmp  [cs:bx+0x73f2]
suffix_ay_handlers_C3000_728A:
; file 0x3728A
    mov  byte [di-0x1],0x69
    push word [bp+0x8]
    push di
    call 0x960a
    add  sp,byte +0x4
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jnz  loc_7249
    mov  byte [di-0x1],0x79
    jmp  suffix_ay_common_retry_C3000_7424
    mov  bx,[0x7134]
    cmp  word [bx+0x6],byte +0x17
    jnz  loc_731E
    cmp  byte [di-0x2],0x69
    jnz  loc_7300
    sub  di,byte +0x2
    push word [bp+0x8]
    push di
    lea  ax,[bp-0x30]
    push ax
    call 0x960a
    add  sp,byte +0x4
    push ax
    call 0x960a
    add  sp,byte +0x4
    mov  byte [bp-0x18],0x79
    push word [bp+0x8]
    lea  ax,[bp-0x17]
    push ax
    call 0x960a
    add  sp,byte +0x4
    lea  ax,[bp-0x30]
    push ax
    lea  ax,[bp-0x18]
    push ax
    push di
    push si
    call suffix_compound_builder_C3000_7686
    add  sp,byte +0x8
    or   ax,ax
    jz   loc_72FA
    jmp  loc_7249
loc_72FA:
    add  di,byte +0x2
    jmp  loc_731E
    nop
loc_7300:
    cmp  byte [di-0x2],0x79
    jnz  loc_731E
    push word [bp+0x8]
    push di
    call 0x960a
    add  sp,byte +0x4
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jz   loc_731E
    jmp  loc_7249
loc_731E:
    dec  di
    push word [bp+0x8]
    push di
    call 0x960a
    add  sp,byte +0x4
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jz   loc_7337
    jmp  loc_7249
loc_7337:
    mov  byte [di],0x65
    inc  di
    jmp  suffix_ay_common_retry_C3000_7424
suffix_ay_small_handlers_C3000_733E:
; file 0x3733E
    push word [bp+0x8]
    push di
    call 0x960a
    add  sp,byte +0x4
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jnz  loc_7356
    jmp  suffix_ay_common_retry_C3000_7424
loc_7356:
    jmp  loc_7249
    nop
    cmp  byte [di-0x2],0x61
    jz   loc_7366
    cmp  byte [di-0x2],0x69
    jnz  loc_7382
loc_7366:
    mov  byte [di],0x6b
    inc  di
    push word [bp+0x8]
    push di
    call 0x960a
    add  sp,byte +0x4
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jz   loc_7382
    jmp  loc_7249
loc_7382:
    dec  di
    jmp  suffix_ay_common_retry_C3000_7424
    push word [bp+0x8]
    lea  ax,[bp-0x18]
    push ax
    call 0x960a
    add  sp,byte +0x4
    mov  al,[di-0x1]
    mov  [bp-0x30],al
    push word [bp+0x8]
    lea  ax,[bp-0x2f]
    push ax
    call 0x960a
    add  sp,byte +0x4
    lea  ax,[bp-0x30]
    push ax
    lea  ax,[bp-0x18]
    push ax
    push di
    push si
    call suffix_compound_builder_C3000_7686
    add  sp,byte +0x8
    pop  si
    pop  di
    mov  sp,bp
    pop  bp
    ret
    push word [bp+0x8]
    push di
    call 0x960a
    add  sp,byte +0x4
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jz   loc_73D4
    jmp  loc_7249
loc_73D4:
    mov  al,[di-0x1]
    mov  [di],al
    inc  di
    push word [bp+0x8]
    push di
    call 0x960a
    add  sp,byte +0x4
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jz   loc_7382
    jmp  loc_7249
suffix_ay_common_retry_C3000_7424:
; file 0x37424
    push word [bp+0x8]
    push di
    call 0x960a
    add  sp,byte +0x4
    jmp  loc_725C
