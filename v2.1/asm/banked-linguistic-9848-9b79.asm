; Generated from disasm: 3000:9848-3000:9B79
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x9848

; helper call targets covered by later slices
candidate_builder_C3000_9B7A       equ 0x9B7A
stream_wordcmp_C3000_9D1A         equ 0x9D1A
candidate_list_copy_C3000_9DC8     equ 0x9DC8

;-------------------------------------------------------------------------------
;  3000:9848..9B79
; candidate_search_C3000_9848
; A leading candidate search and expansion loop from the banked manager.
;  It accepts table pointer/count in [bp+04], [bp+0A], [bp+08] and appends
;  candidate rows into the caller-provided scratch area.
;  It may delegate to the helper chain below and returns candidates-in-use count in AX.
;-------------------------------------------------------------------------------
candidate_search_C3000_9848:
    push bp
    mov bp,sp
    sub sp,byte +0x3a
    push di
    push si
    mov si,[bp+0x4]
    mov di,[bp+0xa]
    push si
    call 0x5260
    add sp,byte +0x2
    cmp ax,0x18
    jl loc_986A
loc_9862:
    sub ax,ax
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
loc_986A:
    mov ax,[bp+0x8]
    mov [bp-0x2],ax
    mov ax,0x18
    push ax
    lea ax,[bp-0x32]
    push ax
    push si
    call 0x92f8
    add sp,byte +0x6
    mov [0x799e],ax
    inc ax
    jz loc_9862
    dec word [bp+0x6]
    mov ax,0x7767
    push ax
    lea ax,[bp-0x32]
    push ax
    call 0x969e
    add sp,byte +0x4
    or ax,ax
    jz loc_98B8
    lea ax,[bp-0x32]
    push ax
    mov ax,0x7767
    push ax
    call 0x960a
    add sp,byte +0x4
    mov word [0x7762],0x1
    mov al,[0x799e]
    and al,0x10
    mov [0x7765],al
    jmp short loc_990B
loc_98B8:
    mov al,[0x7764]
    sub ah,ah
    cmp [bp+0x6],ax
    jna loc_98CC
    mov ax,0xffff
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
    nop
loc_98CC:
    cmp word [0x7762],byte +0x1
    jz loc_990B
    mov bx,[0x9250]
    mov ax,[bx+0x1e]
    mov [bp-0x36],ax
    jmp short loc_9901
    nop
loc_98E0:
    cmp word [bp+0x8],byte +0x0
    jz loc_990B
    mov ax,0x2
    push ax
    add di,ax
    push word [di-0x2]
    push word [bp+0x6]
    inc word [bp+0x6]
    push word [bp-0x36]
    call 0xa1aa
    add sp,byte +0x8
    dec word [bp+0x8]
loc_9901:
    mov al,[0x7764]
    sub ah,ah
    cmp [bp+0x6],ax
    jc loc_98E0
loc_990B:
    mov ax,[0x7762]
    cmp ax,0x1
    jz loc_9928
    cmp ax,0x2
    jz loc_9959
    cmp ax,0x4
    jz loc_993A
    cmp ax,0x7
    jnz loc_9925
    jmp loc_9B63
loc_9925:
    jmp loc_9862
loc_9928:
    lea ax,[bp-0x34]
    push ax
    push si
    call candidate_builder_C3000_9B7A
    add sp,byte +0x4
    or ax,ax
    jnz loc_993A
    jmp loc_9862
loc_993A:
    push di
    lea ax,[bp+0x8]
    push ax
    sub ax,ax
    push ax
    call candidate_list_copy_C3000_9DC8
    add sp,byte +0x6
    shl ax,1
    add di,ax
    cmp word [0x7762],byte +0x2
    jz loc_9959
    cmp word [bp+0x8],byte +0x0
    jnz loc_9966
loc_9959:
    mov ax,[bp-0x2]
    sub ax,[bp+0x8]
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
    nop
loc_9966:
    mov al,[0x7764]
    sub ah,ah
    mov [0x77d0],ax
    mov word [0x7762],0x7
    mov ax,0x7767
    push ax
    mov ax,0x7797
    push ax
    call 0x960a
    add sp,byte +0x4
    mov ax,0x77f8
    push ax
    mov ax,0x77c7
    push ax
    mov ax,0x7797
    push ax
    call 0x79e8
    add sp,byte +0x6
    or ax,ax
    jnz loc_99A0
loc_9998:
    mov word [0x7762],0x2
    jmp short loc_9959
loc_99A0:
    cmp byte [0x7765],0x0
    jz loc_99D7
    cmp byte [0x7766],0x0
    jz loc_99D7
    mov ax,0x18
    push ax
    lea ax,[bp-0x32]
    push ax
    mov ax,0x7797
    push ax
    call 0x92f8
    add sp,byte +0x6
    inc ax
    jz loc_99D7
    lea ax,[bp-0x32]
    push ax
    mov ax,0x7797
    push ax
    call 0x960a
    add sp,byte +0x4
    mov word [0x77c9],0x0
