bits 16
org 0

%ifndef SPLIT_SPIKE_COD_SEG
SPLIT_SPIKE_COD_SEG equ 0x19C0
%endif
%ifndef SPLIT_SPIKE_DAT_ORG
SPLIT_SPIKE_DAT_ORG equ 0x1000
%endif
%ifndef SPLIT_SPIKE_DAT_SIZE
%error "SPLIT_SPIKE_DAT_SIZE must be defined"
%endif
%ifndef SPLIT_SPIKE_PAD_SIZE
SPLIT_SPIKE_PAD_SIZE equ 1024
%endif

SPLIT_SPIKE_READ_CHUNK equ 0x0200

; DreamWriter ROM CARD executable header.
    dw 0xA4F0
    dw 0x1997
    dw entry
    dw 0x0A4F

entry:
    mov [cs:old_ds], ds
    mov [cs:old_es], es

    push cs
    pop ds
    call load_dat
    jc load_failed

    push cs
    pop ds
    push cs
    pop es
    call SPLIT_SPIKE_COD_SEG:0

return_to_rom:
    push cs
    pop ds
    mov ax, [old_es]
    mov es, ax
    mov ax, [old_ds]
    mov ds, ax
    retf

load_failed:
    call print_message_wait
    jmp return_to_rom

load_dat:
    call open_dat
    mov [cs:file_handle], ax
    cmp word [cs:file_handle], 0xffff
    je .open_failed

    call read_dat
    mov [cs:read_count], ax
    cmp ax, SPLIT_SPIKE_DAT_SIZE
    jne .read_failed

    call close_dat
    clc
    ret
.open_failed:
    mov ax, open_failed_message
    stc
    ret
.read_failed:
    call close_dat
    mov ax, read_failed_message
    stc
    ret

open_dat:
    push es
    xor ax, ax
    mov es, ax
    push word 0x0000
    push word data_path
    call far [es:0x0244]
    add sp, 4
    pop es
    ret

read_dat:
    push es
    push si
    push cs
    pop ds
    mov bx, SPLIT_SPIKE_DAT_ORG
    mov si, SPLIT_SPIKE_DAT_SIZE
    mov word [read_count], 0
.loop:
    or si, si
    jz .done
    mov cx, SPLIT_SPIKE_READ_CHUNK
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

close_dat:
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

; AX = CS-relative NUL-terminated string.
print_message_wait:
    xor cx, cx
    xor dx, dx
    call dw_puts_cs_raw
.wait:
    call dw_getkey
    cmp al, " "
    jne .wait
    ret

%include "dwapi.asm"

old_ds:
    dw 0
old_es:
    dw 0
file_handle:
    dw 0
read_count:
    dw 0

data_path:
    db "H:SPIKE.DAT", 0
open_failed_message:
    db "SPLIT SPIKE DAT OPEN BAD", 0
read_failed_message:
    db "SPLIT SPIKE DAT READ BAD", 0

%if ($ - $$) > SPLIT_SPIKE_PAD_SIZE
%error "split spike loader exceeds SPLIT_SPIKE_PAD_SIZE"
%endif
    times SPLIT_SPIKE_PAD_SIZE - ($ - $$) db 0
