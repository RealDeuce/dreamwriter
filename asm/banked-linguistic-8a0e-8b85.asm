; DreamWriter T400 ROM -- banked linguistic slice
;
; Segment:     3000:
; File range:  0x38A0E..0x38F95 (t4_ir_2.1.ic303)
;
; Verified source-for-byte-accuracy slice for the dictionary-word decode helpers
; following `banked-dictionary-stream-init.md` (through `8F95`).
;
BITS 16
org 0x8A0E

;-------------------------------------------------------------------------------
; 3000:8A0E..8A7D
; dictionary_staged_word_postprocess_C3000_8A0E
;-------------------------------------------------------------------------------
dictionary_staged_word_postprocess_C3000_8A0E:
    push bp
    mov bp, sp
    sub sp, byte +0x2
    push di
    push si
    mov si, [bp+0x4]
    sub si, byte +0x2
    mov di, 0x8aa4
    mov word [0x8ab0], 0x0
    mov al, [si]
    sub ah, ah
    cmp ax, 0xff
    jz 0x8a3a

    mov byte [di], 0x1
    inc di
    mov [di], ah
    pop si
    pop di
    mov sp, bp
    pop bp
    ret

_loc_8A3A:
    sub si, byte +0x2
    mov al, [si]
    sub ah, ah
    cmp ax, 0xff
    jz 0x8a3a

    add si, byte +0x2
    mov [si], ah
    inc si
    test byte [si], 0x80
    jz 0x8a5c

    inc si
    mov al, [si-0x1]
    sub ah, ah
    mov [0x8ab0], ax
    jmp short 0x8a60

_loc_8A5C:
    lodsb
    mov [di], al
    inc di

_loc_8A60:
    inc si
    cmp byte [si-0x1], 0x0
    jnz 0x8a4c

    mov byte [di], 0x0
    cmp byte [0x8aa4], 0x0
    jnz 0x8a78

    mov byte [di], 0x1
    inc di
    mov byte [di], 0x0

_loc_8A78:
    pop si
    pop di
    mov sp, bp
    pop bp
    ret


;-------------------------------------------------------------------------------
; 3000:8A7E..8ABB
; compare_staged_word_payload_C3000_8A7E
;-------------------------------------------------------------------------------
compare_staged_word_payload_C3000_8A7E:
    push bp
    mov bp, sp
    sub sp, byte +0x4
    push di
    push si

    mov bx, [bp+0x4]
    inc word [bp+0x4]
    mov al, [bx]
    sub ah, ah
    mov si, ax
    mov bx, [bp+0x6]
    inc word [bp+0x6]
    mov al, [bx]
    sub ah, ah
    mov di, ax
    or di, di
    jz 0x8aaa

    cmp si, di
    jz 0x8a86

    cmp di, 0xff
    jnz 0x8ab2

_loc_8AAA:
    mov ax, si
    pop si
    pop di
    mov sp, bp
    pop bp
    ret

_loc_8AB2:
    mov ax, si
    sub ax, di
    pop si
    pop di
    mov sp, bp
    pop bp
    ret

_loc_8A86:
    mov ax, si
    pop si
    pop di
    mov sp, bp
    pop bp
    ret


;-------------------------------------------------------------------------------
; 3000:8ABC..8B09
; dictionary_word_index_search_C3000_8ABC
;-------------------------------------------------------------------------------
dictionary_word_index_search_C3000_8ABC:
    push bp
    mov bp, sp
    sub sp, byte +0x8
    push di
    push si

    mov ax, [0x751a]
    mov [bp-0x8], ax
    sub di, di
    mov si, [0x750e]

    jmp short 0x8afb

_loc_8AD2:
    mov ax, si
    add ax, di
    inc ax
    sar ax, 1
    mov [bp-0x4], ax

    mov bx, ax
    shl bx, 1
    add bx, [bp-0x8]
    push word [bx]
    push word [bp+0x4]
    call compare_staged_word_payload_C3000_8A7E
    add sp, byte +0x4
    or ax, ax
    jl 0x8af8

    mov di, [bp-0x4]
    jmp short 0x8afc

_loc_8AF7:
    nop

