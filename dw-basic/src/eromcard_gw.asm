bits 16
org 0

%ifndef GW_INIT
%include "gw-basic-symbols.inc"
%endif
%include "src/include/dwloader.inc"

; Default policy is the flat64 model: load one DW-BASIC.FLT after this
; first-stage loader and enter it through an offset-zero segment with
; CS=DS=ES=SS.  The split128 path executes DW-BASIC.COD in place from
; contiguous built-in RAM storage clusters, loads DW-BASIC.DAT at GW_DAT_ORG in
; this loader segment, and enters with CS=COD and DS=ES=SS=loader.

GW_WRAPPER_STACK_SIZE equ 0x0400
GW_OVR_READ_CHUNK equ 0x0200
DW_STORE_SEGMENT equ 0x1800
DW_STORE_SECTOR_SIZE equ 0x80
DW_STORE_ROOT_ENTRIES equ 64
DW_STORE_ROOT_ENTRY_SIZE equ 0x20
DW_STORE_FAT_OFFSET equ 0x80
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
%ifndef GW_BASIC_SPLIT_PAYLOAD
GW_BASIC_SPLIT_PAYLOAD equ 0
%endif
%ifndef GW_DEBUG_STOP_AFTER_SPLIT_LOADS
GW_DEBUG_STOP_AFTER_SPLIT_LOADS equ 0
%endif
%ifndef GW_DEBUG_SPLIT_LOAD_STOP
%if GW_DEBUG_STOP_AFTER_SPLIT_LOADS
GW_DEBUG_SPLIT_LOAD_STOP equ 4
%else
GW_DEBUG_SPLIT_LOAD_STOP equ 0
%endif
%endif
%if GW_BASIC_SPLIT_PAYLOAD
%ifndef GW_COD_SIZE
%error "GW_COD_SIZE must be defined"
%endif
%ifndef GW_DAT_SIZE
%error "GW_DAT_SIZE must be defined"
%endif
%ifndef GW_DAT_ORG
%error "GW_DAT_ORG must be defined"
%endif
GW_COD_CLUSTERS equ (GW_COD_SIZE + 127) / 128
%ifndef GW_COD_PREFIX_PATH
%define GW_COD_PREFIX_PATH "build-split/DW-BASIC.COD"
%endif
%ifndef GW_DAT_PREFIX_PATH
%define GW_DAT_PREFIX_PATH "build-split/DW-BASIC.DAT"
%endif
%else
%ifndef GW_OVR_SIZE
%error "GW_OVR_SIZE must be defined"
%endif
%endif
%ifndef GW_ENTRY_OFFSET
GW_ENTRY_OFFSET equ GW_INIT
%endif
GW_BASIC_STACK_RESERVE equ GW_WRAPPER_STACK_SIZE
GW_BASIC_REQUIRED_SIZE equ GW_LSTVAR + 2 + GW_BASIC_MIN_FREE

%macro debug_split_load_stop 1
%if GW_DEBUG_SPLIT_LOAD_STOP = %1
.debug_split_load_stop_%1:
    cli
    jmp .debug_split_load_stop_%1
%endif
%endmacro

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
    push ds
    mov ax, [old_ds]
    mov ds, ax
    mov ax, [0x7a54]
    pop ds
    mov [rom_work_blocks], ax

%if GW_BASIC_SEPARATE_SEGMENT
    mov ax, loader_end + 15
    mov cl, 4
    shr ax, cl
    mov [basic_segment_delta], ax
    mov dx, cs
    add dx, ax
    mov [basic_segment], dx
    shl ax, cl
    mov [basic_load_offset], ax

%if GW_BASIC_SPLIT_PAYLOAD
    mov ax, cs
    mov [data_segment], ax
    mov [loader_abi_basic_segment], ax
    mov word [data_load_offset], GW_DAT_ORG
    debug_split_load_stop 20

    ; C688:01E6 returns only the low word in AX, but the real ROM-card work
    ; limit is [7A54] 128-byte blocks.  Convert that count to a byte limit
    ; from 0A4F:0000 and cap DS at 64K.
    mov ax, [rom_work_blocks]
    mov dx, ax
    mov cl, 7
    shl ax, cl
    mov cl, 9
    shr dx, cl
    cmp dx, 1
    ja .full_data_segment
    jb .partial_data_segment
    or ax, ax
    jz .full_data_segment
.partial_data_segment:
    jmp .store_data_stack_top
.full_data_segment:
    xor ax, ax
.store_data_stack_top:
    mov [basic_stack_top], ax
    mov [loader_abi_basic_stack_top], ax