loc_99D7:
    mov word [0x8146],0x0
    mov ax,[0x77f8]
    jmp loc_9A67
    nop
loc_99E4:
    mov bx,[0x799c]
    mov ax,[bx+0x4]
    mov bx,[bp-0x3a]
    mov [bx+0x77d8],ax
    push word [0x9250]
    push word [0x7b9e]
    call 0xab4c
    add sp,byte +0x4
    mov bx,[0x8146]
    shl bx,1
    shl bx,1
    mov [bx+0x77e8],ax
    mov [bx+0x77ea],dx
    or dx,dx
    jl loc_9A3F
    push word [bp-0x34]
    push word [0x8146]
    call 0xa858
    add sp,byte +0x4
    or ax,ax
    jnz loc_9A3F
    mov bx,[0x8146]
    shl bx,1
    shl bx,1
    push word [bx+0x77ea]
    push word [bx+0x77e8]
    call stream_wordcmp_C3000_9D1A
    add sp,byte +0x4
    or ax,ax
    jnz loc_9A4C
loc_9A3F:
    push word [0x8146]
    call 0xaaee
    add sp,byte +0x2
    jmp short loc_9A5D
    nop
loc_9A4C:
    inc word [0x8146]
    mov bx,[0x8146]
    shl bx,1
    mov ax,[0x7760]
    mov [bx+0x77e0],ax
loc_9A5D:
    mov bx,[0x8146]
    shl bx,1
    mov ax,[bx+0x77f8]
loc_9A67:
    mov [0x799c],ax
    mov ax,[0x8146]
    shl ax,1
    mov [bp-0x3a],ax
    mov bx,ax
    mov ax,[bx+0x77c7]
    mov [0x7b9e],ax
    or ax,ax
    jz loc_9A82
    jmp loc_99E4
loc_9A82:
    cmp byte [0x7766],0x0
    jz loc_9AC0
    cmp byte [0x7765],0x0
    jz loc_9AC0
    mov word [bp-0x38],0x7797
loc_9A95:
    mov bx,[bp-0x38]
    cmp byte [bx],0x0
    jz loc_9AC0
    inc word [bp-0x38]
    cmp byte [bx],0x8
    jnz loc_9A95
    push word [bp-0x38]
    lea ax,[bp-0x32]
    push ax
    call 0x960a
    add sp,byte +0x4
    lea ax,[bp-0x32]
    push ax
    mov ax,0x7797
    push ax
    call 0x960a
    add sp,byte +0x4
loc_9AC0:
    mov word [0x8146],0x0
    mov ax,[0x77c7]
    mov [0x7b9e],ax
    jmp loc_9B63
    nop
loc_9AD0:
    mov al,[0x7764]
    sub ah,ah
    cmp [0x77d0],ax
    jnc loc_9AF2
    mov bx,[0x799c]
    cmp word [bx+0x6],byte +0xf
    jz loc_9AEB
    cmp word [bx+0x6],byte +0x11
    jnz loc_9AF2
loc_9AEB:
    cmp word [0x8146],byte +0x0
    jg loc_9B43
loc_9AF2:
    and word [0x7750],0xe000
    mov bx,[0x8146]
    shl bx,1
    mov ax,[bx+0x77d8]
    cwd
    or [0x7750],ax
    or [0x7752],dx
    push di
    lea ax,[bp+0x8]
    push ax
    mov ax,[0x8146]
    inc ax
    push ax
    call candidate_list_copy_C3000_9DC8
    add sp,byte +0x6
    shl ax,1
    add di,ax
    cmp word [0x7762],byte +0x2
    jnz loc_9B29
    jmp loc_9959
loc_9B29:
    cmp word [bp+0x8],byte +0x0
    jnz loc_9B32
    jmp loc_9959
loc_9B32:
    mov bx,[0x8146]
    shl bx,1
    mov al,[0x7764]
    sub ah,ah
    cmp [bx+0x77d0],ax
    jnz loc_9B50
loc_9B43:
    push word [0x8146]
    call 0xaaee
    add sp,byte +0x2
    jmp short loc_9B63
    nop
loc_9B50:
    inc word [0x8146]
    mov bx,[0x8146]
    shl bx,1
    mov al,[0x7764]
    sub ah,ah
    mov [bx+0x77d0],ax
loc_9B63:
    mov bx,[0x8146]
    shl bx,1
    mov ax,[bx+0x77f8]
    mov [0x799c],ax
    or ax,ax
    jz loc_9B77
    jmp loc_9AD0
loc_9B77:
    jmp loc_9998
