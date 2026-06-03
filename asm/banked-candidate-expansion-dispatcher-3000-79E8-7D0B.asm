; Generated from disasm: 3000:79E8-7D0B
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x79E8


; helper call targets covered by later slices
suffix_pattern_tail_and_lookup_C3000_7D24equ 0x7D24
suffix_pattern_final_e_start_C3000_7E12equ 0x7E12

candidate_expansion_dispatch_C3000_79E8:
; file 0x379E8
    push bp
    mov bp,sp
    sub sp,byte +0x2
    push si
    mov si,[bp+0x4]
    mov ax,0x20
    push ax
    push si
    call 0x963a
    add sp,byte +0x4
    or ax,ax
    jz loc_7A06
    mov ax,0x8528
    jmp short loc_7A09
loc_7A06:
    mov ax,0x7a1e
loc_7A09:
    mov [bp-0x2],ax
    push word [bp+0x8]
    push word [bp+0x6]
    push si
    call [bp-0x2]
    add sp,byte +0x6
    pop si
    mov sp,bp
    pop bp
    ret
    push bp
    mov bp,sp
    sub sp,byte +0x3c
    push di
    push si
    mov si,[bp+0x4]
    push si
    lea ax,[bp-0x1c]
    push ax
    call 0x960a
    add sp,byte +0x4
    mov word [bp-0x3a],0x0
    mov di,si
    mov ax,0xff
    push ax
    lea ax,[bp-0x34]
    push ax
    push si
    call 0xb116
    add sp,byte +0x6
    mov [bp-0x2],ax
    inc ax
    jnz loc_7A53
    jmp loc_7B3E
loc_7A53:
    cmp word [bp-0x2],byte +0x0
    jnz loc_7A62
loc_7A59:
    sub ax,ax
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
    nop
loc_7A62:
    lea ax,[bp-0x34]
    push ax
    push si
    call 0x960a
    add sp,byte +0x4
    cmp word [bp-0x2],byte +0x4
    jnz loc_7A8E
    mov ax,0x6
    push ax
    lea ax,[bp-0x1c]
    push ax
    lea ax,[bp-0x1c]
    push ax
    call 0xb116
    add sp,byte +0x6
    or ax,ax
    jng loc_7A8E
    mov word [bp-0x2],0x2
loc_7A8E:
    push word [bp-0x2]
    call 0x83e4
    add sp,byte +0x2
    mov [0x7180],ax
    or ax,ax
    jz loc_7A59
    push si
    call 0x9626
    add sp,byte +0x2
    mov di,ax
    push word [bp-0x3a]
    push word [bp+0x6]
    push word [bp+0x8]
    push si
    call 0x8438
    add sp,byte +0x8
    mov [bp-0x3a],ax
    lea ax,[bp-0x1c]
    push ax
    call 0x9626
    add sp,byte +0x2
    dec ax
    mov [bp-0x4],ax
    cmp word [bp-0x2],byte +0x8
    jz loc_7AD4
    cmp word [bp-0x2],byte +0x1c
    jnz loc_7B28
loc_7AD4:
    mov bx,[bp-0x4]
    cmp byte [bx],0x73
    jnz loc_7B28
    mov byte [bx],0x0
    cmp word [bp-0x2],byte +0x8
    jnz loc_7AEC
    add word [0x7180],byte +0x10
    jmp short loc_7AF1
loc_7AEC:
    sub word [0x7180],byte +0x10
loc_7AF1:
    push word [bp-0x4]
    lea ax,[bp-0x1c]
    push ax
    call suffix_pattern_final_e_start_C3000_7E12
    add sp,byte +0x4
    or ax,ax
    jz loc_7B28
    inc di
    lea ax,[bp-0x1c]
    push ax
    push di
    call 0x960a
    add sp,byte +0x4
    mov bx,[bp-0x3a]
    shl bx,1
    add bx,[bp+0x6]
    mov [bx],di
    mov bx,[bp-0x3a]
    inc word [bp-0x3a]
    shl bx,1
    add bx,[bp+0x8]
    mov ax,[0x7180]
    mov [bx],ax
loc_7B28:
    mov bx,[bp-0x3a]
    shl bx,1
    add bx,[bp+0x8]
    mov word [bx],0x0
loc_7B34:
    mov ax,0x1
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
candidate_expansion_pattern_fallback_C3000_7B3E:
; file 0x37B3E
loc_7B3E:
    push si
    call 0x9626
    add sp,byte +0x2
    mov di,ax
    sub ax,si
    push ax
    push di
    call 0x7dca
    add sp,byte +0x4
    mov [0x7180],ax
    or ax,ax
    jnz loc_7B5B
    jmp loc_7A59
