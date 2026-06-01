bits 16
org 0

%include "build/gw-basic-symbols.inc"

; Current policy is the flat64 model: load one DW-BASIC.FLT into the card
; loader's segment and enter it with CS=DS=ES=SS.  The future split128 model
; should choose a separate overlay/container when enough RAM is available; see
; docs/memory-model.md before changing this loader path.

GW_WRAPPER_STACK_SIZE equ 0x0400
GW_OVR_READ_CHUNK equ 0x0200
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
    mov ax, ds
    mov [old_ds], ax
    mov ax, es
    mov [old_es], ax
    mov ax, cs
    mov ds, ax
    mov [old_sp], sp
    mov ax, ss
    mov [old_ss], ax
    mov bp, sp
    mov ax, [ss:bp]
    mov [old_ip], ax
    mov ax, [ss:bp+2]
    mov [old_cs], ax
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
    mov ax, [old_ds]
    mov [GW_DW_EXIT_DS], ax
    mov ax, [old_es]
    mov [GW_DW_EXIT_ES], ax
    mov ax, [old_ss]
    mov [GW_DW_EXIT_SS], ax
    mov ax, [old_sp]
    mov [GW_DW_EXIT_SP], ax
    mov ax, [old_ip]
    mov [GW_DW_EXIT_IP], ax
    mov ax, [old_cs]
    mov [GW_DW_EXIT_CS], ax
    cli
    mov ax, cs
    mov ss, ax
    mov sp, [stack_top]
    sti
    jmp GW_INIT

not_enough_memory:
    call snapshot_not_enough_state
    call fill_not_enough_segment_dump
    call print_not_enough_dump_wait
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
    push si
    mov ax, cs
    mov ds, ax
    mov bx, GW_BASIC_LOAD_OFFSET
    mov si, GW_OVR_SIZE
    mov word [read_count], 0
.loop:
    or si, si
    jz .done
    mov cx, GW_OVR_READ_CHUNK
    cmp si, cx
    jae .have_chunk
    mov cx, si
.have_chunk:
    mov ax, [file_handle]
    push bx
    push cx
    push si
    push ax
    xor ax, ax
    mov es, ax
    pop ax
    call far [es:0x0248]
    pop si
    pop cx
    pop bx
    jc .done
    or ax, ax
    jz .done
    cmp ax, cx
    ja .done
    push cs
    pop ds
    add bx, ax
    sub si, ax
    add [read_count], ax
    cmp ax, cx
    je .loop
.done:
    mov ax, [read_count]
    pop si
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

print_not_enough_dump_wait:
    xor cx, cx
    xor dx, dx
    mov ax, not_enough_title
    call dw_puts_cs
    mov dx, 8
    mov ax, not_enough_segments
    call dw_puts_cs
    mov dx, 16
    mov ax, not_enough_stack
    call dw_puts_cs
    mov dx, 24
    mov ax, not_enough_indirect
    call dw_puts_cs
    mov dx, 32
    mov ax, not_enough_prompt
    call dw_puts_cs
    call dw_getkey
    ret

snapshot_not_enough_state:
    mov [cs:not_enough_saved_bp], bp
    mov [cs:not_enough_saved_bx], bx
    mov [cs:not_enough_saved_di], di
    mov [cs:not_enough_saved_ax], ax
    mov ax, bx
    add ax, di
    sub ax, 2
    mov [cs:not_enough_saved_ea], ax
    push bx
    mov bx, ax
    mov ax, [cs:bx]
    mov [cs:not_enough_saved_target], ax
    pop bx
    mov bp, sp

    push cs
    pop ax
    mov [cs:not_enough_saved_cs], ax
    mov ax, ds
    mov [cs:not_enough_saved_ds], ax
    mov ax, es
    mov [cs:not_enough_saved_es], ax
    mov ax, ss
    mov [cs:not_enough_saved_ss], ax

    lea ax, [bp + 2]
    mov [cs:not_enough_saved_sp], ax
    mov ax, [ss:bp + 2]
    mov [cs:not_enough_saved_s0], ax
    mov ax, [ss:bp + 4]
    mov [cs:not_enough_saved_s2], ax

    mov bp, [cs:not_enough_saved_bp]
    ret

