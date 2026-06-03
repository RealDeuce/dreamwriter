; Generated from disasm: 3000:7F96-8231
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x7F96


; helper call targets covered by later slices
inflection_helper_tail_C3000_8264equ 0x8264
multiword_expansion_C3000_84A8 equ 0x84A8

suffix_extended_final_letter_C3000_7F96:
; file 0x37F96
    mov byte [di],0x0
    jmp 0x7e74
    push bp
    mov bp,sp
    push di
    push si
    mov si,[bp+0x4]
    mov di,[bp+0x6]
    cmp byte [di-0x1],0x69
    jnz loc_7FC8
    mov byte [di-0x1],0x79
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jz loc_7FC4
    mov ax,0x1
    pop si
    pop di
    pop bp
    ret
    nop
loc_7FC4:
    mov byte [di-0x1],0x69
loc_7FC8:
    push si
    call 0xb0e6
    add sp,byte +0x2
    pop si
    pop di
    pop bp
    ret
    nop
    push bp
    mov bp,sp
    push di
    push si
    mov si,[bp+0x4]
    mov di,[bp+0x6]
    mov al,[di-0x1]
    sub ah,ah
    cmp ax,0x62
    jz loc_8048
    cmp ax,0x69
    jz loc_7FF8
    cmp ax,0x6c
    jz loc_8008
loc_7FF3:
    mov byte [di],0x0
    jmp short loc_7FFC
loc_7FF8:
    mov byte [di-0x1],0x79
loc_7FFC:
    push si
    call 0xb0e6
    add sp,byte +0x2
    pop si
    pop di
    pop bp
    ret
    nop
loc_8008:
    cmp byte [di-0x2],0x61
    jnz loc_802E
    cmp byte [di-0x3],0x63
    jnz loc_802E
    sub di,byte +0x2
    mov byte [di],0x0
    mov ax,0x2aee
    push ax
    mov ax,0x2aef
    push ax
    push di
    push si
    call multiword_expansion_C3000_84A8
    add sp,byte +0x8
    pop si
    pop di
    pop bp
    ret
loc_802E:
    mov byte [di],0x6c
    mov byte [di+0x1],0x0
loc_8035:
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jz loc_7FF3
    mov ax,0x1
    pop si
    pop di
    pop bp
    ret
    nop
loc_8048:
    mov ax,0x2af2
    push ax
    push di
    call 0x960a
    add sp,byte +0x4
    jmp short loc_8035
    nop
    push bp
    mov bp,sp
    sub sp,byte +0x30
    push di
    push si
    mov si,[bp+0x4]
    mov di,[bp+0x6]
    mov bx,[0x7180]
    cmp word [bx+0x6],byte +0xb
    jnz loc_808C
    mov ax,0x2af5
    push ax
    push di
    call 0x960a
    add sp,byte +0x4
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jnz loc_80AC
loc_8084:
    sub ax,ax
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
loc_808C:
    mov bx,[0x7180]
    cmp word [bx+0x6],byte +0xd
    jnz loc_80AC
    mov ax,0x2af9
    push ax
    push di
    call 0x960a
    add sp,byte +0x4
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jz loc_8084
loc_80AC:
    mov byte [di],0x0
    mov al,[di-0x1]
    sub ah,ah
    sub ax,0x61
    cmp ax,0x18
    jna loc_80BF
    jmp inflection_helper_tail_C3000_8264
loc_80BF:
    add ax,ax
    xchg ax,bx
    jmp [cs:bx-0x7dce]
    nop
    mov byte [di-0x1],0x79
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jz loc_80E0
loc_80D7:
    mov ax,0x1
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
loc_80E0:
    mov byte [di-0x1],0x69
loc_80E4:
    mov byte [di],0x65
    inc di
    mov byte [di],0x0
loc_80EB:
    push si
    call 0xb0e6
    add sp,byte +0x2
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
    cmp byte [di-0x2],0x65
    jz loc_80EB
    mov bx,[0x7180]
    test byte [bx+0x4],0x1
    jnz loc_80E4
loc_8108:
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jnz loc_80D7
    jmp short loc_80E4
    nop
    mov byte [di],0x65
    inc di
    mov byte [di],0x0
loc_811D:
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jnz loc_80D7
    mov byte [di-0x1],0x0
    jmp short loc_80EB
    mov bx,[0x7180]
    cmp word [bx+0x6],byte +0x17
    jnz loc_816D
    mov ax,0x2afc
    push ax
    lea ax,[bp-0x18]
    push ax
    call 0x960a
    add sp,byte +0x4
    mov byte [bp-0x30],0x79
    mov byte [bp-0x2f],0x0
    dec di
    mov byte [di],0x0
    lea ax,[bp-0x30]
    push ax
    lea ax,[bp-0x18]
    push ax
    push di
    push si
    call multiword_expansion_C3000_84A8
    add sp,byte +0x8
    or ax,ax
    jz loc_8169
    jmp loc_80D7
loc_8169:
    mov byte [di],0x79
    inc di
loc_816D:
    mov byte [bp-0x30],0x65
    sub al,al
    mov [bp-0x2f],al
    mov [bp-0x18],al
    lea ax,[bp-0x30]
    push ax
    lea ax,[bp-0x18]
    push ax
    push di
    push si
    call multiword_expansion_C3000_84A8
    add sp,byte +0x8
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
    nop
    mov bx,[0x7180]
    test word [bx+0x4],0xc00
    jnz loc_819E
    jmp loc_80EB
loc_819E:
    jmp short loc_816D
    cmp byte [di-0x2],0x74
    jz loc_81A9
    jmp loc_8108
loc_81A9:
    mov bx,[0x7180]
    test word [bx+0x4],0xc00
    jnz loc_81B7
    jmp loc_8108
loc_81B7:
    mov byte [di],0x65
    inc di
    mov byte [di],0x0
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jz loc_81CC
    jmp loc_80D7
loc_81CC:
    dec di
    mov byte [di],0x0
    jmp loc_8108
    nop
    cmp byte [di-0x2],0x63
    jz loc_81DD
    jmp inflection_helper_tail_C3000_8264
loc_81DD:
    jmp loc_811D
    mov ax,0x1
    mov cl,[di-0x2]
    sub cl,0x61
    shl ax,cl
    cwd
    and ax,0x4111
    and dx,0x110
    or dx,ax
    jz inflection_helper_tail_C3000_8264
    push si
    call 0x5260
    add sp,byte +0x2
    cmp ax,0x4
    jnl inflection_helper_tail_C3000_8264
    mov al,[di-0x1]
    mov [di],al
    mov ax,0x2aff
    push ax
    lea ax,[di+0x1]
    push ax
    call 0x960a
    add sp,byte +0x4
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jz loc_822C
    mov byte [di],0x65
    mov byte [di+0x1],0x0
    jmp loc_80EB
    nop
loc_822C:
    mov byte [di],0x0
    jmp short inflection_helper_tail_C3000_8264
    nop
