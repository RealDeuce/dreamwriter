; Generated from disasm: 3000:84A8-8853
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x84A8


multiword_expansion_C3000_84A8:
; file 0x384A8
    push bp
    mov bp,sp
    sub sp,byte +0x1a
    push si
    push word [bp+0x8]
    push word [bp+0x4]
    lea ax,[bp-0x1a]
    push ax
    call 0x960a
    add sp,byte +0x4
    push ax
    call 0x960a
    add sp,byte +0x4
    mov si,ax
    lea ax,[bp-0x1a]
    push ax
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jnz loc_84DE
    lea ax,[bp-0x1a]
    mov si,ax
    mov byte [si],0x0
loc_84DE:
    push word [bp+0xa]
    push word [bp+0x6]
    call 0x960a
    add sp,byte +0x4
    push word [bp+0x4]
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jz loc_850C
    lea ax,[bp-0x1a]
    cmp ax,si
    jz loc_8502
    mov byte [si],0xe
    inc si
loc_8502:
    push word [bp+0x4]
    push si
    call 0x960a
    add sp,byte +0x4
loc_850C:
    lea ax,[bp-0x1a]
    push ax
    push word [bp+0x4]
    call 0x960a
    add sp,byte +0x4
    mov bx,[bp+0x4]
    cmp byte [bx],0x1
    sbb ax,ax
    inc ax
    pop si
    mov sp,bp
    pop bp
    ret
    nop
    push bp
    mov bp,sp
    sub sp,0x88
    push di
    push si
    mov si,[bp+0x4]
    mov word [bp-0x50],0x0
    mov word [bp-0x82],0x0
    mov ax,0xff
    push ax
    lea ax,[bp-0x4c]
    push ax
    push si
    call 0xb116
    add sp,byte +0x6
    mov [bp-0x1a],ax
    inc ax
    jz loc_85B0
    cmp word [bp-0x1a],byte +0x0
    jnz loc_8562
loc_855A:
    sub ax,ax
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
loc_8562:
    push word [bp-0x1a]
    call 0x83e4
    add sp,byte +0x2
    mov [0x7180],ax
    or ax,ax
    jz loc_855A
    lea ax,[bp-0x4c]
    push ax
    push si
    call 0x960a
    add sp,byte +0x4
    mov bx,[bp-0x82]
    shl bx,1
    add bx,[bp+0x8]
    mov ax,[0x7180]
    mov [bx],ax
    mov bx,[bp-0x82]
    inc word [bp-0x82]
    shl bx,1
    add bx,[bp+0x6]
    mov [bx],si
    mov bx,[bp-0x82]
    shl bx,1
    add bx,[bp+0x6]
    mov word [bx],0x0
    mov ax,0x1
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
loc_85B0:
    push si
    lea ax,[bp-0x34]
    push ax
    call 0x960a
    add sp,byte +0x4
    mov ax,0x20
    push ax
    lea ax,[bp-0x34]
    push ax
    call 0x9666
    add sp,byte +0x4
    mov di,ax
    inc di
    mov ax,0x20
    push ax
    push si
    call 0x963a
    add sp,byte +0x4
    mov [bp-0x4e],ax
    push di
    lea ax,[bp-0x80]
    push ax
    call 0x960a
    add sp,byte +0x4
    push word [bp-0x4e]
    lea ax,[bp-0x18]
    push ax
    call 0x960a
    add sp,byte +0x4
    mov byte [di],0x0
    mov bx,[bp-0x4e]
    mov byte [bx],0x0
    push si
    lea ax,[bp-0x4c]
    push ax
    call 0x960a
    add sp,byte +0x4
    mov word [bp-0x82],0x0
    push word [bp+0x8]
    push word [bp+0x6]
    lea ax,[bp-0x4c]
    push ax
    call 0x7a1e
    add sp,byte +0x6
    or ax,ax
    jnz loc_8623
    jmp loc_870B
loc_8623:
    jmp loc_86D3
loc_8626:
    add ax,[bp+0x8]
    mov [bp-0x86],ax
    mov bx,ax
    mov bx,[bx]
    cmp word [bx+0x6],byte +0x7
    jnz loc_8647
    mov ax,0x16
    push ax
    call 0x83e4
    add sp,byte +0x2
    mov bx,[bp-0x86]
    mov [bx],ax
loc_8647:
    mov bx,[bp-0x82]
    shl bx,1
    add bx,[bp+0x8]
    mov bx,[bx]
    mov ax,[bx+0x6]
    cmp ax,0x1
    jz loc_8692
    cmp ax,0x3
    jz loc_8692
    cmp ax,0x5
    jz loc_8692
    cmp ax,0x15
    jz loc_8692
    cmp ax,0x17
    jz loc_8692
    mov ax,[bp-0x82]
    shl ax,1
    mov [bp-0x86],ax
    add ax,[bp+0x8]
    push ax
    mov ax,[bp-0x86]
    add ax,[bp+0x6]
    push ax
    call loc_87D6
    add sp,byte +0x4
    mov word [0x7180],0x0
    jmp short loc_86D3