%else
    mov dx, [basic_segment]
    mov [data_segment], dx
    mov [loader_abi_basic_segment], dx
    mov ax, [basic_load_offset]
    mov [data_load_offset], ax

    mov ax, bx
    sub ax, [basic_load_offset]
    jc not_enough_memory
    mov [basic_stack_top], ax
    mov [loader_abi_basic_stack_top], ax
%endif
%else
	    mov ax, cs
	    mov [basic_segment], ax
    mov [data_segment], ax
    mov [loader_abi_basic_segment], ax
    mov word [basic_load_offset], GW_BASIC_LOAD_OFFSET
    mov word [data_load_offset], GW_BASIC_LOAD_OFFSET
	    mov ax, bx
	    mov [basic_stack_top], ax
	    mov [loader_abi_basic_stack_top], ax
%endif
	    mov dx, [basic_segment]
	    mov [basic_entry_segment], dx
    mov ax, [basic_stack_top]
    or ax, ax
    jz .full_segment_limit
	    sub ax, GW_BASIC_STACK_RESERVE
    jc not_enough_memory
    jmp .store_basic_limit
.full_segment_limit:
    mov ax, 0x10000 - GW_BASIC_STACK_RESERVE
.store_basic_limit:
    mov [basic_limit], ax
    mov [loader_abi_limit], ax
    cmp ax, GW_BASIC_REQUIRED_SIZE
    jb not_enough_memory

    mov ax, loading_message
    call print_message
    debug_split_load_stop 21
%if GW_BASIC_SPLIT_PAYLOAD
    debug_split_load_stop 1
    call find_code_image
    debug_split_load_stop 2
    jc load_failed
    mov ax, [code_segment]
    mov [basic_segment], ax
    mov [basic_entry_segment], ax

    mov word [load_path], data_path
    mov word [load_phase], 2
    mov word [load_size], GW_DAT_SIZE
    mov word [load_offset], GW_DAT_ORG
    mov word [expected_prefix], expected_data_prefix
    debug_split_load_stop 3
    call load_current_image
    debug_split_load_stop 4
    jc load_failed
%else
    mov word [load_path], overlay_path
    mov word [load_phase], 0
    mov word [load_size], GW_OVR_SIZE
    mov ax, [basic_load_offset]
    mov [load_offset], ax
    mov word [expected_prefix], expected_overlay_prefix
    call load_current_image
    jc load_failed
%endif
    mov ax, cs
	    mov ds, ax
	    cli
%if GW_BASIC_SPLIT_PAYLOAD
	    mov ax, cs
    mov ds, ax
	    mov es, ax
	    mov ss, ax
	    mov sp, [cs:basic_stack_top]
	    sti
	    jmp far [cs:basic_entry_ptr]
%else
	    mov ax, [basic_segment]
	    mov ds, ax
	    mov es, ax
	    mov ss, ax
	    mov sp, [cs:basic_stack_top]
	    sti
%if GW_BASIC_SEPARATE_SEGMENT
	    jmp far [cs:basic_entry_ptr]
%else
	    jmp GW_INIT
%endif
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

load_failed:
    call print_message_wait
    mov ax, cs
    mov ds, ax
    restore_loader_stack
    retf

%if GW_BASIC_SPLIT_PAYLOAD
find_code_image:
    push ds
    push es
    push si
    push di
    push bx
    push cx
    push dx

    push cs
    pop ds
    mov ax, DW_STORE_SEGMENT
    mov es, ax
    mov ax, [es:0]
    cmp ax, 0x1997
    jne .bad
    mov ax, [es:2]
    cmp ax, 0x0126
    jne .bad
    mov ax, [es:4]
    mov [store_geometry], ax

    ; root = (3 * geometry + 1) * 128
    mov bx, ax
    shl ax, 1
    add ax, bx
    inc ax
    mov cl, 7
    shl ax, cl
    mov di, ax
    mov cx, DW_STORE_ROOT_ENTRIES
.root_loop:
    cmp byte [es:di], 0
    je .not_found
    cmp byte [es:di], 0xe5
    je .next_entry
    push cx
    push di
    mov si, code_raw_name
    mov cx, 11
    cld
    repe cmpsb
    pop di
    pop cx
    je .found
.next_entry:
    add di, DW_STORE_ROOT_ENTRY_SIZE
    loop .root_loop
.not_found:
    mov ax, code_not_found_message
    stc
    jmp .done
