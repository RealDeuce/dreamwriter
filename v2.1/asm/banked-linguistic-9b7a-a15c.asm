; Generated from disasm: 3000:9B7A-3000:A15C
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x9B7A

; helper call targets covered by previous slices
candidate_search_C3000_9848           equ 0x9848

;-------------------------------------------------------------------------------
;  3000:9B7A..9D19
; candidate_builder_C3000_9B7A
; Builds candidate expansion context and candidate slots from dictionary state.
;  Populates temporary slot tables and performs candidate-word normalization
;  before dispatching to record/weighting helpers.
;-------------------------------------------------------------------------------
candidate_builder_C3000_9B7A:
    push bp
    mov bp,sp
    sub sp,byte +0x38
    push di
    push si
    mov bx,[bp+0x6]
    mov word [bx],0x1
    mov word [0x7750],0xffff
    mov word [0x7752],0x13
    mov word [0x799c],0x0
    mov di,0x4
    jmp short loc_9BE5
loc_9BA0:
    mov ax,di
    shl ax,1
    mov [bp-0x38],ax
    mov bx,ax
    mov word [bx+0x77d8],0xd
    mov bx,[bp-0x38]
    mov word [bx+0x77d0],0x28
    mov bx,[bp-0x38]
    mov word [bx+0x77e0],0x28
    mov bx,di
    shl bx,1
    shl bx,1
    mov word [bx+0x77e8],0xffff
    mov word [bx+0x77ea],0xffff
    mov bx,[bp-0x38]
    mov word [bx+0x77f8],0x0
    mov bx,[bp-0x38]
    mov word [bx+0x77c7],0x0
loc_9BE5:
    dec di
    jns loc_9BA0
    mov word [0x7b9e],0x0
    mov byte [0x7764],0x0
    mov byte [0x7797],0x0
    mov word [0x775e],0x0
    mov word [0x7760],0x0
    mov byte [0x7766],0x0
    mov di,[0x775c]
    jmp short loc_9C1C
    nop
loc_9C10:
    mov bx,di
    shl bx,1
    add bx,[0x7946]
    mov word [bx],0x0
loc_9C1C:
    dec di
    jns loc_9C10
    push word [0x9250]
    mov ax,0x7767
    push ax
    call 0xab4c
    add sp,byte +0x4
    mov [0x7754],ax
    mov [0x7756],dx
    or dx,dx
    jnl loc_9CB4
    cmp byte [0x7765],0x0
    jz loc_9C57
    push word [bp+0x4]
    mov ax,0x7767
    push ax
    call 0x960a
    add sp,byte +0x4
    mov si,ax
    dec si
    cmp byte [si],0x2e
    jnz loc_9C57
    mov byte [si],0x0
loc_9C57:
    mov word [bp-0x34],0x7767
loc_9C5C:
    mov si,[bp-0x34]
    jmp short loc_9C68
    nop
loc_9C62:
    cmp byte [si],0x20
    jz loc_9C6D
    inc si
loc_9C68:
    cmp byte [si],0x0
    jnz loc_9C62
loc_9C6D:
    cmp byte [si],0x20
    jnz loc_9CCE
    mov byte [0x7766],0x1
    mov byte [si],0x0
    mov ax,0x18
    push ax
    lea ax,[bp-0x32]
    push ax
    push word [bp-0x34]
    call 0x92f8
    add sp,byte +0x6
    push word [0x9250]
    lea ax,[bp-0x32]
    push ax
    call 0xab4c
    add sp,byte +0x4
    or dx,dx
    jnl loc_9CA6
loc_9C9D:
    sub ax,ax
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
    nop
loc_9CA6:
    mov byte [si],0x20
    lea ax,[si+0x1]
    mov [bp-0x34],ax
loc_9CAF:
    cmp byte [si],0x0
    jnz loc_9C5C
loc_9CB4:
    cmp word [0x7756],byte +0x0
    jnl loc_9CC2
    cmp byte [0x7766],0x0
    jz loc_9C9D
loc_9CC2:
    cmp byte [0x7766],0x0
    jz loc_9CFA
    sub ax,ax
    jmp short loc_9D08
    nop
loc_9CCE:
    mov ax,0x18
    push ax
    lea ax,[bp-0x32]
    push ax
    push word [bp-0x34]
    call 0x92f8
    add sp,byte +0x6
    cmp byte [0x7766],0x0
    jz loc_9C9D
    push word [0x9250]
    lea ax,[bp-0x32]
    push ax
    call 0xab4c
    add sp,byte +0x4
    or dx,dx
    jnl loc_9CAF
    jmp short loc_9C9D
loc_9CFA:
    push word [0x7756]
    push word [0x7754]
    call stream_wordcmp_C3000_9D1A
    add sp,byte +0x4
