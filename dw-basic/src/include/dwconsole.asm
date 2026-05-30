; Minimal DreamWriter text console over the firmware text vector.
;
; Coordinates are logical 6x8 text cells on the 480x64 LCD.

CONSOLE_CELL_W equ 6
CONSOLE_CELL_H equ 8
CONSOLE_COLS equ 80
CONSOLE_ROWS equ 8
LCD_DEFAULT_FRAMEBUFFER_BASE equ 0x1000
LCD_STRIDE_BYTES equ 64
LCD_VISIBLE_BYTES equ 60

console_clear:
    pushf
    push ax
    push di
    push cx
    push dx
    push es
    push ds
    pop es
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
    pop es
    pop dx
    pop cx
    pop di
    pop ax
    popf
    ret

; DH=row, DL=column.
console_goto:
    mov [console_row], dh
    mov [console_col], dl
    ret

; AX = physical offset of the currently displayed LCD framebuffer.
; The normal T400 menu/boot framebuffer is 0x1000. The BASIC wrapper can select
; another scanout buffer, so direct LCD primitives must consult this runtime
; value rather than embedding the default address.
lcd_set_framebuffer_base:
    mov [lcd_framebuffer_base], ax
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
    jae console_scroll_up
    inc byte [console_row]
    ret

console_scroll_up:
    push ax
    push bx
    push cx
    mov ax, 0x0102
    mov bx, 0x0101
    mov cx, (CONSOLE_COLS << 8) | (CONSOLE_ROWS - 1)
    call SCROLL
    call console_clear_bottom_row
    pop cx
    pop bx
    pop ax
    ret

; GW-BASIC OEM SCROLL primitive.
; AX = source position, AH=column and AL=line, 1-based.
; BX = destination position, BH=column and BL=line, 1-based.
; CX = rectangle size, CH=columns and CL=lines.
; This moves both the shadow text cells and the raw LCD pixels in the matching
; 6x8-cell rectangle. It deliberately does not clear newly exposed cells; the
; generic screen driver does that with CLREOL/SCROUT after calling SCROLL.
SCROLL:
    pushf
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    mov [scroll_src_col], ah
    dec byte [scroll_src_col]
    mov [scroll_src_row], al
    dec byte [scroll_src_row]
    mov [scroll_dst_col], bh
    dec byte [scroll_dst_col]
    mov [scroll_dst_row], bl
    dec byte [scroll_dst_row]
    mov [scroll_cols], ch
    mov [scroll_rows], cl

    or ch, ch
    jz .done
    or cl, cl
    jz .done

    call console_scroll_shadow_rect
    call console_scroll_pixel_rect

.done:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    popf
    ret

; GW-BASIC OEM character output primitive.
; AX = character, DH=1-based column, DL=1-based line.
; Writes one cell without changing the console's current cursor position.
SCROUT:
    push ax
    push bx
    push cx
    push dx
    mov bl, [console_col]
    mov bh, [console_row]
    push bx

    cmp dh, 1
    jb .done
    cmp dh, CONSOLE_COLS
    ja .done
    cmp dl, 1
    jb .done
    cmp dl, CONSOLE_ROWS
    ja .done

    dec dh
    dec dl
    mov [console_col], dh
    mov [console_row], dl

    mov [console_cell], al
    mov byte [console_cell + 1], 0
    call console_buffer_put_at_cursor
    mov ax, console_cell
    call console_draw_at_cursor

.done:
    pop bx
    mov [console_col], bl
    mov [console_row], bh
    pop dx
    pop cx
    pop bx
    pop ax
    clc
    ret

; GW-BASIC OEM screen input primitive.
; DH=1-based column, DL=1-based line. Returns AX=character.
SCRINP:
    push bx
    push dx
    push di
    mov bl, [console_col]
    mov bh, [console_row]
    push bx

    cmp dh, 1
    jb .space
    cmp dh, CONSOLE_COLS
    ja .space
    cmp dl, 1
    jb .space
    cmp dl, CONSOLE_ROWS
    ja .space

    dec dh
    dec dl
    mov [console_col], dh
    mov [console_row], dl
    call console_buffer_get_at_cursor
    xor ah, ah
    jmp .done

.space:
    mov ax, " "