_loc_8AF8:
    mov si, [bp-0x4]

_loc_8AFB:
    dec si
    cmp di, si
    jl 0x8ad2

    mov [0x8a5a], si
    pop si
    pop di
    mov sp, bp
    pop bp
    ret


;-------------------------------------------------------------------------------
; 3000:8B0A..8B85
; decode_edit_stream_to_output_C3000_8B0A
;-------------------------------------------------------------------------------
decode_edit_stream_to_output_C3000_8B0A:
    push bp
    mov bp, sp
    sub sp, byte +0xa
    push di
    push si

    mov word [bp-0x4], 0x7502
    mov di, [0x8ab2]
    mov ax, [0x7528]
    mov [bp-0x8], ax

_loc_8B21:
    mov bx, [bp-0x8]
    inc word [bp-0x8]
    mov al, [bx]
    sub ah, ah
    mov si, ax
    or si, si
    jz 0x8b68

    mov bx, [0x8a50]
    cmp [bx+0x4], si
    jng 0x8b60

    mov [di], al
    inc di
    cmp si, byte +0x4
    jnz 0x8b21

    jmp short 0x8b49

_loc_8B49:
    mov ax, si
    mov [di], al
    inc di

    mov bx, [bp-0x8]
    inc word [bp-0x8]
    mov al, [bx]
    sub ah, ah
    mov si, ax
    cmp si, 0xff
    jnz 0x8b49

    dec word [bp-0x8]
    jmp short 0x8b21

_loc_8B60:
    mov bx, [bp-0x4]
    cmp [bx+0x1c], si
    jng 0x8b86

    mov byte [di], 0x0
    mov [0x8ab2], di
    mov bx, [bp-0x4]
    mov ax, [bp-0x8]
    dec ax
    mov [bx+0x26], ax

    push di
    call dictionary_staged_word_postprocess_C3000_8A0E
    add sp, byte +0x2

    pop si
    pop di
    mov sp, bp
    pop bp
    ret

_loc_8B68:
    cmp si, 0xff
    jnl 0x8bae

    mov ax, si
    shl ax, 1
    mov [bp-0xa], ax

    mov bx, [bp-0x4]
    mov bx, [bx+0x16]
    add bx, ax
    mov al, [bx]
    mov [di], al
    inc di

    mov bx, [bp-0x4]
    mov bx, [bx+0x16]
    add bx, [bp-0xa]
    mov al, [bx+0x1]
    jmp short 0x8bbb

;-------------------------------------------------------------------------------
; 3000:8B86..8F95
; decode_edit_stream_to_output_C3000_8B0A (extended tail + stream helpers)
;-------------------------------------------------------------------------------
_loc_8B86:
    cmp si, 0xff
    jnl 0x8bae

    mov ax, si
    shl ax, 1
    mov [bp-0xa], ax

    mov bx, [bp-0x4]
    mov bx, [bx+0x16]
    add bx, ax
    mov al, [bx]
    mov [di], al
    inc di

    mov bx, [bp-0x4]
    mov bx, [bx+0x16]
    add bx, [bp-0xa]
    mov al, [bx+0x1]
    jmp short 0x8bbb

_loc_8BAE:
    mov ax, si
    mov [di], al
    inc di

    mov bx, [bp-0x8]
    inc word [bp-0x8]
    mov al, [bx]
    mov [di], al
    inc di
    jmp 0x8b21

_loc_8BC1:
    nop

;-------------------------------------------------------------------------------
; 3000:8BC2..8E03
; decode_dictionary_word_to_buffer_C3000_8BC2
;-------------------------------------------------------------------------------
decode_dictionary_word_to_buffer_C3000_8BC2:
    push bp
    mov bp, sp
    sub sp, byte +0x1a
    push di
    push si
    mov word [bp-0x14], 0x7502
    mov ax, [0x751c]
    mov [bp-0x16], ax
    mov ax, [0x7514]
    mov [bp-0x12], ax
    mov ax, [0x7516]
    mov [bp-0x10], ax
    mov ax, [0x751e]
    mov [bp-0xe], ax
    mov ax, [0x7518]
    mov [bp-0x18], ax
    mov bx, [0x8a50]
    mov ax, [bx+0x4]
    add ax, 0xf
    mov [bp-0xc], ax
    mov ax, [0x7528]
    mov [bp-0x2], ax
    mov di, [0x8ab2]
    mov word [bp-0x1a], 0x8a5c
    mov byte [di], 0x0
    mov ax, [bp-0x1a]
    sub ax, 0x8a50
    add ax, [bp+0x4]
    sub ax, 0xc
    mov [bp-0x4], ax