loc_9D08:
    mov [0x77e0],ax
    mov word [0x7762],0x4
    mov ax,0x1
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
;-------------------------------------------------------------------------------
;  3000:9D1A..9DC7
; stream_wordcmp_C3000_9D1A
; Compares two stream values and returns equality.
;-------------------------------------------------------------------------------
stream_wordcmp_C3000_9D1A:
    push bp
    mov bp,sp
    sub sp,byte +0xc
    mov bx,[0x9250]
    mov ax,[bx+0x1e]
    mov [bp-0xc],ax
    mov ax,[bp+0x4]
    mov dx,[bp+0x6]
    sub al,al
    and dx,byte +0x1
    mov cl,0x8
loc_9D37:
    sar dx,1
    rcr ax,1
    dec cl
    jnz loc_9D37
    mov [bp-0x6],ax
    push word [0x7720]
    push word [0x773e]
    push word [0x773c]
    push word [0x774a]
    push word [0x7748]
    push ax
    call 0xa15e
    add sp,byte +0xc
    mov [bp-0xa],ax
    mov [bp-0x8],dx
    push word [0x7720]
    push word [0x773e]
    push word [0x773c]
    push word [0x774a]
    push word [0x7748]
    mov ax,[bp-0x6]
    inc ax
    push ax
    call 0xa15e
    add sp,byte +0xc
    mov [bp-0x4],ax
    mov [bp-0x2],dx
    mov ax,[bp-0xa]
    mov dx,[bp-0x8]
    cmp [bp-0x4],ax
    jnz loc_9D9E
    cmp [bp-0x2],dx
    jnz loc_9D9E
    sub ax,ax
    mov sp,bp
    pop bp
    ret
loc_9D9E:
    mov ax,0x1
    push ax
    push word [bp-0x8]
    push word [bp-0xa]
    call 0xb076
    add sp,byte +0x6
    mov ax,[bp-0x4]
    sub ax,[bp-0xa]
    push ax
    mov al,[bp+0x4]
    sub ah,ah
    push ax
    push word [bp-0xc]
    call related_word_build_C3000_9F7E
    add sp,byte +0x6
    mov sp,bp
    pop bp
    ret
;-------------------------------------------------------------------------------
;  3000:9DC8..9E45
; candidate_list_copy_C3000_9DC8
; Copies/compacts one candidate tuple into the result vector.
;  Produces index and text-pointer side effects used by the caller.
;  Returns updated counts/flags in registers.
;-------------------------------------------------------------------------------
candidate_list_copy_C3000_9DC8:
    push bp
    mov bp,sp
    sub sp,byte +0x2
    push si
    sub si,si
loc_9DD1:
    mov bx,[bp+0x4]
    shl bx,1
    mov ax,[0x775e]
    cmp [bx+0x77e0],ax
    jng loc_9E3E
    mov bx,[bp+0x6]
    cmp word [bx],byte +0x0
    jz loc_9E3E
    mov bx,[bp+0x8]
    push word [bx]
    mov al,[0x7764]
    sub ah,ah
    push ax
    mov bx,[0x775e]
    inc word [0x775e]
    shl bx,1
    push word [bx+0x7800]
    call offset_accumulate_C3000_9E46
    add sp,byte +0x6
    or ax,ax
    jz loc_9E31
    mov bl,[0x7764]
    inc word [0x7764]
    sub bh,bh
    shl bx,1
    shl bx,1
    mov ax,[0x7758]
    mov dx,[0x775a]
    mov [bx+0x78a0],ax
    mov [bx+0x78a2],dx
    mov bx,[bp+0x6]
    dec word [bx]
    inc si
    add word [bp+0x8],byte +0x2
loc_9E31:
    cmp byte [0x7764],0x28
    jc loc_9DD1
    mov word [0x7762],0x2
loc_9E3E:
    mov ax,si
    pop si
    mov sp,bp
    pop bp
    ret
    nop
;-------------------------------------------------------------------------------
;  3000:9E46..9F13
; offset_accumulate_C3000_9E46
; Accumulates per-record offsets into candidate slot arrays.
;  Used to build relation between compressed payload offsets and candidate buffer entries.
;-------------------------------------------------------------------------------
offset_accumulate_C3000_9E46:
    push bp
    mov bp,sp
    sub sp,byte +0x10
    push si
    mov si,[bp+0x4]
    mov bx,[0x9250]
    mov ax,[bx+0x1e]
    mov [bp-0xe],ax
    mov ax,si
    and ax,0x1ff0
    mov cl,0x4
    sar ax,cl
    mov [bp-0x2],ax
    mov ax,si
    and ax,0xf
    mov [bp-0x10],ax
    push word [0x7724]
    push word [0x7742]
    push word [0x7740]
    push word [0x774e]
    push word [0x774c]
    push word [bp-0x2]
    call 0xa15e
    add sp,byte +0xc
    mov [bp-0x6],ax
    mov [bp-0x4],dx
    mov ax,0x1
    push ax
    push dx
    push word [bp-0x6]
    call 0xb076
    add sp,byte +0x6
    mov ax,[bp-0x6]
    mov dx,[bp-0x4]
    mov cl,0x3