.found:
    mov ax, [es:di + 0x1c]
    mov [code_file_size_low], ax
    cmp ax, GW_COD_SIZE
    jne .bad
    mov ax, [es:di + 0x1e]
    mov [code_file_size_high], ax
    or ax, ax
    jnz .bad
    mov ax, [es:di + 0x1a]
    mov [code_first_cluster], ax
    cmp ax, 2
    jb .bad
    call verify_code_chain
    jc .bad
    call compute_code_segment
    call verify_code_prefix_storage
    jc .bad
    clc
    jmp .done
.bad:
    mov ax, code_bad_message
    stc
.done:
    pop dx
    pop cx
    pop bx
    pop di
    pop si
    pop es
    pop ds
    ret

verify_code_chain:
    mov ax, [code_first_cluster]
%if GW_COD_CLUSTERS > 1
    mov cx, GW_COD_CLUSTERS - 1
.chain_loop:
    mov [code_current_cluster], ax
    call get_store_fat12
    mov dx, [code_current_cluster]
    inc dx
    cmp ax, dx
    jne .bad
    loop .chain_loop
%endif
    call get_store_fat12
    cmp ax, 0x0ff8
    jb .bad
    clc
    ret
.bad:
    stc
    ret

compute_code_segment:
    ; segment = 1800h + ((3 * geometry + 1fh + first_cluster) * 8)
    mov ax, [store_geometry]
    mov bx, ax
    shl ax, 1
    add ax, bx
    add ax, 0x001f
    add ax, [code_first_cluster]
    mov cl, 3
    shl ax, cl
    add ax, DW_STORE_SEGMENT
    mov [code_segment], ax
    ret

verify_code_prefix_storage:
    push ds
    push es
    push si
    push di
    push cx
    push cs
    pop ds
    mov ax, [code_segment]
    mov es, ax
    mov si, expected_code_prefix
    xor di, di
    mov cx, 16
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

get_store_fat12:
    push bx
    push dx
    push si
    mov bx, ax
    mov dx, ax
    shr dx, 1
    add dx, bx
    add dx, DW_STORE_FAT_OFFSET
    mov si, dx
    mov ax, [es:si]
    test bl, 1
    jz .even
    shr ax, 4
.even:
    and ax, 0x0fff
    pop si
    pop dx
    pop bx
    ret
%endif

load_current_image:
    call open_overlay
    mov [cs:file_handle], ax
    mov [cs:last_open_handle], ax
    cmp word [cs:load_phase], 1
    jne .not_code_open
    mov [cs:code_file_handle], ax
    jmp .open_handle_saved
.not_code_open:
    cmp word [cs:load_phase], 2
    jne .open_handle_saved
    mov [cs:data_file_handle], ax
.open_handle_saved:
    cmp word [cs:file_handle], 0xffff
    je .open_failed
    debug_split_load_stop 5

    call read_overlay
    debug_split_load_stop 6
    mov [cs:read_count], ax
    cmp ax, [cs:load_size]
    jne .read_failed

    call close_overlay
    debug_split_load_stop 7
    call verify_overlay
    debug_split_load_stop 8
    jc .verify_failed
    clc
    ret
.open_failed:
    mov ax, open_failed_message
    stc
    ret
.read_failed:
    call close_overlay
    mov ax, read_failed_message
    stc
    ret
.verify_failed:
    mov ax, verify_failed_message
    stc
    ret

open_overlay:
    ; DS=CS on entry and exit. The open wrapper consumes DS:offset for the
    ; filename, while the vector table lives in low RAM, so fetch the vector
    ; through ES instead of changing DS.
    push es
    xor ax, ax
    mov es, ax
    push word 0x0000
    push word [load_path]
    debug_split_load_stop 30
    call far [es:0x0244]
    debug_split_load_stop 31
    add sp, 4
    pop es
    ret

read_overlay:
    ; Keep the ROM read wrapper's proven current-segment destination contract:
    ; DS=CS, BX=offset. In separate-segment mode that offset is the paragraph-
    ; aligned loader end; BASIC later sees the same physical bytes through the
    ; corresponding segment:0000 alias.
    push es
    push si
    mov ax, cs
    mov ds, ax
    mov bx, [load_offset]
    mov si, [load_size]
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
    mov [cs:read_call_handle], ax
    mov [cs:read_call_offset], bx
    mov [cs:read_call_count], cx
    push ax
    mov ax, ds
    mov [cs:read_call_segment], ax
    pop ax
    push bx
    push cx
    push si
    push ax
    xor ax, ax
    mov es, ax
    pop ax
    debug_split_load_stop 12
    call far [es:0x0248]
    pushf
    mov [cs:read_return_ax], ax
    pop word [cs:read_return_flags]
    debug_split_load_stop 13
    pop si
    pop cx
    pop bx
    test word [cs:read_return_flags], 0x0001
    jnz .done
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
    push cs
    pop ds
    mov [last_close_status], ax
    cmp word [load_phase], 1
    jne .not_code_close
    mov [code_close_status], ax
    jmp .close_status_saved
