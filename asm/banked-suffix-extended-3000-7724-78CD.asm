; Generated from disasm: 3000:7724-78CD
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x7724


; helper call targets covered by later slices
suffix_compound_builder_C3000_7686equ 0x7686

suffix_extended_C3000_7724:
; file 0x37724
    push bp
    mov bp,sp
    sub sp,byte +0x60
    push di
    push si
    mov si,[bp+0x4]
    mov di,[bp+0x6]
    mov bx,[0x7134]
    cmp word [bx+0x6],byte +0xb
    jnz loc_7750
    mov ax,0x25bc
    push ax
    lea ax,[bp-0x18]
    push ax
    call 0x960a
    add sp,byte +0x4
    mov ax,0x25c0
    jmp short loc_7761
    nop
loc_7750:
    mov ax,0x25c6
    push ax
    lea ax,[bp-0x18]
    push ax
    call 0x960a
    add sp,byte +0x4
    mov ax,0x25c9
loc_7761:
    push ax
    lea ax,[bp-0x60]
    push ax
    call 0x960a
    add sp,byte +0x4
    mov al,[di-0x1]
    sub ah,ah
    cmp ax,0x65
    jnz loc_7779
    jmp loc_782A
loc_7779:
    cmp ax,0x6c
    jnz loc_7781
    jmp loc_785C
loc_7781:
    cmp ax,0x79
    jz loc_77BA
    mov [di],al
    inc di
    lea ax,[bp-0x18]
    push ax
    push di
    call 0x960a
    add sp,byte +0x4
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jz loc_77B4
    push word [bp+0x8]
    push di
    call 0x960a
    add sp,byte +0x4
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jnz loc_77E9
loc_77B4:
    dec di
    mov byte [di],0x0
    jmp short loc_77F6
loc_77BA:
    mov byte [di-0x1],0x69
    lea ax,[bp-0x18]
    push ax
    push di
    call 0x960a
    add sp,byte +0x4
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jz loc_77F2
    push word [bp+0x8]
    push di
    call 0x960a
    add sp,byte +0x4
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jz loc_77F2
loc_77E9:
    mov ax,0x1
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
loc_77F2:
    mov byte [di-0x1],0x79
loc_77F6:
    lea ax,[bp-0x18]
    push ax
    push di
    call 0x960a
    add sp,byte +0x4
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jnz loc_780F
    jmp loc_78AA
loc_780F:
    push word [bp+0x8]
    push di
    call 0x960a
    add sp,byte +0x4
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jnz loc_7827
    jmp loc_78AA
loc_7827:
    jmp short loc_77E9
    nop
loc_782A:
    dec di
    lea ax,[bp-0x18]
    push ax
    push di
    call 0x960a
    add sp,byte +0x4
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jz loc_7856
    push word [bp+0x8]
    push di
    call 0x960a
    add sp,byte +0x4
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jnz loc_77E9
loc_7856:
    mov byte [di],0x65
    inc di
    jmp short loc_77F6
loc_785C:
    lea ax,[bp-0x18]
    push ax
    push di
    call 0x960a
    add sp,byte +0x4
    push si
    call 0xb0e6
    add sp,byte +0x2
    or ax,ax
    jz loc_77F6
    push word [bp+0x8]
    lea ax,[bp-0x30]
    push ax
    call 0x960a
    add sp,byte +0x4
    mov byte [bp-0x48],0x6c
    push word [bp+0x8]
    lea ax,[bp-0x47]
    push ax
    call 0x960a
    add sp,byte +0x4
    lea ax,[bp-0x48]
    push ax
    lea ax,[bp-0x30]
    push ax
    push di
    push si
    call suffix_compound_builder_C3000_7686
    add sp,byte +0x8
    or ax,ax
    jz loc_78A7
    jmp loc_77E9
loc_78A7:
    jmp loc_77F6
loc_78AA:
    mov byte [di],0x0
    push si
    lea ax,[bp-0x60]
    push ax
    call 0x9626
    add sp,byte +0x2
    push ax
    call 0x960a
    add sp,byte +0x4
    lea ax,[bp-0x60]
    push ax
    push si
    call 0x960a
    add sp,byte +0x4
    jmp loc_77E9
    nop
