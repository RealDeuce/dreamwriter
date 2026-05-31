bits 16
org 0

%include "build/gw-basic-symbols.inc"

; Current policy is the flat64 model: load one GWBASIC.OVR into the card
; loader's segment and enter it with CS=DS=ES=SS.  The future split128 model
; should choose a separate overlay/container when enough RAM is available; see
; docs/memory-model.md before changing this loader path.

GW_WRAPPER_STACK_SIZE equ 0x0400
%ifndef GW_BASIC_MIN_FREE
GW_BASIC_MIN_FREE equ 4096
%endif
%ifndef GW_BASIC_LOAD_OFFSET
GW_BASIC_LOAD_OFFSET equ 0x0800
%endif
%ifndef GW_OVR_SIZE
%error "GW_OVR_SIZE must be defined"
%endif
GW_BASIC_REQUIRED_SIZE equ GW_LSTVAR + 2 + GW_BASIC_MIN_FREE

; DreamWriter ROM CARD executable header.
; The T400 loader reads EROMCARD.X to physical 0x0A4F0, checks these words,
; and calls the far pointer at +4.
    dw 0xA4F0
    dw 0x1997
    dw entry
    dw 0x0A4F

%macro restore_loader_stack 0
    push cs
    pop ds
    cli
    mov ax, [old_ss]
    mov bx, [old_sp]
    mov ss, ax
    mov sp, bx
    sti
%endmacro

entry:
    mov bx, ax
    mov ax, cs
    mov ds, ax
    mov [old_sp], sp
    mov ax, ss
    mov [old_ss], ax
    mov [stack_top], bx

    mov ax, bx
    sub ax, GW_WRAPPER_STACK_SIZE
    jc not_enough_memory
    mov [basic_limit], ax
    cmp ax, GW_BASIC_REQUIRED_SIZE
    jb not_enough_memory

    mov ax, loading_message
    call print_message
    call open_overlay
    mov [cs:file_handle], ax
    cmp word [cs:file_handle], 0xffff
    je open_failed

    call read_overlay
    mov [cs:read_count], ax
    cmp word [cs:read_count], GW_OVR_SIZE
    jne read_failed

    call close_overlay
    call verify_overlay
    jc verify_failed
    mov ax, cs
    mov ds, ax
    mov ax, [basic_limit]
    mov [GW_DW_LOADER_LIMIT], ax
    cli
    mov ax, cs
    mov ss, ax
    mov sp, [stack_top]
    sti
    jmp GW_INIT

not_enough_memory:
    mov ax, not_enough_message
    call print_message_wait
    mov ax, cs
    mov ds, ax
    restore_loader_stack
    retf

open_failed:
    mov ax, open_failed_message
    call print_message_wait
    mov ax, cs
    mov ds, ax
    restore_loader_stack
    retf

read_failed:
    call close_overlay
    mov ax, read_failed_message
    call print_message_wait
    mov ax, cs
    mov ds, ax
    restore_loader_stack
    retf

verify_failed:
    mov ax, verify_failed_message
    call print_message_wait
    mov ax, cs
    mov ds, ax
    restore_loader_stack
    retf

open_overlay:
    ; DS=CS on entry and exit. The open wrapper consumes DS:offset for the
    ; filename, while the vector table lives in low RAM, so fetch the vector
    ; through ES instead of changing DS.
    push es
    xor ax, ax
    mov es, ax
    push word 0x0000
    push word overlay_path
    call far [es:0x0244]
    add sp, 4
    pop es
    ret

read_overlay:
    ; DS=CS is the destination segment for the ROM read wrapper. Fetch the
    ; vector through ES=0 so DS remains the buffer segment.
    push es
    mov ax, cs
    mov ds, ax
    mov ax, [file_handle]
    mov bx, GW_BASIC_LOAD_OFFSET
    mov cx, GW_OVR_SIZE
    push ax
    xor ax, ax
    mov es, ax
    pop ax
    call far [es:0x0248]
    pop es
    ret

close_overlay:
    push es
    mov ax, cs
    mov ds, ax
    mov ax, [file_handle]
    push ax
    xor ax, ax
    mov es, ax
    pop ax
    call far [es:0x0250]
    pop es
    ret

verify_overlay:
    push ds
    push es
    push si
    push di
    push cx
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov si, expected_overlay_prefix
    mov di, GW_BASIC_LOAD_OFFSET
    mov cx, expected_overlay_prefix_end - expected_overlay_prefix
    cld
    repe cmpsb
    clc
    je .done
    stc
.done:
    pop cx
    pop di
    pop si
    pop es
    pop ds
    ret

; AX = CS-relative NUL-terminated string.  The T400 print vector takes AX:BX as
; a far pointer and CX:DX as the display position; keep this wrapper identical
; in shape to the smoke-test shim.
print_message:
    push cx
    push dx
    xor cx, cx
    xor dx, dx
    call dw_puts_cs
    pop dx
    pop cx
    ret

print_message_wait:
    call print_message
    call dw_getkey
    ret

%include "src/include/dwapi.asm"

old_ss:
    dw 0
old_sp:
    dw 0
basic_limit:
    dw 0
stack_top:
    dw 0
file_handle:
    dw 0
read_count:
    dw 0

not_enough_message:
    db "DW-BASIC NEEDS MORE MEMORY", 13
    db "PRESS KEY TO RETURN", 0
loading_message:
    db "LOADING DW-BASIC", 0
before_open_message:
    db "BEFORE OPEN", 13
    db "PRESS KEY", 0
after_open_message:
    db "AFTER OPEN", 13
    db "PRESS KEY", 0
before_read_message:
    db "BEFORE READ", 13
    db "PRESS KEY", 0
after_read_message:
    db "AFTER READ", 13
    db "PRESS KEY", 0
before_close_message:
    db "BEFORE CLOSE", 13
    db "PRESS KEY", 0
after_close_message:
    db "AFTER CLOSE", 13
    db "PRESS KEY", 0
before_verify_message:
    db "BEFORE VERIFY", 13
    db "PRESS KEY", 0
after_verify_message:
    db "AFTER VERIFY", 13
    db "PRESS KEY", 0
open_failed_message:
    db "CAN NOT OPEN GWBASIC.OVR", 13
    db "PRESS KEY TO RETURN", 0
read_failed_message:
    db "CAN NOT READ GWBASIC.OVR", 13
    db "PRESS KEY TO RETURN", 0
verify_failed_message:
    db "BAD GW-BASIC.OVR LOAD", 13
    db "PRESS KEY TO RETURN", 0
verified_message:
    db "GWBASIC.OVR VERIFIED", 13
    db "PRESS KEY TO START", 0
overlay_path:
    db "I:GWBASIC.OVR", 0
overlay_path_end:
expected_overlay_prefix:
    incbin "build/GWBASIC.OVR", 0, 16
expected_overlay_prefix_end:

%if ($ - $$) > GW_BASIC_LOAD_OFFSET
%error "EROMCARD.X loader overlaps GW-BASIC overlay load offset"
%endif
