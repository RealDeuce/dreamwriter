; Generated from disasm: 3000:7432-7723
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x7432


suffix_compact_helper_C3000_7432:
; file 0x37432
    push bp
    mov  bp,sp
    push di
    push si
    mov  si,[bp+0x4]
    mov  di,[bp+0x6]
    push word [bp+0x8]
    push di
    call 0x960a
    add  sp,byte +0x4
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jz   loc_745A
    mov  ax,0x1
    pop  si
    pop  di
    pop  bp
    ret
    nop
loc_745A:
    mov  byte [di],0
    mov  ax,0x25b8
    push ax
    lea  ax,[di-0x3]
    push ax
    call 0x969e
    add  sp,byte +0x4
    or   ax,ax
    jnz  loc_7488
    push word [bp+0x8]
    lea  ax,[di-0x1]
    push ax
    call 0x960a
    add  sp,byte +0x4
    push si
    call 0xb0e6
    add  sp,byte +0x2
    pop  si
    pop  di
    pop  bp
    ret
    nop
loc_7488:
    sub  ax,ax
    pop  si
    pop  di
    pop  bp
    ret
suffix_by_dispatch_C3000_748E:
; file 0x3748E
    push bp
    mov  bp,sp
    sub  sp,byte +0x18
    push di
    push si
    mov  si,[bp+0x4]
    mov  di,[bp+0x6]
    push word [bp+0x8]
    lea  ax,[bp-0x18]
    push ax
    call 0x960a
    add  sp,byte +0x4
    mov  byte [bp-0x18],0x69
    mov  al,[di-0x2]
    cmp  [di-0x1],al
    jnz  loc_74CC
loc_74B5:
    push word [bp+0x8]
loc_74B8:
    push di
    call 0x960a
    add  sp,byte +0x4
    push si
    call 0xb0e6
    add  sp,byte +0x2
    pop  si
    pop  di
    mov  sp,bp
    pop  bp
    ret
loc_74CC:
    mov  al,[di-0x1]
    sub  ah,ah
    sub  ax,0x62
    cmp  ax,0x17
    jna  loc_74DC
    jmp  loc_7666
loc_74DC:
    add  ax,ax
    xchg ax,bx
    jmp  [cs:bx+0x7636]
suffix_by_local_handlers_C3000_74E4:
; file 0x374E4
    mov  byte [di-0x1],0x69
    push word [bp+0x8]
    push di
    call 0x960a
    add  sp,byte +0x4
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jz   loc_7506
loc_74FD:
    mov  ax,0x1
    pop  si
    pop  di
    mov  sp,bp
    pop  bp
    ret
loc_7506:
    mov  byte [di-0x1],0x79
    jmp  loc_7666
    nop
    mov  al,[di-0x1]
    mov  [di],al
    push word [bp+0x8]
    lea  ax,[di+0x1]
    push ax
    call 0x960a
    add  sp,byte +0x4
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jnz  loc_74FD
    lea  ax,[bp-0x18]
    push ax
    push di
    call 0x960a
    add  sp,byte +0x4
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jnz  loc_74FD
    mov  byte [di-0x1],0x73
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jnz  loc_74FD
    mov  byte [di-0x1],0x64
    jmp  loc_74B5
suffix_by_t_e_handlers_C3000_7558:
; file 0x37558
    mov  al,[di-0x1]
    mov  [di],al
    push word [bp+0x8]
    lea  ax,[di+0x1]
    push ax
    call 0x960a
    add  sp,byte +0x4
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jnz  loc_74FD
    cmp  byte [di-0x2],0x69
    jnz  loc_75A2
    mov  byte [di-0x1],0x73
    mov  byte [di],0x73
    lea  ax,[bp-0x18]
    push ax
    lea  ax,[di+0x1]
    push ax
    call 0x960a
    add  sp,byte +0x4
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jz   loc_759E
    jmp  loc_74FD
loc_759E:
    mov  byte [di-0x1],0x74
loc_75A2:
    lea  ax,[bp-0x18]
    push ax
    push di
loc_75A7:
    call 0x960a
    add  sp,byte +0x4
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jz   loc_75BB
    jmp  loc_74FD
loc_75BB:
    jmp  loc_74B5
    mov  al,[di-0x1]
    mov  [di],al
    push word [bp+0x8]
    lea  ax,[di+0x1]
    push ax
    jmp  loc_75A7
    push word [bp+0x8]
    lea  ax,[di-0x1]
    push ax
    call 0x960a
    add  sp,byte +0x4
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jz   loc_75E7
    jmp  loc_74FD
loc_75E7:
    lea  ax,[bp-0x18]
    push ax
    lea  ax,[di-0x1]
    push ax
    call 0x960a
    add  sp,byte +0x4
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jz   loc_7603
    jmp  loc_74FD
loc_7603:
    cmp  byte [di-0x3],0x61
    jnz  loc_762E
    cmp  byte [di-0x2],0x74
    jnz  loc_762E
    push word [bp+0x8]
    lea  ax,[di-0x3]
    push ax
    call 0x960a
    add  sp,byte +0x4
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jz   loc_762A
    jmp  loc_74FD
loc_762A:
    mov  byte [di-0x2],0x74
loc_762E:
    mov  byte [di-0x1],0x65
    jmp  loc_74B5
suffix_by_common_fallback_C3000_7666:
; file 0x37666
loc_7666:
    push word [bp+0x8]
    push di
    call 0x960a
    add  sp,byte +0x4
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jz   loc_767E
    jmp  loc_74FD
loc_767E:
    lea  ax,[bp-0x18]
    push ax
    jmp  loc_74B8
suffix_compound_builder_C3000_7686:
; file 0x37686
    push bp
    mov  bp,sp
    sub  sp,byte +0x34
    push di
    push si
    mov  si,[bp+0x4]
    mov  di,[bp+0x6]
    mov  byte [di],0
    lea  ax,[bp-0x34]
    mov  [bp-0x2],ax
    push word [bp+0x8]
    push si
    lea  ax,[bp-0x34]
    push ax
    call 0x960a
    add  sp,byte +0x4
    push ax
    call 0x960a
    add  sp,byte +0x4
    inc  ax
    mov  [bp-0x4],ax
    push word [bp+0xa]
    push si
    push ax
    call 0x960a
    add  sp,byte +0x4
    push ax
    call 0x960a
    add  sp,byte +0x4
    push word [bp-0x2]
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jnz  loc_76DB
    mov  ax,[bp-0x4]
    mov  [bp-0x2],ax
loc_76DB:
    push word [bp-0x4]
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jnz  loc_76EE
    mov  bx,[bp-0x4]
    mov  byte [bx],0
loc_76EE:
    mov  bx,[bp-0x2]
    cmp  byte [bx],0
    jz   loc_771C
    mov  ax,[bp-0x4]
    cmp  bx,ax
    jz   loc_7708
    mov  bx,ax
    cmp  byte [bx],0
    jz   loc_7708
    mov  byte [bx-0x1],0xe
loc_7708:
    push word [bp-0x2]
    push si
    call 0x960a
    add  sp,byte +0x4
    mov  ax,0x1
    pop  si
    pop  di
    mov  sp,bp
    pop  bp
    ret
    nop
loc_771C:
    sub  ax,ax
    pop  si
    pop  di
    mov  sp,bp
    pop  bp
    ret
