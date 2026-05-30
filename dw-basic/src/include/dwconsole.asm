; Minimal DreamWriter text console over the firmware text vector.
;
; Coordinates are logical 6x8 text cells on the 480x64 LCD.

CONSOLE_CELL_W equ 6
CONSOLE_CELL_H equ 8
CONSOLE_COLS equ 80
CONSOLE_ROWS equ 8

console_clear:
    push ax
    push di
    push cx
    push dx
    mov di, console_text_buffer
    mov cx, CONSOLE_COLS * CONSOLE_ROWS
    mov al, " "
    rep stosb
    xor dx, dx
.loop:
    mov ax, console_blank_line
    xor cx, cx
    call dw_puts_cs
    add dx, CONSOLE_CELL_H
    cmp dx, CONSOLE_ROWS * CONSOLE_CELL_H
    jb .loop
    mov byte [console_col], 0
    mov byte [console_row], 0
    mov byte [console_cursor_visible], 0
    pop dx
    pop cx
    pop di
    pop ax
    ret

; DH=row, DL=column.
console_goto:
    mov [console_row], dh
    mov [console_col], dl
    ret

console_show_cursor:
    cmp byte [console_cursor_visible], 0
    je .draw
    call console_hide_cursor
.draw:
    cmp byte [console_row], CONSOLE_ROWS
    jae .done
    push ax
    push cx
    push dx
    mov al, [console_col]
    mov [console_cursor_logical_col], al
    mov al, [console_row]
    mov [console_cursor_logical_row], al
    call console_cursor_display_xy
    mov [console_cursor_col], dl
    mov [console_cursor_row], dh
    call console_buffer_get_at_cursor
    mov [console_cursor_saved_char], al
    mov [console_cursor_cell + 1], al
    mov ax, console_cursor_cell
    call console_draw_at_cursor
    mov byte [console_cursor_visible], 1
    pop dx
    pop cx
    pop ax
.done:
    ret

console_hide_cursor:
    cmp byte [console_cursor_visible], 0
    je .done
    push ax
    push cx
    push dx
    mov al, [console_col]
    push ax
    mov al, [console_row]
    push ax
    mov al, [console_cursor_logical_col]
    mov [console_col], al
    mov al, [console_cursor_logical_row]
    mov [console_row], al
    mov al, [console_cursor_saved_char]
    mov [console_cell], al
    mov byte [console_cell + 1], 0
    call console_cursor_display_xy
    mov ax, console_cell
    call console_draw_at_cursor
    mov byte [console_cursor_visible], 0
    pop ax
    mov [console_row], al
    pop ax
    mov [console_col], al
    pop dx
    pop cx
    pop ax
.done:
    ret

; AX = CS-relative NUL-terminated string.
console_puts:
    push ax
    push si
    mov si, ax
.loop:
    lodsb
    test al, al
    jz .done
    call console_putc
    jmp .loop
.done:
    pop si
    pop ax
    ret

; AL = character. Handles CR/LF and printable byte output.
console_putc:
    cmp al, 0x0d
    je console_newline
    cmp al, 0x0a
    je console_newline
    cmp al, 0x20
    jb .done

    cmp byte [console_col], CONSOLE_COLS
    jb .draw
    call console_newline

.draw:
    push ax
    push cx
    push dx
    mov [console_cell], al
    mov byte [console_cell + 1], 0
    call console_buffer_put_at_cursor
    mov ax, console_cell
    call console_draw_at_cursor
    pop dx
    pop cx
    pop ax

    inc byte [console_col]
.done:
    ret

console_newline:
    mov byte [console_col], 0
    cmp byte [console_row], CONSOLE_ROWS - 1
    jae .done
    inc byte [console_row]
.done:
    ret

console_backspace:
    cmp byte [console_col], 0
    jne .same_row
    cmp byte [console_row], 0
    je .done
    dec byte [console_row]
    mov byte [console_col], CONSOLE_COLS - 1
    jmp .erase

.same_row:
    dec byte [console_col]

.erase:
    call console_erase_cell
.done:
    ret

console_erase_cell:
    push ax
    push cx
    push dx
    mov al, " "
    mov [console_cell], al
    mov byte [console_cell + 1], 0
    call console_buffer_put_at_cursor
    mov ax, console_space_cell
    call console_draw_at_cursor
    pop dx
    pop cx
    pop ax
    ret

