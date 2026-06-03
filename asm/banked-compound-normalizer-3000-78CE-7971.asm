; Generated from disasm: 3000:78CE-7971
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x78CE


compound_candidate_normalizer_C3000_78CE:
; file 0x378CE
    push bp
    mov bp,sp
    sub sp,byte +0x68
    push di
    push si
    mov di,[bp+0x4]
    lea ax,[bp-0x36]
    mov [bp-0x6],ax
    mov si,ax
    mov word [bp-0x68],0x0
    jmp short loc_7928
loc_78E8:
    cmp byte [di],0xe
    jz loc_78F2
    cmp byte [di],0x2f
    jnz loc_791D
loc_78F2:
    mov word [bp-0x68],0x1
    push word [bp+0x6]
    push word [bp-0x6]
    call 0x960a
    add sp,byte +0x4
    mov [bp-0x6],ax
    mov ax,0xff
    push ax
    lea ax,[bp-0x66]
    push ax
    push si
    call 0xb116
    add sp,byte +0x6
    or ax,ax
    jz loc_796A
    mov si,[bp-0x6]
    inc si
loc_791D:
    mov bx,[bp-0x6]
    inc word [bp-0x6]
    mov al,[di]
    inc di
    mov [bx],al
loc_7928:
    cmp byte [di],0x0
    jnz loc_78E8
    push word [bp+0x6]
    push word [bp-0x6]
    call 0x960a
    add sp,byte +0x4
    lea ax,[bp-0x36]
    push ax
    push word [bp+0x4]
    call 0x960a
    add sp,byte +0x4
    cmp word [bp-0x68],byte +0x0
    jnz loc_7961
    mov ax,0xff
    push ax
    lea ax,[bp-0x66]
    push ax
    push word [bp+0x4]
    call 0xb116
    add sp,byte +0x6
    or ax,ax
    jz loc_796A
loc_7961:
    mov ax,0x1
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
loc_796A:
    sub ax,ax
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