.not_code_close:
    cmp word [load_phase], 2
    jne .close_status_saved
    mov [data_close_status], ax
.close_status_saved:
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
    mov si, [expected_prefix]
    mov di, [load_offset]
    mov cx, 16
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
rom_work_blocks:
    dw 0
basic_stack_top:
    dw 0
basic_segment_delta:
    dw 0
basic_segment:
	    dw 0
basic_entry_ptr:
		    dw GW_ENTRY_OFFSET
basic_entry_segment:
	    dw 0
data_segment:
	    dw 0
code_segment:
    dw 0
basic_load_offset:
    dw 0
data_load_offset:
    dw 0
file_handle:
    dw 0
last_open_handle:
    dw 0
last_close_status:
    dw 0
code_file_handle:
    dw 0
code_close_status:
    dw 0
data_file_handle:
    dw 0
data_close_status:
    dw 0
read_count:
    dw 0
load_path:
    dw 0
load_phase:
    dw 0
load_size:
    dw 0
load_offset:
    dw 0
expected_prefix:
    dw 0
read_call_handle:
    dw 0
read_call_segment:
    dw 0
read_call_offset:
    dw 0
read_call_count:
    dw 0
read_return_ax:
    dw 0
read_return_flags:
    dw 0
store_geometry:
    dw 0
code_first_cluster:
    dw 0
code_current_cluster:
    dw 0
code_file_size_low:
    dw 0
code_file_size_high:
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
    db "CAN NOT OPEN DW-BASIC FILE", 13
    db "PRESS KEY TO RETURN", 0
read_failed_message:
    db "CAN NOT READ DW-BASIC FILE", 13
    db "PRESS KEY TO RETURN", 0
code_not_found_message:
    db "CAN NOT FIND DW-BASIC.COD", 13
    db "PRESS KEY TO RETURN", 0
code_bad_message:
    db "BAD DW-BASIC.COD FILE", 13
    db "PRESS KEY TO RETURN", 0
verify_failed_message:
    db "BAD DW-BASIC FILE LOAD", 13
    db "PRESS KEY TO RETURN", 0
verified_message:
    db "DW-BASIC.FLT VERIFIED", 13
    db "PRESS KEY TO START", 0
overlay_path:
    db "H:DW-BASIC.FLT", 0
code_path:
    db "H:DW-BASIC.COD", 0
code_raw_name:
    db "DW-BASICCOD"
data_path:
    db "H:DW-BASIC.DAT", 0
expected_overlay_prefix:
%if !GW_BASIC_SPLIT_PAYLOAD
    incbin "build/DW-BASIC.FLT", 0, 16
%else
    times 16 db 0
%endif
expected_overlay_prefix_end:
expected_code_prefix:
%if GW_BASIC_SPLIT_PAYLOAD
    incbin GW_COD_PREFIX_PATH, 0, 16
%else
    times 16 db 0
%endif
expected_code_prefix_end:
expected_data_prefix:
%if GW_BASIC_SPLIT_PAYLOAD
    incbin GW_DAT_PREFIX_PATH, 0, 16
%else
    times 16 db 0
%endif
expected_data_prefix_end:

loader_end:
LOADER_END_OFFSET equ loader_end - $$
%if GW_BASIC_SEPARATE_SEGMENT
%if GW_BASIC_SPLIT_PAYLOAD
%if LOADER_END_OFFSET > GW_DAT_ORG
%error "EROMCARD.X loader overlaps DW-BASIC.DAT origin"
%endif
%if GW_DAT_ORG + GW_DAT_SIZE > 0x10000
%error "DW-BASIC.DAT crosses segment boundary"
%endif
%else
%if (((LOADER_END_OFFSET + 15) / 16) * 16) + GW_OVR_SIZE > 0x10000
%error "EROMCARD.X loader plus DW-BASIC.FLT crosses segment boundary"
%endif
%endif
%else
%if ($ - $$) > GW_BASIC_LOAD_OFFSET
%error "EROMCARD.X loader overlaps GW-BASIC overlay load offset"
%endif
%endif