; DI = destination buffer, CL = maximum printable bytes.
; Returns AL=0 for accepted line, AL=1 for cancel.
console_read_line:
    push bx
    push cx
    push di
    push si
    mov si, di
    xor ch, ch
    mov byte [di], 0
    mov al, [console_col]
    mov [console_line_start_col], al
    mov al, [console_row]
    mov [console_line_start_row], al
    call console_show_cursor

.next_key:
    call dw_getkey
    cmp al, 0xda
    je .accept
    cmp al, 0x0d
    je .accept
    cmp al, 0x1b
    je .cancel
    cmp al, 0x08
    je .backspace
    cmp al, 0x7f
    je .backspace
    cmp al, 0x20
    jb .next_key
    cmp al, 0x7e
    ja .next_key

    cmp ch, cl
    jae .next_key
    call console_hide_cursor
    mov [di], al
    inc di
    inc ch
    mov byte [di], 0
    call console_putc
    call console_show_cursor
    jmp .next_key

.backspace:
    test ch, ch
    jz .next_key
    call console_hide_cursor
    dec di
    dec ch
    mov byte [di], 0
    mov al, ch
    call console_line_goto_offset
    call console_erase_cell
    call console_show_cursor
    jmp .next_key

.cancel:
    call console_hide_cursor
    mov byte [si], 0
    mov al, 1
    jmp .done

.accept:
    call console_hide_cursor
    xor al, al

.done:
    pop si
    pop di
    pop cx
    pop bx
    ret

; Move to input-line-relative character offset AL.
console_line_goto_offset:
    push ax
    push bx
    push dx
    xor ah, ah
    mov bl, [console_line_start_col]
    xor bh, bh
    add ax, bx
    mov bl, CONSOLE_COLS
    div bl
    mov dl, ah
    add al, [console_line_start_row]
    mov dh, al
    call console_goto
    pop dx
    pop bx
    pop ax
    ret

; AX = CS-relative NUL-terminated string to draw at current cursor cell.
console_draw_at_cursor:
    push cx
    push dx
    call console_cell_xy
    call dw_puts_cs
    pop dx
    pop cx
    ret

; Return cursor display cell in DH=row, DL=column.
; A logical column of 80 is the one-past-right-edge state; render it by
; sticking to the last visible cell.
console_cursor_display_xy:
    mov dl, [console_col]
    mov dh, [console_row]
    cmp dl, CONSOLE_COLS
    jb .col_ok
    mov dl, CONSOLE_COLS - 1
.col_ok:
    cmp dh, CONSOLE_ROWS
    jb .row_ok
    mov dh, CONSOLE_ROWS - 1
.row_ok:
    ret

console_buffer_put_at_cursor:
    push ax
    push bx
    push di
    mov bl, al
    call console_buffer_offset_at_cursor
    mov [console_text_buffer + di], bl
    pop di
    pop bx
    pop ax
    ret

console_buffer_get_at_cursor:
    push di
    call console_buffer_offset_at_cursor
    mov al, [console_text_buffer + di]
    pop di
    ret

console_buffer_offset_at_cursor:
    push ax
    push bx
    call console_cursor_display_xy
    mov al, dh
    xor ah, ah
    mov bl, CONSOLE_COLS
    mul bl
    mov bl, dl
    xor bh, bh
    add ax, bx
    mov di, ax
    pop bx
    pop ax
    ret

; Convert current logical cursor to firmware pixel coordinates.
; Returns CX=x, DX=y.
console_cell_xy:
    push ax
    call console_cursor_display_xy
    mov al, dl
    xor ah, ah
    mov cx, ax
    shl ax, 1
    shl cx, 2
    add cx, ax

    mov al, dh
    xor ah, ah
    shl ax, 3
    mov dx, ax
    pop ax
    ret

console_col:
    db 0
console_row:
    db 0
console_line_start_col:
    db 0
console_line_start_row:
    db 0
console_cursor_visible:
    db 0
console_cursor_col:
    db 0
console_cursor_row:
    db 0
console_cursor_logical_col:
    db 0
console_cursor_logical_row:
    db 0
console_cursor_saved_char:
    db " "
console_cell:
    db 0, 0
console_space_cell:
    db " ", 0
console_cursor_cell:
    db 0xf2, " ", 0xf3, 0
console_blank_line:
    times CONSOLE_COLS db " "
    db 0
console_text_buffer:
    times CONSOLE_COLS * CONSOLE_ROWS db " "