.done:
    pop bx
    mov [console_col], bl
    mov [console_row], bh
    pop di
    pop dx
    pop bx
    ret

; GW-BASIC OEM clear-to-end-of-line primitive.
; DH=1-based start column, DL=1-based line.
CLREOL:
    push ax
    push dx
    cmp dl, 1
    jb .done
    cmp dl, CONSOLE_ROWS
    ja .done
    cmp dh, 1
    jae .check_right
    mov dh, 1
.check_right:
    cmp dh, CONSOLE_COLS
    ja .done
    mov ax, " "
.loop:
    call SCROUT
    cmp dh, CONSOLE_COLS
    jae .done
    inc dh
    jmp .loop
.done:
    pop dx
    pop ax
    ret

%ifndef DWCONSOLE_NO_LOCAL_SETCSR
; GW-BASIC drives cursor state through CSRTYP in its data segment. This
; standalone shim does not have that data segment yet; console_read_line uses
; the local cursor helpers directly for now.
; TODO: Implement this once the port has GW-BASIC's data segment and CSRTYP.
SETCSR:
    ret
%endif

console_scroll_shadow_rect:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    call scroll_source_cell_offset
    mov [scroll_src_offset], di
    call scroll_dest_cell_offset
    mov [scroll_dst_offset], di

    mov ax, [scroll_dst_offset]
    cmp ax, [scroll_src_offset]
    ja .backward

.forward:
    mov byte [scroll_work_row], 0
.forward_row:
    mov al, [scroll_work_row]
    cmp al, [scroll_rows]
    jae .done
    mov byte [scroll_work_col], 0
.forward_col:
    mov al, [scroll_work_col]
    cmp al, [scroll_cols]
    jae .forward_next_row
    call scroll_copy_shadow_cell
    inc byte [scroll_work_col]
    jmp .forward_col
.forward_next_row:
    inc byte [scroll_work_row]
    jmp .forward_row

.backward:
    mov al, [scroll_rows]
    mov [scroll_work_row], al
.backward_row:
    cmp byte [scroll_work_row], 0
    je .done
    dec byte [scroll_work_row]
    mov al, [scroll_cols]
    mov [scroll_work_col], al
.backward_col:
    cmp byte [scroll_work_col], 0
    je .backward_row
    dec byte [scroll_work_col]
    call scroll_copy_shadow_cell
    jmp .backward_col

.done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

scroll_copy_shadow_cell:
    call scroll_source_cell_offset
    mov al, [console_text_buffer + di]
    mov dl, al
    call scroll_dest_cell_offset
    mov [console_text_buffer + di], dl
    ret

scroll_source_cell_offset:
    mov al, [scroll_src_row]
    add al, [scroll_work_row]
    mov bl, CONSOLE_COLS
    mul bl
    mov bl, [scroll_src_col]
    add bl, [scroll_work_col]
    xor bh, bh
    add ax, bx
    mov di, ax
    ret

scroll_dest_cell_offset:
    mov al, [scroll_dst_row]
    add al, [scroll_work_row]
    mov bl, CONSOLE_COLS
    mul bl
    mov bl, [scroll_dst_col]
    add bl, [scroll_work_col]
    xor bh, bh
    add ax, bx
    mov di, ax
    ret

console_scroll_pixel_rect:
    push ax
    push bx
    push cx
    push dx
    push es

    call scroll_prepare_pixel_rect
    mov ax, [scroll_src_pixel_x]
    test al, 7
    jnz .bit_rect
    mov ax, [scroll_dst_pixel_x]
    test al, 7
    jnz .bit_rect
    mov ax, [scroll_pixel_width]
    test al, 7
    jnz .bit_rect
    call scroll_byte_rect
    jmp .done

.bit_rect:
    ; Future optimization: when source and destination columns differ by a
    ; multiple of four cells, their 6-pixel cell origins have the same bit
    ; alignment. That can copy whole middle bytes with masked edge bytes instead
    ; of falling all the way back to per-pixel movement.
    mov ax, [scroll_dst_pixel_y]
    cmp ax, [scroll_src_pixel_y]
    ja .backward
    jb .forward
    mov ax, [scroll_dst_pixel_x]
    cmp ax, [scroll_src_pixel_x]
    ja .backward

