; Generated from disasm: 3000:6ECE-7163
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x6ECE


suffix_final_letter_dispatch_C3000_6ECE:
; file 0x36ECE
    push bp
    mov  bp,sp
    sub  sp,byte +0x30
    push di
    push si
    mov  si,[bp+0x4]
    mov  di,[bp+0x6]
    mov  al,[di-0x1]
    sub  ah,ah
    sub  ax,0x65
    cmp  ax,0x15
    jna  loc_6EEC
    jmp  loc_7150
loc_6EEC:
    add  ax,ax
    xchg ax,bx
    jmp  [cs:bx+0x7124]
suffix_simple_mutations_C3000_6EF4:
; file 0x36EF4
    mov  byte [di],0x73
    mov  byte [di+0x1],0
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jz   loc_6F10
loc_6F06:
    mov  ax,0x1
    pop  si
    pop  di
    mov  sp,bp
    pop  bp
    ret
    nop
loc_6F10:
    mov  byte [di-0x1],0x69
loc_6F14:
    mov  byte [di],0x65
    inc  di
    jmp  loc_7150
    nop
    mov  byte [di],0x73
    mov  byte [di+0x1],0
loc_6F23:
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jz   loc_6F14
    jmp  loc_6F06
suffix_s_handler_C3000_6F30:
; file 0x36F30
    cmp  byte [di-0x2],0x69
    jnz  loc_6F52
    cmp  byte [di-0x3],0x73
    jnz  loc_6F52
    mov  byte [di-0x2],0x65
    mov  byte [di],0
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jnz  loc_6F06
    mov  byte [di-0x2],0x69
loc_6F52:
    cmp  byte [di-0x2],0x75
    jnz  loc_6F79
    cmp  word [bp+0x8],byte +0x5
    jnz  loc_6F79
    mov  byte [di-0x2],0x69
    mov  byte [di-0x1],0
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jnz  loc_6F06
    mov  byte [di-0x2],0x75
    mov  byte [di-0x1],0x73
loc_6F79:
    mov  ax,0x25a7
loc_6F7C:
    push ax
    push di
    call 0x960a
    add  sp,byte +0x4
    jmp  loc_6F23
suffix_x_u_combination_C3000_6F86:
; file 0x36F86
    cmp  byte [di-0x2],0x69
    jz   loc_6F92
    cmp  byte [di-0x2],0x65
    jnz  loc_6FDC
loc_6F92:
    cmp  word [bp+0x8],byte +0x5
    jnz  loc_6FDC
    mov  al,[di-0x2]
    mov  [bp-0x18],al
    mov  ax,0x25ab
    push ax
    lea  ax,[bp-0x17]
    push ax
    call 0x960a
    add  sp,byte +0x4
    lea  ax,[bp-0x18]
    push ax
    lea  ax,[bp-0x30]
    push ax
    call 0x960a
    add  sp,byte +0x4
    mov  byte [bp-0x30],0x69
    mov  byte [bp-0x2f],0x63
loc_6FC2:
    lea  ax,[bp-0x30]
    push ax
    lea  ax,[bp-0x18]
    push ax
    lea  ax,[di-0x2]
    push ax
loc_6FCE:
    push si
    call 0x7686
    add  sp,byte +0x8
    pop  si
    pop  di
    mov  sp,bp
    pop  bp
    ret
    nop
loc_6FDC:
    mov  byte [di],0x65
    inc  di
    mov  byte [di],0x73
    inc  di
    mov  byte [di],0
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jz   loc_6FF5
    jmp  loc_6F06
loc_6FF5:
    mov  byte [si],0
    mov  byte [bp-0x18],0x73
    mov  byte [bp-0x30],0x78
    sub  al,al
    mov  [bp-0x2f],al
    mov  [bp-0x17],al
loc_7008:
    lea  ax,[bp-0x30]
    push ax
    lea  ax,[bp-0x18]
    push ax
    push di
    jmp  loc_6FCE
    nop
    mov  ax,0x25af
    jmp  loc_6F7C
suffix_remaining_handlers_C3000_701A:
; file 0x3701A
    cmp  byte [di-0x2],0x66
    jnz  loc_7023
    jmp  loc_7150
loc_7023:
    mov  byte [di],0x73
    inc  di
    mov  byte [di],0
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jz   loc_7038
    jmp  loc_6F06
loc_7038:
    sub  di,byte +0x2
    mov  byte [di],0x76
    inc  di
    jmp  loc_6F14
    cmp  byte [di-0x3],0x65
    jnz  loc_7051
    cmp  byte [di-0x2],0x73
    jnz  loc_7051
    jmp  loc_6F06
loc_7051:
    mov  byte [di],0x73
    mov  byte [di+0x1],0
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jz   loc_7066
    jmp  loc_6F06
loc_7066:
    cmp  byte [di-0x2],0x66
    jnz  loc_707E
    mov  byte [di-0x2],0x76
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jz   loc_707E
    jmp  loc_6F06
loc_707E:
    sub  ax,ax
    pop  si
    pop  di
    mov  sp,bp
    pop  bp
    ret
    cmp  word [bp+0x8],byte +0xa
    jnz  loc_70C0
    mov  ax,0x1
    mov  cl,[di-0x2]
    sub  cl,0x61
    shl  ax,cl
    cwd
    and  ax,0x4111
    and  dx,0x110
    or   dx,ax
    jnz  loc_70C0
    mov  byte [di],0x65
    mov  byte [di+0x1],0x73
    mov  byte [di+0x2],0
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jnz  loc_70BC
    jmp  loc_7150
loc_70BC:
    jmp  loc_6F06
    nop
loc_70C0:
    mov  byte [bp-0x18],0x65
    mov  byte [bp-0x17],0x73
    mov  byte [bp-0x30],0x73
    sub  al,al
    mov  [bp-0x2f],al
    mov  [bp-0x16],al
    jmp  loc_7008
    nop
    cmp  byte [di-0x2],0x61
    jnz  loc_7150
    cmp  byte [di-0x3],0x6d
    jnz  loc_7150
    mov  byte [di-0x2],0x65
    push si
    call 0xb0e6
    add  sp,byte +0x2
    or   ax,ax
    jz   loc_70F6
    jmp  loc_6F06
loc_70F6:
    mov  byte [di-0x2],0x61
    jmp  loc_7150
    cmp  byte [di-0x2],0x75
    jnz  loc_7150
    cmp  word [bp+0x8],byte +0x5
    jnz  loc_7150
    mov  byte [bp-0x18],0x75
    mov  byte [bp-0x17],0x6d
    mov  byte [bp-0x16],0x73
    mov  byte [bp-0x30],0x61
    sub  al,al
    mov  [bp-0x2f],al
    mov  [bp-0x15],al
    jmp  loc_6FC2
suffix_default_s_check_C3000_7150:
; file 0x37150
loc_7150:
    mov  byte [di],0x73
    inc  di
    mov  byte [di],0
    push si
    call 0xb0e6
    add  sp,byte +0x2
    pop  si
    pop  di
    mov  sp,bp
    pop  bp
    ret
