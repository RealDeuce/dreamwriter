; Generated from disasm: 3000:8854-8A0D
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x8854


dictionary_stream_init_C3000_8854:
; file 0x38854
    push bp
    mov bp,sp
    sub sp,byte +0x6
    push di
    push si
    mov si,[bp+0x4]
    mov ax,[bp+0x6]
    mov [bp-0x4],ax
    jmp short loc_888D
    nop
loc_8868:
    mov ax,0x8
    push ax
    call 0xadbe
    add sp,byte +0x2
    mov di,ax
    mov ax,0x8
    push ax
    call 0xadbe
    add sp,byte +0x2
    mov [bp-0x2],ax
    mov ah,[bp-0x2]
    sub al,al
    or ax,di
    mov [si],ax
    add si,byte +0x2
loc_888D:
    mov ax,[bp-0x4]
    dec word [bp-0x4]
    or ax,ax
    jg loc_8868
    sub ax,ax
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
    nop
    push bp
    mov bp,sp
    sub sp,byte +0x14
    push si
    mov word [0x8a50],0x29bc
    mov si,0x7502
    mov word [si+0x24],0x864e
    mov word [si+0x12],0x7622
    mov word [si+0x16],0x752a
    mov word [si+0x10],0x7236
    call 0x65fe
    or ax,ax
    jng loc_88ED
    mov ax,0x100
    cwd
    push dx
    push ax
    call 0x66ae
    add sp,byte +0x4
    or ax,ax
    jnz loc_88ED
    mov ax,0x10
    push ax
    lea ax,[bp-0x14]
    push ax
    call 0x95b6
    add sp,byte +0x4
    or ax,ax
    jz loc_88F4
loc_88ED:
    sub ax,ax
    pop si
    mov sp,bp
    pop bp
    ret
loc_88F4:
    mov ax,0x8
    push ax
    push si
    lea ax,[bp-0x14]
    push ax
    call 0x95d4
    add sp,byte +0x6
    push word [si+0x8]
    push word [si+0x12]
    call 0x95b6
    add sp,byte +0x4
    or ax,ax
    jnz loc_88ED
    mov ax,[si+0xa]
    shl ax,1
    push ax
    push word [si+0x16]
    call 0x95b6
    add sp,byte +0x4
    or ax,ax
    jnz loc_88ED
    push word [si+0xe]
    push word [si+0x10]
    call 0x95b6
    add sp,byte +0x4
    or ax,ax
    jnz loc_88ED
    mov word [si+0x14],0x7182
    mov word [si+0x18],0x75e0
    push word [si+0x8]
    push word [si+0x14]
    push word [si+0x10]
    call loc_89B6
    add sp,byte +0x6
    mov [bp-0x2],ax
    push word [si+0xc]
    push word [si+0x18]
    push ax
    call loc_89B6
    add sp,byte +0x6
    mov ax,[si+0xa]
    shl ax,1
    add ax,[si+0x8]
    add ax,[si+0xe]
    add ax,0x10f
    and ax,0xfc00
    cwd
    xor ax,dx
    sub ax,dx
    mov cx,0xa
    sar ax,cl
    xor ax,dx
    sub ax,dx
    inc ax
    mov [si+0x22],ax
    mov bx,[0x8a50]
    mov ax,[bx+0x4]
    add ax,0x10
    mov [si+0x1a],ax
    add ax,[si+0x8]
    mov [si+0x1c],ax
    mov byte [si+0x20],0x1
    mov ax,[si+0x1a]
    sub [si+0x12],ax
    mov ax,[si+0x1a]
    shl ax,1
    sub [si+0x14],ax
    mov ax,[si+0x1c]
    shl ax,1
    sub [si+0x16],ax
    mov ax,si
    pop si
    mov sp,bp
    pop bp
    ret
loc_89B6:
    push bp
    mov bp,sp
    push di
    push si
    mov si,[bp+0x4]
    mov di,[bp+0x6]
    jmp short loc_89D1
    nop
loc_89C4:
    add di,byte +0x2
    mov [di-0x2],si
loc_89CA:
    inc si
    cmp byte [si-0x1],0x0
    jnz loc_89CA
loc_89D1:
    mov ax,[bp+0x8]
    dec word [bp+0x8]
    or ax,ax
    jg loc_89C4
    mov ax,si
    pop si
    pop di
    pop bp
    ret
    nop
    mov ax,[0x8a5a]
    add ax,[0x7524]
    cwd
    mov cl,0xa
loc_89EC:
    shl ax,1
    rcl dx,1
    dec cl
    jnz loc_89EC
    push dx
    push ax
    call 0x66ae
    add sp,byte +0x4
    mov ax,0x400
    push ax
    mov ax,0x864e
    push ax
    call 0x660f
    add sp,byte +0x4
    mov ax,0x1
    ret
