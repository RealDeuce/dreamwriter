bits 16
org 0

%ifndef DW_ROMCARD_PROFILE
%define DW_ROMCARD_PROFILE 21
%endif

%if DW_ROMCARD_PROFILE = 21
DW_ROMCARD_HEADER_OFFSET equ 0
DW_ROMCARD_HEADER_WORD0 equ 0xA4F0
DW_ROMCARD_HEADER_WORD1 equ 0x1997
DW_ROMCARD_ENTRY_SEGMENT equ 0x0A4F
%elif DW_ROMCARD_PROFILE = 31
DW_ROMCARD_HEADER_OFFSET equ 0
DW_ROMCARD_HEADER_WORD0 equ 0x1210
DW_ROMCARD_HEADER_WORD1 equ 0x1992
DW_ROMCARD_ENTRY_SEGMENT equ 0x09C0
%elif DW_ROMCARD_PROFILE = 100
DW_ROMCARD_HEADER_OFFSET equ 0
DW_ROMCARD_HEADER_WORD0 equ 0xCA00
DW_ROMCARD_HEADER_WORD1 equ 0x1997
DW_ROMCARD_ENTRY_SEGMENT equ 0x0CA0
%elif DW_ROMCARD_PROFILE = 31260
DW_ROMCARD_VECTOR_OFFSET equ 0x2514
DW_ROMCARD_ENTRY_SEGMENT equ 0x0A4F
%define DW_ROMCARD_HAS_VECTOR 1
%else
%error "DW_ROMCARD_PROFILE must be 21, 31, 100, or 31260"
%endif

%ifdef DW_ROMCARD_HAS_VECTOR
    times DW_ROMCARD_VECTOR_OFFSET - ($ - $$) db 0

; T400 v3.1/v3.1.260 executable vector. The loader reads to physical 0x0A4F0
; and calls the far pointer at loaded address 0x0CA04, i.e. file offset 0x2514.
    dw entry
    dw DW_ROMCARD_ENTRY_SEGMENT
%else
%if DW_ROMCARD_HEADER_OFFSET > 0
    times DW_ROMCARD_HEADER_OFFSET - ($ - $$) db 0
%endif

; DreamWriter ROM CARD executable header.
    dw DW_ROMCARD_HEADER_WORD0
    dw DW_ROMCARD_HEADER_WORD1
    dw entry
    dw DW_ROMCARD_ENTRY_SEGMENT
%endif

entry:
    mov [cs:launch_ax], ax
    mov ax, ds
    mov [cs:entry_ds], ax
    mov ax, es
    mov [cs:entry_es], ax

    mov bx, ax
    mov [cs:work_bytes_low], ax
    xor ax, ax
    mov [cs:work_bytes_high], ax
    mov ax, bx
    mov cl, 7
    shr ax, cl
    mov [cs:work_blocks], ax

    push cs
    pop ds
    call fill_values
    call show_screen
    call wait_for_space
    mov ax, [cs:entry_es]
    mov es, ax
    mov dx, [cs:entry_ds]
    xor ax, ax
    mov ds, dx
    retf

fill_values:
    mov ax, [launch_ax]
    mov di, launch_ax_value
    call write_hex_word

    mov ax, [entry_ds]
    mov di, entry_ds_value
    call write_hex_word

    mov ax, [work_blocks]
    mov di, blocks_value
    call write_hex_word

    mov ax, [work_bytes_high]
    mov di, bytes_value
    call write_hex_word
    mov ax, [work_bytes_low]
    mov di, bytes_value + 4
    call write_hex_word
    ret

show_screen:
    xor cx, cx
    xor dx, dx
    mov ax, title
    call dw_puts_cs
    mov dx, 8
    mov ax, launch_line
    call dw_puts_cs
    mov dx, 16
    mov ax, blocks_line
    call dw_puts_cs
    mov dx, 24
    mov ax, bytes_line
    call dw_puts_cs
    mov dx, 32
    mov ax, prompt
    call dw_puts_cs
    ret

wait_for_space:
    call dw_getkey
    cmp al, " "
    jne wait_for_space
    ret

; AX = word, DS:DI = four ASCII hex digits. Advances DI.
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

%include "dwapi.asm"

launch_ax:
    dw 0
entry_ds:
    dw 0
entry_es:
    dw 0
work_blocks:
    dw 0
work_bytes_low:
    dw 0
work_bytes_high:
    dw 0

title:
    db "ROM CARD MEMORY", 0
launch_line:
    db "AX="
launch_ax_value:
    db "0000"
    db " DS="
entry_ds_value:
    db "0000", 0
blocks_line:
    db "AX/80="
blocks_value:
    db "0000"
    db " BLOCKS", 0
bytes_line:
    db "BYTES=$"
bytes_value:
    db "00000000", 0
prompt:
    db "PRESS SPACE TO RETURN", 0
