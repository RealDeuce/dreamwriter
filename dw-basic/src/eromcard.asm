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
    call scroll_text_demo
    call scroll_graphics_demo
    call oem_primitive_demo
    call keyinp_demo

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

scroll_text_demo:
    call console_clear
    mov ax, text_scroll_lines
    mov dx, 0x0000
    call console_goto
    call console_puts
    call dw_getkey
    ret

scroll_graphics_demo:
    call console_clear
    mov ax, graphics_title
    mov dx, 0x0000
    call console_goto
    call console_puts

    call draw_source_box
    mov ax, 0x0302
    mov bx, 0x1905
    mov cx, (10 << 8) | 2
    call SCROLL

    mov ax, graphics_prompt
    mov dx, 0x0700
    call console_goto
    call console_puts
    call dw_getkey
    ret

oem_primitive_demo:
    call console_clear
    mov ax, oem_title
    mov dx, 0x0000
    call console_goto
    call console_puts

    mov ax, oem_scroute_text
    mov dx, 0x0304
    call oem_puts_at

    mov dh, 5
    mov dl, 4
    call SCRINP
    cmp al, "S"
    jne .scrinp_fail
    mov ax, oem_scrinp_ok
    jmp .show_scrinp
.scrinp_fail:
    mov ax, oem_scrinp_fail
.show_scrinp:
    mov dx, 0x0404
    call oem_puts_at

    mov ax, oem_clreol_text
    mov dx, 0x0504
    call oem_puts_at
    mov dh, 25
    mov dl, 6
    call CLREOL

    mov ax, oem_prompt
    mov dx, 0x0700
    call console_goto
    call console_puts
    call dw_getkey
    ret

; AX = CS-relative string, DH=row, DL=zero-based column.
oem_puts_at:
    push ax
    push dx
    push si
    mov si, ax
    mov al, dh
    mov dh, dl
    inc dh
    mov dl, al
    inc dl
.loop:
    lodsb
    test al, al
    jz .done
    xor ah, ah
    call SCROUT
    inc dh
    jmp .loop
.done:
    pop si
    pop dx
    pop ax
    ret

keyinp_demo:
    call console_clear
    mov ax, keyinp_title
    mov dx, 0x0000
    call console_goto
    call console_puts

.wait_key:
    call KEYINP
    jz .wait_key
    pushf
    mov [keyinp_ax], ax
    pop ax
    mov [keyinp_flags], ax

    mov ax, keyinp_result
    mov dx, 0x0200
    call console_goto
    call console_puts

    mov ax, [keyinp_ax]
    mov di, keyinp_ax_hex
    call word_to_hex

    mov ax, [keyinp_flags]
    test ax, 1
    jz .carry_clear
    mov byte [keyinp_cf_char], "1"
    jmp .show_result
.carry_clear:
    mov byte [keyinp_cf_char], "0"
.show_result:
    mov ax, keyinp_result_line
    mov dx, 0x0300
    call console_goto
    call console_puts

    mov ax, keyinp_prompt
    mov dx, 0x0700
    call console_goto
    call console_puts
    call dw_getkey
    ret

; AX = value, DI = four-byte ASCII destination.
word_to_hex:
    push ax
    mov al, ah
    call byte_to_hex
    pop ax
    call byte_to_hex
    ret

; AL = value, DI = two-byte ASCII destination.
byte_to_hex:
    push ax
    mov ah, al
    shr al, 4
    call nibble_to_hex
    mov al, ah
    and al, 0x0f
    call nibble_to_hex
    pop ax
    ret

nibble_to_hex:
    cmp al, 10
    jb .digit
    add al, "A" - 10
    jmp .store
.digit:
    add al, "0"
.store:
    stosb
    ret

draw_source_box:
    push ax
    push cx
    push dx
    push es
    xor ax, ax
    mov es, ax

    mov dx, 8
    mov cx, 12
.top:
    mov al, 1
    call lcd_put_pixel
    inc cx
    cmp cx, 72
    jb .top

    mov dx, 23
    mov cx, 12
.bottom:
    mov al, 1
    call lcd_put_pixel
    inc cx
    cmp cx, 72
    jb .bottom

    mov cx, 12
    mov dx, 8
.left:
    mov al, 1
    call lcd_put_pixel
    inc dx
    cmp dx, 24
    jb .left

    mov cx, 71
    mov dx, 8
.right:
    mov al, 1
    call lcd_put_pixel
    inc dx
    cmp dx, 24
    jb .right

    pop es
    pop dx
    pop cx
    pop ax
    ret

LINE_BUFFER_MAX equ 78

text_scroll_lines:
    db "LINE 01 SHOULD SCROLL OFF", 13
    db "LINE 02 SHOULD SCROLL OFF", 13
    db "LINE 03 SHOULD BE TOP", 13
    db "LINE 04", 13
    db "LINE 05", 13
    db "LINE 06", 13
    db "LINE 07", 13
    db "LINE 08", 13
    db "LINE 09", 13
    db "LINE 10 - PRESS KEY", 0
graphics_title:
    db "GRAPHICS SCROLL: BOX SHOULD ALSO APPEAR LOWER RIGHT", 0
graphics_prompt:
    db "TWO BOXES VISIBLE - PRESS KEY", 0
oem_title:
    db "OEM PRIMITIVES", 0
oem_scroute_text:
    db "SCROUT WROTE THIS", 0
oem_scrinp_ok:
    db "SCRINP OK", 0
oem_scrinp_fail:
    db "SCRINP FAIL", 0
oem_clreol_text:
    db "CLREOL KEEPS THIS | ERASED TEXT", 0
oem_prompt:
    db "SCROUT/SCRINP/CLREOL - PRESS KEY", 0
keyinp_title:
    db "KEYINP TEST - PRESS A KEY", 0
keyinp_result:
    db "KEYINP RETURNED", 0
keyinp_result_line:
    db "AX="
keyinp_ax_hex:
    db "0000 CF="
keyinp_cf_char:
    db "0", 0
keyinp_prompt:
    db "PRESS KEY TO CONTINUE", 0
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
keyinp_ax:
    dw 0
keyinp_flags:
    dw 0

%include "src/gw/dwio.asm"

%ifdef EROMCARD_PAD_SIZE
times EROMCARD_PAD_SIZE - ($ - $$) db 0
%endif