loc_8692:
    mov bx,[bp-0x82]
    shl bx,1
    add bx,[bp+0x6]
    push word [bx]
    push si
    call 0x960a
    add sp,byte +0x4
    lea ax,[bp-0x18]
    push ax
    push si
    call loc_8808
    add sp,byte +0x4
    mov bx,[bp-0x82]
    inc word [bp-0x82]
    shl bx,1
    add bx,[bp+0x6]
    mov [bx],si
    mov bx,[bp-0x82]
    shl bx,1
    add bx,[bp+0x6]
    push word [bx-0x2]
    call 0x9626
    add sp,byte +0x2
    mov si,ax
    inc si
loc_86D3:
    mov ax,[bp-0x82]
    shl ax,1
    mov [bp-0x84],ax
    mov bx,ax
    add bx,[bp+0x6]
    cmp word [bx],byte +0x0
    jz loc_86EA
    jmp loc_8626
loc_86EA:
    cmp word [bp-0x82],byte +0x0
    jz loc_870B
    mov bx,[bp-0x82]
    shl bx,1
    add bx,[bp+0x6]
    push word [bx-0x2]
    call 0x9626
    add sp,byte +0x2
    mov si,ax
    inc si
    mov word [bp-0x50],0x1
loc_870B:
    mov ax,[bp-0x82]
    shl ax,1
    mov [bp-0x86],ax
    add ax,[bp+0x8]
    push ax
    mov ax,[bp-0x86]
    add ax,[bp+0x6]
    push ax
    lea ax,[bp-0x80]
    push ax
    call 0x7a1e
    add sp,byte +0x6
    or ax,ax
    jnz loc_8732
    jmp loc_87CC
loc_8732:
    jmp short loc_87AC
loc_8734:
    mov bx,[bp-0x88]
    cmp word [bx+0x6],byte +0x7
    jz loc_8752
    push word [bp-0x84]
    mov ax,[bp-0x86]
    add ax,[bp+0x6]
    push ax
    call loc_87D6
    add sp,byte +0x4
    jmp short loc_87AC
loc_8752:
    mov ax,[bp-0x82]
    shl ax,1
    add ax,[bp+0x8]
    mov [bp-0x88],ax
    mov bx,ax
    mov bx,[bx]
    test word [bx+0x4],0x400
    jz loc_876F
    mov bx,ax
    add word [bx],byte +0x8
loc_876F:
    lea ax,[bp-0x34]
    push ax
    push si
    call 0x960a
    add sp,byte +0x4
    mov di,ax
    mov bx,[bp-0x82]
    shl bx,1
    add bx,[bp+0x6]
    push word [bx]
    push di
    call 0x960a
    add sp,byte +0x4
    mov bx,[bp-0x82]
    inc word [bp-0x82]
    shl bx,1
    add bx,[bp+0x6]
    mov [bx],si
    push si
    call 0x9626
    add sp,byte +0x2
    inc ax
    mov si,ax
    mov word [bp-0x50],0x1
loc_87AC:
    mov ax,[bp-0x82]
    shl ax,1
    mov [bp-0x86],ax
    add ax,[bp+0x8]
    mov [bp-0x84],ax
    mov bx,ax
    mov ax,[bx]
    mov [bp-0x88],ax
    or ax,ax
    jz loc_87CC
    jmp loc_8734
loc_87CC:
    mov ax,[bp-0x50]
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
    nop
loc_87D6:
    push bp
    mov bp,sp
    sub sp,byte +0x2
    push di
    push si
    sub si,si
    jmp short loc_87F5
loc_87E2:
    cmp si,byte +0x4
    jnl loc_8801
    mov ax,[bx+di+0x2]
    mov [bx+di],ax
    mov bx,[bp+0x6]
    mov ax,[bx+di+0x2]
    mov [bx+di],ax
    inc si
loc_87F5:
    mov di,si
    shl di,1
    mov bx,[bp+0x4]
    cmp word [bx+di],byte +0x0
    jnz loc_87E2
loc_8801:
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
    nop
loc_8808:
    push bp
    mov bp,sp
    sub sp,byte +0x34
    push di
    push si
    mov di,[bp+0x4]
    lea ax,[bp-0x32]
    mov si,ax
    jmp short loc_8831
loc_881A:
    cmp byte [di],0xe
    jnz loc_882B
    push word [bp+0x6]
    push si
    call 0x960a
    add sp,byte +0x4
    mov si,ax
loc_882B:
    mov al,[di]
    inc di
    mov [si],al
    inc si
loc_8831:
    cmp byte [di],0x0
    jnz loc_881A
    push word [bp+0x6]
    push si
    call 0x960a
    add sp,byte +0x4
    lea ax,[bp-0x32]
    push ax
    push word [bp+0x4]
    call 0x960a
    add sp,byte +0x4
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
    nop