_loc_8C1B:
    mov bx, [bp-0x1a]
    inc word [bp-0x1a]
    mov al, [bx]
    sub ah, ah
    mov si, ax

    mov bx, [bp-0x4]
    inc word [bp-0x4]
    mov al, [bx]
    mov [bp-0x8], ax
    cmp ax, si
    jz 0x8c4e
    cmp si, 0xff
    jz 0x8c44
    cmp [bp-0x8], si
    jng 0x8c64
    jmp short 0x8c77

_loc_8C43:
    nop

_loc_8C44:
    cmp word [bp-0x8], byte +0x0
    jz 0x8c4e
    sub si, si
    jmp short 0x8c3c

_loc_8C4E:
    cmp word [bp-0x8], byte +0x0
    jnz 0x8c1b
    push di
    call dictionary_staged_word_postprocess_C3000_8A0E
    add sp, byte +0x2
    mov ax, 0x1
    pop si
    pop di
    mov sp, bp
    pop bp
    ret

_loc_8C64:
    dec word [bp-0x1a]
    mov bx, [bp-0x2]
    inc word [bp-0x2]
    mov al, [bx]
    sub ah, ah
    mov si, ax
    or si, si
    jnz 0x8c80
    sub ax, ax
    pop si
    pop di
    mov sp, bp
    pop bp
    ret

_loc_8C7F:
    nop

_loc_8C80:
    mov word [bp-0x8], 0x0
    cmp [bp-0x16], si
    jng 0x8cbc
    mov bx, [0x8a50]
    mov ax, si
    sub ax, [bx+0x4]
    sub di, ax
    cmp [bp-0xc], si
    jnz 0x8cad
    mov bx, [bp-0x2]
    inc word [bp-0x2]
    mov al, [bx]
    sub ah, ah
    mov bx, [0x8a50]
    sub ax, [bx+0x4]
    sub di, ax

_loc_8CAD:
    cmp [bp-0x1a], di
    jc 0x8cfe
    mov word [bp-0x8], 0x1
    mov [bp-0x1a], di
    jmp short 0x8cfe

_loc_8CBC:
    mov bx, [bp-0x12]
    mov al, [bx+si]
    sub ah, ah
    sub di, ax
    mov bx, [bp-0x10]
    mov ax, si
    shl ax, 1
    add bx, ax
    mov ax, [bx]
    mov [bp-0x4], ax
    cmp [bp-0x1a], di
    jc 0x8cf3
    mov word [bp-0x8], 0x1
    mov [bp-0x1a], di
    mov bx, [bp-0x4]
    inc word [bp-0x4]
    mov al, [bx]
    mov [di], al
    inc di
    or al, al
    jnz 0x8ce0
    dec di
    jmp short 0x8cfe

_loc_8CF2:
    inc di

_loc_8CF3:
    mov bx, [bp-0x4]
    inc word [bp-0x4]
    cmp byte [bx], 0x0
    jnz 0x8cf2

_loc_8CFE:
    cmp word [bp-0x8], byte +0x0
    jnz 0x8d70
    mov bx, [bp-0x2]
    inc word [bp-0x2]
    mov al, [bx]
    sub ah, ah
    mov si, ax
    or si, si
    jnz 0x8d17
    jmp 0x8d99

_loc_8D12:
    jnz 0x8d17
    jmp 0x8d99

_loc_8D17:
    mov bx, [0x8a50]
    cmp [bx+0x4], si
    jng 0x8d3e
    inc di
    cmp si, byte +0x4
    jnz 0x8d04
    jmp short 0x8d29

_loc_8D26:
    nop

_loc_8D28:
    inc di

