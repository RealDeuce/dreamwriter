bits 16
org 0

%ifndef SPLIT_SPIKE_DAT_ORG
SPLIT_SPIKE_DAT_ORG equ 0x1000
%endif
%ifndef SPLIT_SPIKE_COD_PAD_SIZE
SPLIT_SPIKE_COD_PAD_SIZE equ 512
%endif

SPIKE_DAT_MAGIC equ SPLIT_SPIKE_DAT_ORG + 0x0000
SPIKE_DAT_TITLE equ SPLIT_SPIKE_DAT_ORG + 0x0010
SPIKE_DAT_PROMPT equ SPLIT_SPIKE_DAT_ORG + 0x0040

entry:
    xor cx, cx
    xor dx, dx
    mov ax, code_title
    call dw_puts_cs_raw

    mov dx, 8
    mov ax, SPIKE_DAT_TITLE
    call dw_puts_ds_raw

    mov dx, 16
    mov ax, data_line_ok
    cmp byte [ds:SPIKE_DAT_MAGIC], "S"
    jne .bad_data
    cmp byte [ds:SPIKE_DAT_MAGIC + 1], "P"
    jne .bad_data
    cmp byte [ds:SPIKE_DAT_MAGIC + 2], "K"
    jne .bad_data
    cmp byte [ds:SPIKE_DAT_MAGIC + 3], "D"
    jne .bad_data
    jmp .show_data
.bad_data:
    mov ax, data_line_bad
.show_data:
    call dw_puts_cs_raw

    mov dx, 24
    mov ax, SPIKE_DAT_PROMPT
    call dw_puts_ds_raw

.wait:
    call dw_getkey
    cmp al, " "
    jne .wait
    retf

; AX=DS-relative string pointer, CX=x, DX=y.
dw_puts_ds_raw:
    push bx
    mov bx, ds
    call dw_puts_far_raw
    pop bx
    ret

; AX:BX far firmware text string pointer, CX=x, DX=y.
dw_puts_far_raw:
    pushf
    pusha
    push ds
    push es
    push ax
    xor ax, ax
    mov ds, ax
    pop ax
    call far [DW_VEC_PUTS]
    pop es
    pop ds
    popa
    popf
    ret

%include "dwapi.asm"

code_title:
    db "SPLIT SPIKE COD OK", 0
data_line_ok:
    db "DAT MAGIC OK", 0
data_line_bad:
    db "DAT MAGIC BAD", 0

%if ($ - $$) > SPLIT_SPIKE_COD_PAD_SIZE
%error "split spike COD exceeds SPLIT_SPIKE_COD_PAD_SIZE"
%endif
    times SPLIT_SPIKE_COD_PAD_SIZE - ($ - $$) db 0
