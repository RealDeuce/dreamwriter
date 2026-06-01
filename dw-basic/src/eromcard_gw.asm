bits 16
org 0

%include "build/gw-basic-symbols.inc"
%include "src/include/dwloader.inc"

; Current policy is the flat64 model: load one DW-BASIC.FLT after this
; first-stage loader and enter that same physical image through an offset-zero
; segment with CS=DS=ES=SS.  The loader segment remains resident and exposes a
; small fixed ABI table for values BASIC must read after the segment switch.

GW_WRAPPER_STACK_SIZE equ 0x0400
GW_OVR_READ_CHUNK equ 0x0200
%ifndef GW_BASIC_MIN_FREE
GW_BASIC_MIN_FREE equ 4096
%endif
%ifndef GW_BASIC_SEPARATE_SEGMENT
GW_BASIC_SEPARATE_SEGMENT equ 1
%endif
%ifndef GW_BASIC_LOAD_OFFSET
%if GW_BASIC_SEPARATE_SEGMENT
GW_BASIC_LOAD_OFFSET equ 0
%else
GW_BASIC_LOAD_OFFSET equ 0x0800
%endif
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
    dw DW_LOADER_SEGMENT

entry:
    jmp entry_code

times DW_LOADER_ABI_OFFSET - ($ - $$) db 0

loader_abi:
    dw DW_LOADER_ABI_MAGIC_VALUE
    dw DW_LOADER_ABI_VERSION_VALUE
loader_abi_limit:
    dw 0
loader_abi_basic_segment:
    dw 0
loader_abi_basic_stack_top:
    dw 0
loader_abi_exit_thunk:
    dw DW_LOADER_EXIT_THUNK_OFFSET
    dw DW_LOADER_SEGMENT
loader_abi_end:

%if (loader_abi_end - loader_abi) != DW_LOADER_ABI_SIZE
%error "DW loader ABI table size does not match dwloader.inc"
%endif

times DW_LOADER_EXIT_THUNK_OFFSET - ($ - $$) db 0

loader_exit_thunk:
%if (loader_exit_thunk - $$) != DW_LOADER_EXIT_THUNK_OFFSET
%error "DW loader exit thunk offset does not match dwloader.inc"
%endif
    push cs
    pop ds
    cli
    mov ax, [old_es]
    mov es, ax
    mov ax, [old_ds]
    mov bx, [old_ss]
    mov cx, [old_sp]
    mov ds, ax
    mov ss, bx
    mov sp, cx
    sti
    retf

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

entry_code:
    mov bx, ax
    mov ax, ds
    mov [cs:old_ds], ax
    mov ax, es
    mov [cs:old_es], ax
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

%if GW_BASIC_SEPARATE_SEGMENT
    mov ax, loader_end + 15
    mov cl, 4
    shr ax, cl
    mov [basic_segment_delta], ax
    mov dx, cs
    add dx, ax
    mov [basic_segment], dx
    mov [loader_abi_basic_segment], dx
    shl ax, cl
    mov [basic_load_offset], ax

    mov ax, bx
    sub ax, [basic_load_offset]
    jc not_enough_memory
    mov [basic_stack_top], ax
    mov [loader_abi_basic_stack_top], ax
%else
    mov ax, cs
    mov [basic_segment], ax
    mov [loader_abi_basic_segment], ax
    mov word [basic_load_offset], GW_BASIC_LOAD_OFFSET
    mov ax, bx
    mov [basic_stack_top], ax
    mov [loader_abi_basic_stack_top], ax
%endif
    sub ax, GW_WRAPPER_STACK_SIZE
    jc not_enough_memory
    mov [basic_limit], ax
    mov [loader_abi_limit], ax
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
    cli
    mov ax, [basic_segment]
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, [cs:basic_stack_top]
    sti
%if GW_BASIC_SEPARATE_SEGMENT
    push ax
    push word GW_INIT
    retf
%else
    jmp GW_INIT
%endif

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
    ; Keep the ROM read wrapper's proven current-segment destination contract:
    ; DS=CS, BX=offset.  In separate-segment mode that offset is the paragraph-
    ; aligned loader end; BASIC later sees the same physical bytes at
    ; basic_segment:0000.
    push es
    push si
    mov ax, cs
    mov ds, ax
    mov bx, [basic_load_offset]
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
    mov di, [basic_load_offset]
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
basic_stack_top:
    dw 0
basic_segment_delta:
    dw 0
basic_segment:
    dw 0
basic_load_offset:
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

loader_end:
LOADER_END_OFFSET equ loader_end - $$
%if GW_BASIC_SEPARATE_SEGMENT
%if (((LOADER_END_OFFSET + 15) / 16) * 16) + GW_OVR_SIZE > 0x10000
%error "EROMCARD.X loader plus DW-BASIC.FLT crosses segment boundary"
%endif
%else
%if ($ - $$) > GW_BASIC_LOAD_OFFSET
%error "EROMCARD.X loader overlaps GW-BASIC overlay load offset"
%endif
%endif