.forward:
    xor ax, ax
    mov es, ax
    mov word [scroll_work_y], 0
.forward_y:
    mov ax, [scroll_work_y]
    cmp ax, [scroll_pixel_height]
    jae .done
    mov word [scroll_work_x], 0
.forward_x:
    mov ax, [scroll_work_x]
    cmp ax, [scroll_pixel_width]
    jae .forward_next_y
    call scroll_copy_pixel
    inc word [scroll_work_x]
    jmp .forward_x
.forward_next_y:
    inc word [scroll_work_y]
    jmp .forward_y

.backward:
    xor ax, ax
    mov es, ax
    mov ax, [scroll_pixel_height]
    mov [scroll_work_y], ax
.backward_y:
    cmp word [scroll_work_y], 0
    je .done
    dec word [scroll_work_y]
    mov ax, [scroll_pixel_width]
    mov [scroll_work_x], ax
.backward_x:
    cmp word [scroll_work_x], 0
    je .backward_y
    dec word [scroll_work_x]
    call scroll_copy_pixel
    jmp .backward_x

.done:
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Fast path for byte-aligned rectangles. This is used for full-width vertical
; text scrolls and any 6x8-cell rectangle whose x/width happen to land on byte
; boundaries. Unaligned rectangles fall back to the bit-level path above.
scroll_byte_rect:
    pushf
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    xor ax, ax
    mov es, ax

    mov ax, [scroll_dst_pixel_y]
    cmp ax, [scroll_src_pixel_y]
    ja .backward
    jb .forward
    mov ax, [scroll_dst_pixel_x]
    cmp ax, [scroll_src_pixel_x]
    ja .backward

.forward:
    cld
    mov ax, [scroll_src_pixel_y]
    shl ax, 6
    mov si, ax
    mov ax, [scroll_src_pixel_x]
    shr ax, 3
    add si, ax
    add si, [lcd_framebuffer_base]

    mov ax, [scroll_dst_pixel_y]
    shl ax, 6
    mov di, ax
    mov ax, [scroll_dst_pixel_x]
    shr ax, 3
    add di, ax
    add di, [lcd_framebuffer_base]

    mov ax, [scroll_pixel_width]
    shr ax, 3
    mov [scroll_byte_width], ax
    mov bx, [scroll_pixel_height]
.forward_line:
    mov cx, [scroll_byte_width]
    shr cx, 1
    es rep movsw
    jnc .forward_even
    es movsb
.forward_even:
    mov ax, LCD_STRIDE_BYTES
    sub ax, [scroll_byte_width]
    add si, ax
    add di, ax
    dec bx
    jnz .forward_line
    jmp .done

.backward:
    std
    mov ax, [scroll_pixel_width]
    shr ax, 3
    mov [scroll_byte_width], ax

    mov ax, [scroll_src_pixel_y]
    add ax, [scroll_pixel_height]
    dec ax
    shl ax, 6
    mov si, ax
    mov ax, [scroll_src_pixel_x]
    shr ax, 3
    add ax, [scroll_byte_width]
    dec ax
    add si, ax
    add si, [lcd_framebuffer_base]

    mov ax, [scroll_dst_pixel_y]
    add ax, [scroll_pixel_height]
    dec ax
    shl ax, 6
    mov di, ax
    mov ax, [scroll_dst_pixel_x]
    shr ax, 3
    add ax, [scroll_byte_width]
    dec ax
    add di, ax
    add di, [lcd_framebuffer_base]

    mov bx, [scroll_pixel_height]
.backward_line:
    mov cx, [scroll_byte_width]
    es rep movsb
    mov ax, [scroll_byte_width]
    sub ax, LCD_STRIDE_BYTES
    add si, ax
    add di, ax
    dec bx
    jnz .backward_line

.done:
    cld
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    popf
    ret