loc_7B5B:
    mov bx,ax
    mov al,[bx+0x2]
    sub ah,ah
    sub di,ax
    mov [di],ah
    mov bx,[0x7180]
    mov al,[bx+0x3]
    cmp ax,0xa
    jna loc_7B75
    jmp loc_7A59
loc_7B75:
    add ax,ax
    xchg ax,bx
    jmp [cs:bx+0x7d0e]
    nop
    push di
    push si
    call suffix_pattern_final_e_start_C3000_7E12
    add sp,byte +0x4
    or ax,ax
    jnz loc_7B8D
    jmp loc_7A59
loc_7B8D:
    mov ax,0x7
    push ax
    lea ax,[bp-0x34]
    push ax
    push si
    call 0xb116
    add sp,byte +0x6
    mov [bp-0x2],ax
    or ax,ax
    jg loc_7BA6
    jmp suffix_pattern_tail_and_lookup_C3000_7D24
loc_7BA6:
    mov ax,0x16
    push ax
    call 0x83e4
    add sp,byte +0x2
    mov [0x7180],ax
    jmp suffix_pattern_tail_and_lookup_C3000_7D24
    push di
    push si
    call 0x7fd4
loc_7BBB:
    add sp,byte +0x4
loc_7BBE:
    or ax,ax
    jz loc_7BC5
    jmp suffix_pattern_tail_and_lookup_C3000_7D24
loc_7BC5:
    jmp loc_7A59
    push di
    push si
    call 0x7f9c
    jmp short loc_7BBB
    nop
    push di
    push si
    call 0x8056
    jmp short loc_7BBB
    nop
    mov bx,[0x7180]
    push word [bx]
    call 0x9626
    add sp,byte +0x2
    mov bx,ax
    cmp byte [bx-0x1],0x73
    jz loc_7BF4
    push di
    push si
    call 0x8290
    jmp short loc_7BBB
    nop
loc_7BF4:
    push si
    lea ax,[bp-0x34]
    push ax
    call 0x960a
    add sp,byte +0x4
    lea ax,[bp-0x1c]
    push ax
    push si
    call 0x960a
    add sp,byte +0x4
    mov di,ax
    dec di
    mov byte [di],0x0
    lea ax,[bp-0x34]
    push ax
    lea ax,[bp-0x1c]
    push ax
    call 0x960a
    add sp,byte +0x4
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jz loc_7C5A
    mov ax,0x8
    push ax
    call 0x83e4
    add sp,byte +0x2
    sub ax,0x8
    mov bx,[bp-0x3a]
    shl bx,1
    add bx,[bp+0x8]
    mov [bx],ax
    mov bx,[bp-0x3a]
    inc word [bp-0x3a]
    shl bx,1
    add bx,[bp+0x6]
    mov [bx],si
    push di
    call 0x9626
    add sp,byte +0x2
    inc ax
    mov di,ax
    jmp short loc_7C5C
    nop
loc_7C5A:
    mov di,si
loc_7C5C:
    lea ax,[bp-0x1c]
    push ax
    call 0x9626
    add sp,byte +0x2
    mov [bp-0x4],ax
    push ax
    lea ax,[bp-0x1c]
    push ax
    call 0x8290
    add sp,byte +0x4
    or ax,ax
    jz loc_7CA6
    lea ax,[bp-0x1c]
    push ax
    push di
    call 0x960a
    add sp,byte +0x4
    mov bx,[bp-0x3a]
    shl bx,1
    add bx,[bp+0x6]
    mov [bx],di
    mov bx,[bp-0x3a]
    inc word [bp-0x3a]
    shl bx,1
    add bx,[bp+0x8]
    mov ax,[0x7180]
    mov [bx],ax
    push di
    call 0x9626
    add sp,byte +0x2
    mov di,ax
loc_7CA6:
    mov byte [di],0x0
    mov bx,[bp-0x3a]
    shl bx,1
    add bx,[bp+0x6]
    mov word [bx],0x0
    cmp byte [si],0x1
    sbb ax,ax
    inc ax
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
    nop
    push di
    push si
    call 0x82c6
    jmp loc_7BBB
    mov ax,0x2ade
loc_7CCD:
    push ax
    push di
    call 0x960a
    add sp,byte +0x4
loc_7CD5:
    push si
    call 0xb0e6
    add sp,byte +0x2
    jmp loc_7BBE
    nop
    mov ax,0x2ae2
    jmp short loc_7CCD
    nop
    mov ax,0x2ae5
    jmp short loc_7CCD
    nop
    cmp byte [di-0x1],0x75
    jz loc_7CF5
    jmp loc_7A59
loc_7CF5:
    jmp short loc_7CD5
    nop
    cmp byte [si],0x0
    jz loc_7D00
    jmp loc_7A59
loc_7D00:
    mov ax,0x2ae8
    push ax
    push si
    call 0x960a
    add sp,byte +0x4
    jmp loc_7B34
