; Generated from disasm: 3000:8264-84A7
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x8264


inflection_helper_tail_C3000_8264:
; file 0x38264
    mov al,[di-0x2]
    cmp [di-0x1],al
    jnz loc_8280
    mov al,[di-0x1]
    mov [bp-0x18],al
    sub al,al
    mov [bp-0x17],al
    mov [bp-0x30],al
    dec di
    mov [di],al
    jmp 0x8179
loc_8280:
    mov byte [bp-0x18],0x65
    sub al,al
    mov [bp-0x30],al
    mov [bp-0x17],al
    jmp 0x8179
    nop
    push bp
    mov bp,sp
    push di
    push si
    mov si,[bp+0x4]
    mov di,[bp+0x6]
    cmp byte [di-0x1],0x61
    jz loc_82C0
    cmp byte [di-0x1],0x67
    jnz loc_82B4
    cmp byte [di-0x2],0x64
    jnz loc_82B4
    mov byte [di],0x65
    inc di
    mov byte [di],0x0
loc_82B4:
    push si
    call 0xb0e6
    add sp,byte +0x2
    pop si
    pop di
    pop bp
    ret
    nop
loc_82C0:
    sub ax,ax
    pop si
    pop di
    pop bp
    ret
    push bp
    mov bp,sp
    push di
    push si
    mov si,[bp+0x4]
    mov di,[bp+0x6]
    mov al,[di-0x2]
    cmp [di-0x1],al
    jnz loc_8330
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jz loc_82EC
loc_82E4:
    mov ax,0x1
    pop si
    pop di
    pop bp
    ret
    nop
loc_82EC:
    mov al,[di-0x1]
    sub ah,ah
    push ax
    mov ax,0x2b03
    push ax
    call 0x963a
    add sp,byte +0x4
    or ax,ax
    jz loc_8310
    mov byte [di-0x1],0x0
loc_8304:
    push si
    call 0xb0e6
    add sp,byte +0x2
    pop si
    pop di
    pop bp
    ret
    nop
loc_8310:
    cmp byte [di-0x2],0x73
    jnz loc_8329
    mov byte [di-0x2],0x74
    mov byte [di-0x1],0x0
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jnz loc_82E4
loc_8329:
    sub ax,ax
    pop si
    pop di
    pop bp
    ret
    nop
loc_8330:
    cmp byte [di-0x1],0x69
    jnz loc_8356
    mov ax,0x2b0e
    push ax
    push di
    call 0x960a
    add sp,byte +0x4
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jnz loc_82E4
    mov byte [di-0x1],0x79
    mov byte [di],0x0
    jmp short loc_8304
    nop
loc_8356:
    cmp byte [di-0x1],0x73
    jnz loc_8386
    cmp byte [di-0x2],0x6e
    jnz loc_837B
    mov byte [di-0x1],0x64
    mov byte [di],0x0
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jz loc_8377
    jmp loc_82E4
loc_8377:
    mov byte [di-0x1],0x73
loc_837B:
    mov byte [di],0x65
    mov byte [di+0x1],0x0
    jmp loc_8304
    nop
loc_8386:
    mov al,[di-0x1]
    sub ah,ah
    push ax
    mov ax,0x2b12
    push ax
    call 0x963a
    add sp,byte +0x4
    or ax,ax
    jz loc_83C4
    mov ax,0x2b19
    push ax
    push di
    call 0x960a
    add sp,byte +0x4
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jz loc_83B3
    jmp loc_82E4
loc_83B3:
    mov byte [di],0x0
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jz loc_83C4
    jmp loc_82E4
loc_83C4:
    mov ax,di
    sub ax,si
    cmp ax,0x3
    jnl loc_83D0
    jmp loc_8304
loc_83D0:
    mov ax,0x2b1d
    push ax
    mov ax,0x2b1e
    push ax
    push di
    push si
    call 0x84a8
    add sp,byte +0x8
    pop si
    pop di
    pop bp
    ret
    push bp
    mov bp,sp
    sub sp,byte +0x4
    push di
    push si
    mov si,[bp+0x4]
    dec si
    sub di,di
    jmp short loc_8405
loc_83F4:
    mov ax,di
    mov cl,0x3
    shl ax,cl
    add ax,0x2a1e
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
    nop
loc_8404:
    inc di
loc_8405:
    mov ax,di
    mov cl,0x3
    shl ax,cl
    mov [bp-0x4],ax
    mov bx,ax
    cmp word [bx+0x2a1e],byte +0x0
    jz loc_8430
    cmp [bx+0x2a24],si
    jnz loc_8404
    cmp si,byte +0x7
    jnz loc_83F4
    mov ax,di
    shl ax,cl
    add ax,0x2a26
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
    nop
loc_8430:
    sub ax,ax
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
    push bp
    mov bp,sp
    sub sp,byte +0x4
    push di
    push si
    mov si,[bp+0xa]
    mov di,[bp+0x4]
    cmp byte [di],0x0
    jnz loc_8454
    sub ax,ax
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
    nop
loc_8454:
    mov bx,[bp+0x6]
    mov ax,si
    shl ax,1
    add bx,ax
    mov ax,[0x7180]
    jmp short loc_848C
loc_8462:
    inc di
    cmp byte [di-0x1],0xe
    jnz loc_849A
    mov byte [di-0x1],0x0
    push di
    push word [bp+0x4]
    call 0x969e
    add sp,byte +0x4
    or ax,ax
    jz loc_849A
    mov ax,[bp+0x6]
    mov cx,si
    shl cx,1
    add ax,cx
    mov [bp-0x4],ax
    mov bx,ax
    mov ax,[bx-0x2]
loc_848C:
    mov [bx],ax
    mov bx,[bp+0x8]
    mov ax,si
    inc si
    shl ax,1
    add bx,ax
    mov [bx],di
loc_849A:
    cmp byte [di],0x0
    jnz loc_8462
    mov ax,si
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
    nop
