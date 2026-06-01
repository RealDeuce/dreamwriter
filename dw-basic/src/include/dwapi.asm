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
DW_VEC_DISPLAY_INFO equ 0x020c
DW_VEC_GETKEY equ 0x0230

%ifdef DWAPI_CURSOR_AWARE
extern dw_cursor_pre_puts
extern dw_cursor_post_puts
%endif

dw_puts_cs:
%ifdef DWAPI_CURSOR_AWARE
    pushf
    push ax
    call dw_cursor_pre_puts
    pop ax
    popf
    call dw_puts_cs_raw
    pushf
    push ax
    call dw_cursor_post_puts
    pop ax
    popf
    ret
%else
    jmp dw_puts_cs_raw
%endif

dw_puts_cs_raw:
    ; DC98:0E81 uses AX:BX as the string far pointer, writes its command stream
    ; through DS:72E5, and loads ES while walking the source string. Treat the
    ; firmware helper as an opaque OEM boundary and preserve caller state here.
    pushf
    pusha
    push ds
    push es
    xor bx, bx
    mov ds, bx
    mov bx, cs
    call far [DW_VEC_PUTS]
    pop es
    pop ds
    popa
    popf
    ret

dw_getkey:
    push bp
    mov bp, sp
    sub sp, 2
    pushf
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    xor bx, bx
    mov ds, bx
    call far [DW_VEC_GETKEY]
    mov [bp - 2], ax
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    popf
    mov ax, [bp - 2]
    mov sp, bp
    pop bp
    ret