scroll_prepare_pixel_rect:
    mov al, [scroll_src_col]
    xor ah, ah
    mov bx, ax
    shl ax, 1
    shl bx, 2
    add ax, bx
    mov [scroll_src_pixel_x], ax

    mov al, [scroll_dst_col]
    xor ah, ah
    mov bx, ax
    shl ax, 1
    shl bx, 2
    add ax, bx
    mov [scroll_dst_pixel_x], ax

    mov al, [scroll_cols]
    xor ah, ah
    mov bx, ax
    shl ax, 1
    shl bx, 2
    add ax, bx
    mov [scroll_pixel_width], ax

    mov al, [scroll_src_row]
    xor ah, ah
    shl ax, 3
    mov [scroll_src_pixel_y], ax

    mov al, [scroll_dst_row]
    xor ah, ah
    shl ax, 3
    mov [scroll_dst_pixel_y], ax

    mov al, [scroll_rows]
    xor ah, ah
    shl ax, 3
    mov [scroll_pixel_height], ax
    ret

scroll_copy_pixel:
    mov cx, [scroll_src_pixel_x]
    add cx, [scroll_work_x]
    mov dx, [scroll_src_pixel_y]
    add dx, [scroll_work_y]
    call lcd_get_pixel
    mov cx, [scroll_dst_pixel_x]
    add cx, [scroll_work_x]
    mov dx, [scroll_dst_pixel_y]
    add dx, [scroll_work_y]
    call lcd_put_pixel
    ret

lcd_get_pixel:
    push bx
    push cx
    push dx
    push si
    mov bx, dx
    shl bx, 6
    mov dx, cx
    shr dx, 3
    add bx, dx
    add bx, [lcd_framebuffer_base]
    mov si, pixel_masks
    and cl, 7
    xor ch, ch
    add si, cx
    mov ah, [si]
    mov al, [es:bx]
    and al, ah
    jz .zero
    mov al, 1
    jmp .done
.zero:
    xor al, al
.done:
    pop si
    pop dx
    pop cx
    pop bx
    ret

lcd_put_pixel:
    push bx
    push cx
    push dx
    push si
    mov [scroll_pixel_value], al
    mov bx, dx
    shl bx, 6
    mov dx, cx
    shr dx, 3
    add bx, dx
    add bx, [lcd_framebuffer_base]
    mov si, pixel_masks
    and cl, 7
    xor ch, ch
    add si, cx
    mov ah, [si]
    cmp byte [scroll_pixel_value], 0
    je .clear
    or [es:bx], ah
    jmp .done
.clear:
    not ah
    and [es:bx], ah
.done:
    pop si
    pop dx
    pop cx
    pop bx
    ret

console_clear_bottom_row:
    pushf
    push ax
    push bx
    push cx
    push di
    push es
    push ds
    pop es
    cld
    mov di, console_text_buffer + (CONSOLE_COLS * (CONSOLE_ROWS - 1))
    mov cx, CONSOLE_COLS
    mov al, " "
    rep stosb
    pop es

    push es
    xor ax, ax
    mov es, ax
    mov di, [lcd_framebuffer_base]
    add di, LCD_STRIDE_BYTES * CONSOLE_CELL_H * (CONSOLE_ROWS - 1)
    xor ax, ax
    mov bx, CONSOLE_CELL_H
.clear_scanline:
    mov cx, LCD_VISIBLE_BYTES / 2
    rep stosw
    add di, LCD_STRIDE_BYTES - LCD_VISIBLE_BYTES
    dec bx
    jnz .clear_scanline
    pop es

    pop di
    pop cx
    pop bx
    pop ax
    popf
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
lcd_framebuffer_base:
    dw LCD_DEFAULT_FRAMEBUFFER_BASE
pixel_masks:
    db 0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01
scroll_src_col:
    db 0
scroll_src_row:
    db 0
scroll_dst_col:
    db 0
scroll_dst_row:
    db 0
scroll_cols:
    db 0
scroll_rows:
    db 0
scroll_work_col:
    db 0
scroll_work_row:
    db 0
scroll_src_offset:
    dw 0
scroll_dst_offset:
    dw 0
scroll_src_pixel_x:
    dw 0
scroll_src_pixel_y:
    dw 0
scroll_dst_pixel_x:
    dw 0
scroll_dst_pixel_y:
    dw 0
scroll_pixel_width:
    dw 0
scroll_pixel_height:
    dw 0
scroll_work_x:
    dw 0
scroll_work_y:
    dw 0
scroll_pixel_value:
    db 0
scroll_byte_width:
    dw 0
console_text_buffer:
    times CONSOLE_COLS * CONSOLE_ROWS db " "