loc_9EA7:
    shl ax,1
    rcl dx,1
    dec cl
    jnz loc_9EA7
    mov [bp-0xc],ax
    mov [bp-0xa],dx
    jmp short loc_9EEA
    nop
loc_9EB8:
    push word [0x7736]
    call 0xadbe
    add sp,byte +0x2
    and ax,0xf0
    mov [bp-0x8],ax
    mov cl,0x4
    sar word [bp-0x8],cl
    mov ax,[0x7736]
    cwd
    add [bp-0xc],ax
    adc [bp-0xa],dx
    push word [bp-0xe]
    push word [bp-0x8]
    call candidate_weight_C3000_9F14
    add sp,byte +0x4
    cwd
    add [bp-0xc],ax
    adc [bp-0xa],dx
loc_9EEA:
    dec word [bp-0x10]
    jns loc_9EB8
    mov ax,[bp-0xc]
    mov dx,[bp-0xa]
    mov [0x7758],ax
    mov [0x775a],dx
    mov ax,0x1
    push ax
    push word [bp+0x8]
    push word [bp+0x6]
    push word [bp-0xe]
    call 0xa1aa
    add sp,byte +0x8
    pop si
    mov sp,bp
    pop bp
    ret
;-------------------------------------------------------------------------------
;  3000:9F14..9F7D
; candidate_weight_C3000_9F14
; Scales intermediate candidate metrics and advances packed cursor.
;  Returns the current expanded byte offset through stack return path.
;-------------------------------------------------------------------------------
candidate_weight_C3000_9F14:
    push bp
    mov bp,sp
    sub sp,byte +0x8
    push di
    push si
    mov word [bp-0x2],0x0
    sub si,si
    mov [bp-0x8],si
loc_9F26:
    mov ax,0x4
    push ax
    call 0xadbe
    add sp,byte +0x2
    mov di,ax
    add si,byte +0x4
    add [bp-0x2],di
    cmp di,byte +0xf
    jz loc_9F26
    push word [bp+0x4]
    push word [bp-0x8]
    call 0xa7a0
    add sp,byte +0x4
    mov [bp-0x8],ax
    cmp ax,0x1
    jl loc_9F26
    mov ax,[0x7734]
    imul word [bp-0x2]
    mov [bp-0x2],ax
    call 0xaeb6
    mov cl,0x3
    shl ax,cl
    add [bp-0x2],ax
    mov ax,[bp-0x2]
    add ax,0x8
    add si,ax
    push word [bp-0x2]
    call 0xafb4
    add sp,byte +0x2
    mov ax,si
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
    nop
;-------------------------------------------------------------------------------
;  3000:9F7E..A04F
; related_word_build_C3000_9F7E
; Builds the related-word payload buffer and final validation tests.
;  Returns either zero/false or index for caller continuation.
;  Shared with word-form and candidate list boundary work.
;-------------------------------------------------------------------------------
related_word_build_C3000_9F7E:
    push bp
    mov bp,sp
    sub sp,byte +0xa
    push di
    push si
    mov si,[bp+0x6]
    mov di,[bp+0x8]
    mov word [bp-0x4],0x20
    mov word [bp-0x6],0x0
    mov ax,[0x7760]
    mov [bp-0xa],ax
    mov ax,0x8
    imul di
    mov di,ax
loc_9FA3:
    call 0xaeb6
    mov [bp-0x2],al
    dec word [bp-0x4]
    sub si,byte +0x8
    jns loc_9FC6
    add si,byte +0x8
loc_9FB4:
    dec si
    js loc_9FDA
    test byte [bp-0x2],0x80
    jz loc_9FC0
    inc word [bp-0x6]
loc_9FC0:
    shl byte [bp-0x2],1
    jmp short loc_9FB4
    nop
loc_9FC6:
    test byte [bp-0x2],0x80
    jz loc_9FCF
    inc word [bp-0x6]
loc_9FCF:
    shl byte [bp-0x2],1
    cmp byte [bp-0x2],0x0
    jnz loc_9FC6
    jmp short loc_9FA3
loc_9FDA:
    test byte [bp-0x2],0x80
    jnz loc_9FE8
