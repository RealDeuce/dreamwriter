; DreamWriter firmware shims.
;
; These wrappers preserve the application DS around firmware calls. The T400
; 2.1 ROM helpers expect their normal firmware data segment in DS, which is the
; zero-based low-RAM segment for the low-RAM vector table and display scratch
; buffer. String pointers are passed explicitly as AX:BX far pointers.
;
; ROM-specific surface for T400 2.1:
;   DW_VEC_PUTS   -> DC98:0E81
;   DW_VEC_GETKEY -> DC98:0CF9
;
; Keep raw firmware vector offsets here so later ROM ports only need a small
; compatibility layer instead of target addresses scattered through the port.

DW_VEC_PUTS equ 0x0204
DW_VEC_GETKEY equ 0x0230

dw_puts_cs:
    push ax
    push bx
    push cx
    push dx
    push si
    push ds
    mov si, ax
    xor ax, ax
    mov ds, ax
    mov ax, si
    mov bx, cs
    call far [DW_VEC_PUTS]
    pop ds
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

dw_getkey:
    push ds
    xor ax, ax
    mov ds, ax
    call far [DW_VEC_GETKEY]
    pop ds
    ret
