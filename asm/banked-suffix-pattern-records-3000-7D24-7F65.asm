; Generated from disasm: 3000:7D24-7F65
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x7D24


; helper call targets covered by later slices
suffix_extended_final_letter_C3000_7F96equ 0x7F96
multiword_expansion_C3000_84A8 equ 0x84A8

suffix_pattern_tail_and_lookup_C3000_7D24:
; file 0x37D24
    push word [bp-0x3a]
    push word [bp+0x6]
    push word [bp+0x8]
    push si
    call 0x8438
    add sp,byte +0x8
    mov [bp-0x36],ax
    mov bx,ax
    shl bx,1
    add bx,[bp+0x6]
    mov word [bx],0x0
    cmp word [bp-0x3a],byte +0x0
    jnz loc_7DC1
    jmp short loc_7DB9
loc_7D4A:
    mov bx,[0x7180]
    push word [bx+0x6]
    lea ax,[bp-0x1c]
    push ax
    mov bx,[bp-0x3a]
    shl bx,1
    add bx,[bp+0x6]
    push word [bx]
    call 0xb116
    add sp,byte +0x6
    mov [bp-0x2],ax
    cmp ax,0xffff
    jnz loc_7D92
    mov bx,[0x7180]
    cmp word [bx+0x6],byte +0x1
    jnz loc_7D92
    mov ax,0x3
    push ax
    lea ax,[bp-0x1c]
    push ax
    mov bx,[bp-0x3a]
    shl bx,1
    add bx,[bp+0x6]
    push word [bx]
    call 0xb116
    add sp,byte +0x6
    mov [bp-0x2],ax
loc_7D92:
    cmp word [bp-0x2],byte +0x0
    jng loc_7DB6
    dec word [bp-0x36]
    mov ax,[bp-0x3a]
    shl ax,1
    mov [bp-0x3c],ax
    add ax,[bp+0x8]
    push ax
    mov ax,[bp-0x3c]
    add ax,[bp+0x6]
    push ax
    call 0x87d6
    add sp,byte +0x4
    jmp short loc_7DB9
loc_7DB6:
    inc word [bp-0x3a]
loc_7DB9:
    mov ax,[bp-0x36]
    cmp [bp-0x3a],ax
    jl loc_7D4A
loc_7DC1:
    mov bx,[bp+0x6]
    cmp word [bx],byte +0x1
    jmp 0x7cb8
    push bp
    mov bp,sp
    sub sp,byte +0x4
    push di
    push si
    mov si,[bp+0x4]
    mov di,0x2a1e
    jmp short loc_7E05
loc_7DDA:
    mov al,[di+0x2]
    sub ah,ah
    mov [bp-0x4],ax
    cmp [bp+0x6],ax
    jc loc_7E02
    push word [di]
    mov ax,si
    sub ax,[bp-0x4]
    push ax
    call 0x969e
    add sp,byte +0x4
    or ax,ax
    jnz loc_7E02
    mov ax,di
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
    nop
loc_7E02:
    add di,byte +0x8
loc_7E05:
    cmp word [di],byte +0x0
    jnz loc_7DDA
    sub ax,ax
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
suffix_pattern_final_e_start_C3000_7E12:
; file 0x37E12
    push bp
    mov bp,sp
    push di
    push si
    mov si,[bp+0x4]
    mov di,[bp+0x6]
    cmp byte [di-0x1],0x65
    jz loc_7E36
    cmp byte [di-0x1],0x73
    jnz loc_7E74
    mov byte [di],0x73
    inc di
    mov byte [di],0x0
    sub ax,ax
    pop si
    pop di
    pop bp
    ret
loc_7E36:
    mov al,[di-0x2]
    sub ah,ah
    sub ax,0x63
    cmp ax,0x17
    jna loc_7E46
    jmp suffix_extended_final_letter_C3000_7F96
loc_7E46:
    add ax,ax
    xchg ax,bx
    jmp [cs:bx+0x7f66]
loc_7E4E:
    mov byte [di-0x1],0x65
    jmp suffix_extended_final_letter_C3000_7F96
    nop
    mov byte [di-0x2],0x79
    mov byte [di-0x1],0x0
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jz loc_7E6C
    jmp loc_7F39
loc_7E6C:
    mov byte [di-0x2],0x69
loc_7E70:
    mov byte [di-0x1],0x65
loc_7E74:
    push si
    call 0xb0e6
    add sp,byte +0x2
    pop si
    pop di
    pop bp
    ret
    nop
    cmp byte [di-0x3],0x74
    jz loc_7E74
    mov byte [di-0x1],0x0
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jz loc_7E98
    jmp loc_7F39
loc_7E98:
    jmp short loc_7E70
    mov al,[di-0x2]
    cmp [di-0x3],al
    jnz loc_7ECA
    mov byte [di-0x1],0x0
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jz loc_7EB4
    jmp loc_7F39
loc_7EB4:
    mov byte [di-0x2],0x0
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jnz loc_7F39
    mov byte [di-0x2],0x73
    jmp short loc_7E70
    nop
loc_7ECA:
    mov byte [di],0x0
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jnz loc_7F39
    mov byte [di-0x1],0x69
    mov byte [di],0x73
    mov byte [di+0x1],0x0
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jnz loc_7F39
    mov byte [di-0x1],0x0
    jmp loc_7E74
    nop
    mov al,[di-0x2]
    cmp [di-0x3],al
    jnz loc_7F27
    sub di,byte +0x2
    mov byte [di],0x0
    mov ax,0x2aeb
    push ax
    mov ax,0x2aec
    push ax
    push di
    push si
    call multiword_expansion_C3000_84A8
    add sp,byte +0x8
    pop si
    pop di
    pop bp
    ret
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jnz loc_7F39
    mov byte [di-0x2],0x66
loc_7F27:
    mov byte [di-0x1],0x0
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jnz loc_7F39
    jmp loc_7E4E
loc_7F39:
    mov ax,0x1
    pop si
    pop di
    pop bp
    ret
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jnz loc_7F39
    mov byte [di-0x2],0x78
    mov byte [di-0x1],0x0
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jnz loc_7F39
    mov byte [di-0x3],0x65
    jmp loc_7E74
    nop