_loc_8D29:
    mov bx, [bp-0x2]
    inc word [bp-0x2]
    mov al, [bx]
    sub ah, ah
    cmp ax, 0xff
    jnz 0x8d28
    dec word [bp-0x2]
    jmp short 0x8d04

_loc_8D3D:
    nop

_loc_8D3E:
    cmp [bp-0xe], si
    jg 0x8d99
    cmp si, 0xff
    jnl 0x8d4e
    add di, byte +0x2
    jmp short 0x8d04

_loc_8D4E:
    add di, byte +0x2
    inc word [bp-0x2]
    jmp short 0x8d04

_loc_8D56:
    mov ax, si
    mov [di], al
    inc di
    mov bx, [bp-0x2]
    inc word [bp-0x2]
    mov al, [bx]
    sub ah, ah
    mov si, ax
    cmp si, 0xff
    jnz 0x8d56
    dec word [bp-0x2]

_loc_8D70:
    mov bx, [bp-0x2]
    inc word [bp-0x2]
    mov al, [bx]
    sub ah, ah
    mov si, ax
    or si, si
    jz 0x8d99
    mov bx, [0x8a50]
    cmp [bx+0x4], si
    jng 0x8d94
    mov [di], al
    inc di
    cmp si, byte +0x4
    jnz 0x8d70
    jmp short 0x8d5b

_loc_8D93:
    nop

_loc_8D94:
    cmp [bp-0xe], si
    jng 0x8da8

_loc_8D99:
    dec word [bp-0x2]
    cmp word [bp-0x8], byte +0x0
    jnz 0x8da5
    jmp 0x8c67

_loc_8DA5:
    jmp 0x8c09

_loc_8DA8:
    cmp si, 0xff
    jnl 0x8dca
    mov ax, [bp-0x18]
    mov cx, si
    shl cx, 1
    add ax, cx
    mov [bp-0x4], ax
    mov bx, ax
    inc word [bp-0x4]
    mov al, [bx]
    mov [di], al
    inc di
    mov bx, [bp-0x4]
    jmp short 0x8dd5

_loc_8DCA:
    mov ax, si
    mov [di], al
    inc di
    mov bx, [bp-0x2]
    inc word [bp-0x2]
    mov al, [bx]
    mov [di], al
    inc di
    jmp short 0x8d70

_loc_8DDC:
    push bp
    mov bp, sp
    sub sp, byte +0x6
    push si
    mov si, [bp+0x4]
    mov bx, [bp+0x6]
    mov byte [bx], 0x0
    push si
    call decode_dictionary_word_to_buffer_C3000_8E04
    add sp, byte +0x2
    or ax, ax
    jz 0x8e01
    mov ax, 0x8aa4
    push ax
    push word [bp+0x6]
    call 0x960a
    add sp, byte +0x4
_loc_8E01:
    pop si
    pop bp
    ret

;-------------------------------------------------------------------------------
; 3000:8E04..8F05
; decode_dictionary_word_to_buffer_C3000_8E04
;-------------------------------------------------------------------------------
decode_dictionary_word_to_buffer_C3000_8E04:
    push bp
    mov bp, sp
    sub sp, byte +0x56
    push di
    push si
    lea ax, [bp-0x4a]
    push ax
    push word [bp+0x4]
    call 0x92bc
    add sp, byte +0x4
    lea ax, [bp-0x4a]
    push ax
    call dictionary_word_index_search_C3000_8ABC
    add sp, byte +0x2
    mov si, 0x7502
    mov bx, [si+0x18]
    mov ax, [0x8a5a]
    shl ax, 1
    add bx, ax
    mov ax, [bx]
    mov [bp-0x50], ax
    push ax
    lea ax, [bp-0x4a]
    push ax
    call compare_staged_word_payload_C3000_8A7E
    add sp, byte +0x4
    or ax, ax
    jnz 0x8e62
    push word [bp-0x50]
    mov ax, 0x8a5c
    push ax
    call 0x960a
    add sp, byte +0x4
    push ax
    call dictionary_staged_word_postprocess_C3000_8A0E
    add sp, byte +0x2
    mov ax, 0x1
    pop si
    pop di
    mov sp, bp
    pop bp
    ret