loc_9FE0:
    sub ax,ax
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
loc_9FE8:
    mov ax,[bp-0x4]
    mov cl,0x3
    shl ax,cl
    push ax
    call 0xafb4
    add sp,byte +0x2
    jmp short loc_A00F
loc_9FF8:
    sub di,byte +0xe
    js loc_9FE0
    mov ax,0xe
    push ax
    call 0xadbe
    add sp,byte +0x2
    and ax,0x2000
    cmp ax,0x2000
    jnz loc_9FF8
loc_A00F:
    dec word [bp-0x6]
    jns loc_9FF8
loc_A014:
    mov ax,0xe
    push ax
    call 0xadbe
    add sp,byte +0x2
    mov [bp-0x8],ax
    mov bx,[bp-0xa]
    inc word [bp-0xa]
    shl bx,1
    mov [bx+0x7800],ax
    mov ax,[bp-0x8]
    and ax,0x2000
    cmp ax,0x2000
    jnz loc_A014
    mov bx,[bp-0xa]
    shl bx,1
    mov word [bx+0x7800],0xffff
    mov ax,[bp-0xa]
    mov [0x7760],ax
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
    nop
;-------------------------------------------------------------------------------
;  3000:A050..A15C
; related_word_finalize_C3000_A050
; Finalizes and copies a generated related-word/text sequence into output rows.
;  Performs word-length checks and tail truncation.
;  Returns output cursor in AX to the caller.
;-------------------------------------------------------------------------------
related_word_finalize_C3000_A050:
    push bp
    mov bp,sp
    sub sp,byte +0x16
    push di
    push si
    mov si,[bp+0x6]
    mov [bp-0xe],si
    sub ax,ax
    mov [bp-0x8],ax
    mov [bp-0xa],ax
    mov [bp-0x14],ax
    mov ax,[0x7744]
    mov [bp-0x4],ax
    mov ax,[0x7746]
    mov [bp-0x16],ax
    call 0xaeb6
    mov [bp-0x12],ax
    dec word [bp+0x8]
loc_A07E:
    sub di,di
    mov byte [bp-0x9],0x0
    mov [bp-0x8],di
    mov [bp-0xc],di
    jmp short loc_A08F
loc_A08C:
    inc word [bp-0xc]
loc_A08F:
    cmp word [bp-0xc],byte +0x20
    jnl loc_A0E9
    mov bx,[bp-0xc]
    shl bx,1
    add bx,[bp-0x4]
    add di,[bx]
    mov ax,[bp-0x14]
    dec word [bp-0x14]
    or ax,ax
    jnz loc_A0C9
    mov word [bp-0x14],0x7
    mov ax,[bp-0x12]
    mov [bp-0x10],ax
    dec word [bp+0x8]
    js loc_A0BF
    call 0xaeb6
    mov [bp-0x12],ax
loc_A0BF:
    mov ax,[bp-0x10]
    cwd
    or [bp-0xa],ax
    or [bp-0x8],dx
loc_A0C9:
    shl word [bp-0xa],1
    rcl word [bp-0x8],1
    mov bx,[bp-0xc]
    shl bx,1
    add bx,[bp-0x4]
    mov ax,[bx]
    sub dx,dx
    sub [bp-0xa],ax
    sbb [bp-0x8],dx
    cmp [bp-0x8],dx
    jnl loc_A08C
    add di,[bp-0xa]
loc_A0E9:
    mov bx,di
    mov bl,bh
    sub bh,bh
    add bx,[bp-0x16]
    mov al,[bx]
    sub ah,ah
    mov [bp-0x2],ax
    cmp ax,0x81
    jnl loc_A108
    mov bx,[bp-0xe]
    mov al,[bp-0x2]
    mov [bx],al
    jmp short loc_A13A
loc_A108:
    cmp [bp-0xe],si
    jz loc_A11C
    mov bx,[bp-0xe]
    cmp byte [bx-0x1],0x20
    jz loc_A11C
    inc word [bp-0xe]
    mov byte [bx],0x20
loc_A11C:
    mov bx,[bp-0x2]
    shl bx,1
    add bx,[0x773a]
    push word [bx-0x102]
    push word [bp-0xe]
    call 0x960a
    add sp,byte +0x4
    mov [bp-0xe],ax
    mov bx,ax
    mov byte [bx],0x20
loc_A13A:
    mov bx,[bp-0xe]
    inc word [bp-0xe]
    cmp byte [bx],0x0
    jz loc_A148
    jmp loc_A07E
loc_A148:
    sub word [bp-0xe],byte +0x2
    mov bx,[bp-0xe]
    cmp byte [bx],0x20
    jnz loc_A157
    mov byte [bx],0x0
loc_A157:
    pop si
    pop di
    mov sp,bp
    pop bp
    ret
