bits 16
org 0

; DreamWriter ROM CARD executable header.
; The T400 loader reads EROMCARD.X to physical 0x0A4F0, checks these words,
; and calls the far pointer at +4.
    dw 0xA4F0
    dw 0x1997
    dw entry
    dw 0x0A4F

entry:
    push ds
    push cs
    pop ds

    call app_main
    pop ds
    retf

app_main:
    call console_clear

    mov ax, title
    mov dx, 0x0000
    call console_goto
    call console_puts

    mov ax, prompt
    mov dx, 0x0200
    call console_goto
    call console_puts

    mov di, line_buffer
    mov cl, LINE_BUFFER_MAX
    call console_read_line
    test al, al
    jnz .cancelled

    mov ax, result_label
    mov dx, 0x0500
    call console_goto
    call console_puts

    mov ax, line_buffer
    mov dx, 0x050c
    call console_goto
    call console_puts
    jmp .return_prompt

.cancelled:
    mov ax, cancel_message
    mov dx, 0x0500
    call console_goto
    call console_puts

.return_prompt:
    mov ax, return_prompt
    mov dx, 0x0700
    call console_goto
    call console_puts

    call dw_getkey
    ret

LINE_BUFFER_MAX equ 78

title:
    db "DW-BASIC BRINGUP", 0
prompt:
input_prefix:
    db "> ", 0
result_label:
    db "LINE:", 0
return_prompt:
    db "PRESS KEY TO RETURN", 0
cancel_message:
    db "CANCELLED", 0
line_buffer:
    times LINE_BUFFER_MAX + 1 db 0

%include "src/include/dwapi.asm"
%include "src/include/dwconsole.asm"