fill_not_enough_segment_dump:
    push ax
    push bx
    push di
    push ds

    push cs
    pop ds

    mov ax, [not_enough_saved_cs]
    mov di, not_enough_cs_value
    call write_hex_word
    mov ax, [not_enough_saved_ds]
    mov di, not_enough_ds_value
    call write_hex_word
    mov ax, [not_enough_saved_es]
    mov di, not_enough_es_value
    call write_hex_word
    mov ax, [not_enough_saved_ss]
    mov di, not_enough_ss_value
    call write_hex_word
    mov ax, [not_enough_saved_sp]
    mov di, not_enough_sp_value
    call write_hex_word
    mov ax, [not_enough_saved_bp]
    mov di, not_enough_bp_value
    call write_hex_word
    mov ax, [not_enough_saved_s0]
    mov di, not_enough_s0_value
    call write_hex_word
    mov ax, [not_enough_saved_s2]
    mov di, not_enough_s2_value
    call write_hex_word
    mov ax, [not_enough_saved_bx]
    mov di, not_enough_bx_value
    call write_hex_word
    mov ax, [not_enough_saved_di]
    mov di, not_enough_di_value
    call write_hex_word
    mov ax, [not_enough_saved_ea]
    mov di, not_enough_ea_value
    call write_hex_word
    mov ax, [not_enough_saved_target]
    mov di, not_enough_target_value
    call write_hex_word

    pop ds
    pop di
    pop bx
    pop ax
    ret

; AX = word, DS:DI = four ASCII hex digits.
write_hex_word:
    push ax
    mov al, ah
    call write_hex_byte
    pop ax
    call write_hex_byte
    ret

; AL = byte, DS:DI = two ASCII hex digits. Advances DI.
write_hex_byte:
    push ax
    mov ah, al
    shr al, 4
    call write_hex_nibble
    mov al, ah
    and al, 0x0f
    call write_hex_nibble
    pop ax
    ret

; AL = low nibble, DS:DI = output digit. Advances DI.
write_hex_nibble:
    and al, 0x0f
    cmp al, 10
    jb .digit
    add al, "A" - 10 - "0"
.digit:
    add al, "0"
    mov [di], al
    inc di
    ret

%include "src/include/dwapi.asm"

old_ss:
    dw 0
old_ds:
    dw 0
old_es:
    dw 0
old_sp:
    dw 0
old_ip:
    dw 0
old_cs:
    dw 0
basic_limit:
    dw 0
stack_top:
    dw 0
file_handle:
    dw 0
read_count:
    dw 0
not_enough_saved_cs:
    dw 0
not_enough_saved_ds:
    dw 0
not_enough_saved_es:
    dw 0
not_enough_saved_ss:
    dw 0
not_enough_saved_sp:
    dw 0
not_enough_saved_bp:
    dw 0
not_enough_saved_s0:
    dw 0
not_enough_saved_s2:
    dw 0
not_enough_saved_bx:
    dw 0
not_enough_saved_di:
    dw 0
not_enough_saved_ax:
    dw 0
not_enough_saved_ea:
    dw 0
not_enough_saved_target:
    dw 0

not_enough_title:
    db "DW-BASIC NEEDS MORE MEMORY", 0
not_enough_segments:
    db "CS="
not_enough_cs_value:
    db "0000"
    db " DS="
not_enough_ds_value:
    db "0000"
    db " ES="
not_enough_es_value:
    db "0000"
    db " SS="
not_enough_ss_value:
    db "0000", 0
not_enough_stack:
    db "SP="
not_enough_sp_value:
    db "0000"
    db " BP="
not_enough_bp_value:
    db "0000"
    db " S0="
not_enough_s0_value:
    db "0000"
    db " S2="
not_enough_s2_value:
    db "0000", 0
not_enough_indirect:
    db "BX="
not_enough_bx_value:
    db "0000"
    db " DI="
not_enough_di_value:
    db "0000"
    db " EA="
not_enough_ea_value:
    db "0000"
    db " TG="
not_enough_target_value:
    db "0000", 0
not_enough_prompt:
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
    db "CAN NOT OPEN DW-BASIC.FLT", 13
    db "PRESS KEY TO RETURN", 0
read_failed_message:
    db "CAN NOT READ DW-BASIC.FLT", 13
    db "PRESS KEY TO RETURN", 0
verify_failed_message:
    db "BAD DW-BASIC.FLT LOAD", 13
    db "PRESS KEY TO RETURN", 0
verified_message:
    db "DW-BASIC.FLT VERIFIED", 13
    db "PRESS KEY TO START", 0
overlay_path:
    db "I:DW-BASIC.FLT", 0
overlay_path_end:
expected_overlay_prefix:
    incbin "build/DW-BASIC.FLT", 0, 16
expected_overlay_prefix_end:

%if ($ - $$) > GW_BASIC_LOAD_OFFSET
%error "EROMCARD.X loader overlaps GW-BASIC overlay load offset"
%endif