_loc_8E61:
    nop

_loc_8E62:
    call 0x89e2
    or ax, ax
    jnz 0x8e72
    sub ax, ax
    pop si
    pop di
    mov sp, bp
    pop bp
    ret

_loc_8E71:
    nop

_loc_8E72:
    mov ax, 0x864e
    mov [bp-0x4e], ax
    mov [bp-0x54], ax
    mov word [bp-0x4c], 0x8655
    sub di, di
    jmp short 0x8e8b

_loc_8E84:
    mov ax, [bp-0x4e]
    mov [bp-0x4c], ax
    inc di

_loc_8E8B:
    cmp di, byte +0x7
    jnl 0x8ecd
    mov bx, [bp-0x54]
    cmp byte [bx], 0x0
    jz 0x8ecd
    inc word [bp-0x54]
    mov al, [bx]
    sub ah, ah
    add ax, [si+0x6]
    add [bp-0x4e], ax
    mov ax, [bp-0x4e]
    mov [si+0x26], ax
    mov word [0x8ab2], 0x8a5c
    call decode_edit_stream_to_output_C3000_8B0A
    mov ax, 0x8a5c
    push ax
    lea ax, [bp-0x4a]
    push ax
    call 0x969e
    add sp, byte +0x4
    mov [bp-0x2], ax
    or ax, ax
    jz 0x8e58
    or ax, ax
    jnl 0x8e84

_loc_8ECD:
    mov ax, [bp-0x4c]
    mov [si+0x26], ax
    or di, di
    jz 0x8ee2
    mov word [0x8ab2], 0x8a5c
    call decode_edit_stream_to_output_C3000_8B0A
    jmp short 0x8ef2

_loc_8EE2:
    push word [bp-0x50]
    mov ax, 0x8a5c
    push ax
    call 0x960a
    add sp, byte +0x4
    mov [0x8ab2], ax

_loc_8EF2:
    lea ax, [bp-0x4a]
    push ax
    call decode_dictionary_word_to_buffer_C3000_8BC2
    add sp, byte +0x2
    or ax, ax
    jnz 0x8f03
    jmp 0x8e69

_loc_8F03:
    jmp 0x8e58

;-------------------------------------------------------------------------------
; 3000:8F06..8F95
; decode_edit_stream_advance_record_C3000_8F06
;-------------------------------------------------------------------------------
decode_edit_stream_advance_record_C3000_8F06:
    push bp
    mov bp, sp
    sub sp, byte +0x6
    push di
    push si
    mov di, 0x7502
    mov ax, [di+0x26]
    mov [bp-0x6], ax
    mov bx, ax
    inc word [bp-0x6]
    mov al, [bx]
    sub ah, ah
    mov si, ax
    or si, si
    jnz 0x8f30
    call 0x8f98
    pop si
    pop di
    mov sp, bp
    pop bp
    ret

_loc_8F2F:
    nop

_loc_8F30:
    cmp [di+0x1a], si
    jng 0x8f64
    mov bx, [0x8a50]
    mov ax, si
    sub ax, [bx+0x4]
    sub [0x8ab2], ax
    mov ax, [bx+0x4]
    add ax, 0xf
    cmp ax, si
    jnz 0x8f85
    mov bx, [bp-0x6]
    inc word [bp-0x6]
    mov al, [bx]
    sub ah, ah
    mov bx, [0x8a50]
    sub ax, [bx+0x4]
    sub [0x8ab2], ax
    jmp short 0x8f85

_loc_8F63:
    nop

_loc_8F64:
    mov bx, [di+0x14]
    mov ax, si
    shl ax, 1
    add bx, ax
    push word [bx]
    mov ax, [0x8ab2]
    mov bx, [di+0x12]
    mov cl, [bx+si]
    sub ch, ch
    sub ax, cx
    push ax
    call 0x960a
    add sp, byte +0x4
    mov [0x8ab2], ax

_loc_8F85:
    mov ax, [bp-0x6]
    mov [di+0x26], ax
    call decode_edit_stream_to_output_C3000_8B0A
    mov ax, 0x1
    pop si
    pop di
    mov sp, bp
    pop bp
    ret
