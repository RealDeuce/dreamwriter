; Generated from disasm: 3000:7972-79E7
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x7972


compressed_subheader_loader_C3000_7972:
; file 0x37972
    push bp
    mov bp,sp
    sub sp,byte +0x6
    push di
    push si
    mov ax,0x8
    push ax
    mov ax,0x9650
    push ax
    call 0x8854
    add sp,byte +0x4
    mov word [bp-0x2],0x10
    mov si,0x7166
    mov [0x9662],si
    mov di,[0x9652]
    add [bp-0x2],di
loc_799B:
    mov ax,0x8
    push ax
    call 0xadbe
    add sp,byte +0x2
    mov [si],al
    inc si
    dec di
    or di,di
    jg loc_799B
    push word [0x9658]
    mov ax,0x7136
    mov [0x9660],ax
    push ax
    call 0x8854
    add sp,byte +0x4
    mov ax,[0x9658]
    shl ax,1
    add [bp-0x2],ax
    mov word [0x9664],0x2b30
    mov ax,[0x965c]
    mov cl,0x3
    shl ax,cl
    push ax
    call 0xafb4
    add sp,byte +0x2
    mov ax,[bp-0x2]
    add ax,[0x965c]
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
    nop
