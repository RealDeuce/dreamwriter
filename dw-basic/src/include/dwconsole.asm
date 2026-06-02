; Minimal DreamWriter text console over the firmware text vector.
;
; Coordinates are logical 6x8 text cells. Most models expose a 480x64 LCD
; (80x8 cells), while wider ROM support also identifies 480x128 displays
; (80x16 cells) through the low-RAM display-info vector.

CONSOLE_CELL_W equ 6
CONSOLE_CELL_H equ 8
CONSOLE_COLS equ 80
CONSOLE_DEFAULT_ROWS equ 8
CONSOLE_MAX_ROWS equ 16
LCD_DEFAULT_FRAMEBUFFER_BASE equ 0x1000
LCD_STRIDE_BYTES equ 64
LCD_VISIBLE_BYTES equ 60

CONSOLE_ATTR_UNDERLINE equ 0x01
CONSOLE_ATTR_BOLD equ 0x08
CONSOLE_ATTR_INVERSE equ 0x70
CONSOLE_ATTR_SMALL equ 0x80
CONSOLE_ATTR_DEFAULT equ 0x07

console_clear:
    pushf
    push ax
    push bx
    push di
    push cx
    push dx
    push es
    push ds
    pop es
    mov di, console_text_buffer
    mov al, [console_rows]
    xor ah, ah
    mov bl, CONSOLE_COLS
    mul bl
    mov cx, ax
    mov ax, (CONSOLE_ATTR_DEFAULT << 8) | " "
    cld
    rep stosw

    xor dx, dx
.clear_row:
    mov ax, console_blank_half_line
    xor cx, cx
%if GW_BASIC_SPLIT_LOAD
    call dw_puts_ds_raw
%else
    call dw_puts_cs_raw
%endif
    mov ax, console_blank_half_line
    mov cx, CONSOLE_CLEAR_HALF_PIXELS
%if GW_BASIC_SPLIT_LOAD
    call dw_puts_ds_raw
%else
    call dw_puts_cs_raw
%endif
    add dx, CONSOLE_CELL_H
    mov al, [console_rows]
    xor ah, ah
    shl ax, 3
    cmp dx, ax
    jb .clear_row

    mov byte [console_col], 0
    mov byte [console_row], 0
    mov byte [console_cursor_visible], 0
    pop es
    pop dx
    pop cx
    pop di
    pop bx
    pop ax
    popf
    ret

; DH=row, DL=column.
console_goto:
    mov [console_row], dh
    mov [console_col], dl
    ret

console_detect_rows:
    pushf
    push ax
    mov byte [console_rows], CONSOLE_DEFAULT_ROWS
    pop ax
    popf
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
    mov al, [console_rows]
    cmp [console_row], al
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
    mov [console_cursor_saved_cell], ax
    test ah, CONSOLE_ATTR_INVERSE
    jz .invert_on
    and ah, ~CONSOLE_ATTR_INVERSE
    jmp .draw_cursor
.invert_on:
    or ah, CONSOLE_ATTR_INVERSE
.draw_cursor:
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
    mov ax, [console_cursor_saved_cell]
    call console_cursor_display_xy
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
    pushf
    push ax
    push si
    cld
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
    popf
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
    mov ah, [console_current_attr]
    call console_buffer_put_at_cursor
    call console_draw_at_cursor
    pop dx
    pop cx
    pop ax

    inc byte [console_col]
.done:
    ret

console_newline:
    mov byte [console_col], 0
    mov al, [console_rows]
    dec al
    cmp [console_row], al
    jae console_scroll_up
    inc byte [console_row]
    ret

console_scroll_up:
    push ax
    push bx
    push cx
    mov ax, 0x0102
    mov bx, 0x0101
    mov ch, CONSOLE_COLS
    mov cl, [console_rows]
    dec cl
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

    cmp ah, 1
    jb .done
    cmp al, 1
    jb .done
    cmp bh, 1
    jb .done
    cmp bl, 1
    jb .done
    or ch, ch
    jz .done
    or cl, cl
    jz .done

    mov dl, ah
    add dl, ch
    jc .done
    dec dl
    cmp dl, CONSOLE_COLS
    ja .done

    mov dl, al
    add dl, cl
    jc .done
    dec dl
    cmp dl, [console_rows]
    ja .done

    mov dl, bh
    add dl, ch
    jc .done
    dec dl
    cmp dl, CONSOLE_COLS
    ja .done

    mov dl, bl
    add dl, cl
    jc .done
    dec dl
    cmp dl, [console_rows]
    ja .done

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
; The original Microsoft source leaves SCROUT to the OEM, so preserve all
; caller state except flags. This implementation directly modifies AX/BX/CX/DX;
; SI/DI/BP/DS/ES/SS are either untouched here or preserved by called helpers.
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
    cmp dl, [console_rows]
    ja .done

    dec dh
    dec dl
    mov [console_col], dh
    mov [console_row], dl

    mov ah, [console_current_attr]
    call console_buffer_put_at_cursor
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
    cmp dl, [console_rows]
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
    clc
    ret

; GW-BASIC OEM clear-to-end-of-line primitive.
; DH=1-based start column, DL=1-based line.
CLREOL:
    pushf
    push ax
    push dx
    cmp dl, 1
    jb .done
    cmp dl, [console_rows]
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
    popf
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
    mov ax, [console_text_buffer + di]
    mov dx, ax
    call scroll_dest_cell_offset
    mov [console_text_buffer + di], dx
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
    shl ax, 1
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
    shl ax, 1
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
    mov ax, [scroll_src_pixel_x]
    xor ax, [scroll_dst_pixel_x]
    test al, 7
    jnz .bitfield_rect
    call scroll_aligned_rect
    jmp .done

.bitfield_rect:
    call scroll_bitfield_rect

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

; Tier 2: same bit alignment (src_x%8 == dst_x%8). Copy middle bytes with
; rep movsb; mask first and last bytes to preserve surrounding pixels.
scroll_aligned_rect:
    pushf
    pusha
    push ds
    push es

    xor ax, ax
    mov ds, ax
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
    call .setup_src_row
    mov si, ax
    call .setup_dst_row
    mov di, ax
    call .setup_masks
    mov bx, [scroll_pixel_height]

.fwd_row:
    push si
    push di
    call .copy_row_masked
    pop di
    pop si
    add si, LCD_STRIDE_BYTES
    add di, LCD_STRIDE_BYTES
    dec bx
    jnz .fwd_row
    jmp .done

.backward:
    cld
    mov ax, [scroll_src_pixel_y]
    add ax, [scroll_pixel_height]
    dec ax
    call .setup_row_at_y
    mov si, ax
    mov ax, [scroll_dst_pixel_y]
    add ax, [scroll_pixel_height]
    dec ax
    call .setup_row_at_y_dst
    mov di, ax
    call .setup_masks
    mov bx, [scroll_pixel_height]

.bwd_row:
    push si
    push di
    call .copy_row_masked
    pop di
    pop si
    sub si, LCD_STRIDE_BYTES
    sub di, LCD_STRIDE_BYTES
    dec bx
    jnz .bwd_row

.done:
    pop es
    pop ds
    popa
    popf
    ret

.setup_src_row:
    mov ax, [scroll_src_pixel_y]
    shl ax, 6
    push bx
    mov bx, [scroll_src_pixel_x]
    shr bx, 3
    add ax, bx
    pop bx
    add ax, [lcd_framebuffer_base]
    ret

.setup_dst_row:
    mov ax, [scroll_dst_pixel_y]
    shl ax, 6
    push bx
    mov bx, [scroll_dst_pixel_x]
    shr bx, 3
    add ax, bx
    pop bx
    add ax, [lcd_framebuffer_base]
    ret

.setup_row_at_y:
    shl ax, 6
    push bx
    mov bx, [scroll_src_pixel_x]
    shr bx, 3
    add ax, bx
    pop bx
    add ax, [lcd_framebuffer_base]
    ret

.setup_row_at_y_dst:
    shl ax, 6
    push bx
    mov bx, [scroll_dst_pixel_x]
    shr bx, 3
    add ax, bx
    pop bx
    add ax, [lcd_framebuffer_base]
    ret

.setup_masks:
    mov ax, [scroll_dst_pixel_x]
    and al, 7
    mov [scroll_left_shift], al
    mov ax, [scroll_dst_pixel_x]
    add ax, [scroll_pixel_width]
    and al, 7
    mov [scroll_right_bits], al
    mov ax, [scroll_pixel_width]
    add ax, [scroll_dst_pixel_x]
    dec ax
    shr ax, 3
    mov cx, [scroll_dst_pixel_x]
    shr cx, 3
    sub ax, cx
    mov [scroll_byte_span], ax
    ret

.copy_row_masked:
    mov cx, [scroll_byte_span]
    mov al, [scroll_left_shift]
    or al, al
    jz .no_left_edge
    push cx
    mov ah, 0xFF
    mov cl, al
    shr ah, cl
    mov al, [si]
    mov cl, [di]
    and al, ah
    not ah
    and cl, ah
    or al, cl
    mov [di], al
    inc si
    inc di
    pop cx
    dec cx
    jz .right_edge
.no_left_edge:
    push cx
    mov al, [scroll_right_bits]
    or al, al
    jz .mid_full
    dec cx
.mid_full:
    shr cx, 1
    rep movsw
    jnc .mid_even
    movsb
.mid_even:
    pop cx
.right_edge:
    mov al, [scroll_right_bits]
    or al, al
    jz .row_done
    mov cl, al
    mov ah, 0xFF
    shl ah, cl
    not ah
    mov al, [si]
    mov cl, [di]
    and al, ah
    not ah
    and cl, ah
    or al, cl
    mov [di], al
.row_done:
    ret

; Tier 3: different bit alignment. Shift-merge byte loop: each destination
; byte is assembled from two adjacent source bytes with SHL/SHR/OR.
; dst_byte[n] = (src_byte[n] << shift_l) | (src_byte[n+1] >> shift_r)
; where shift_l = (src_bit - dst_bit) & 7 for a leftward scroll.
scroll_bitfield_rect:
    pushf
    pusha
    push es

    call scroll_aligned_rect.setup_masks
    call .sm_setup_shifts

    mov ax, [scroll_dst_pixel_y]
    cmp ax, [scroll_src_pixel_y]
    ja .sm_backward
    jb .sm_forward
    mov ax, [scroll_dst_pixel_x]
    cmp ax, [scroll_src_pixel_x]
    ja .sm_backward

.sm_forward:
    cld
    call scroll_aligned_rect.setup_dst_row
    mov di, ax
    ; SI = DI + signed_pixel_offset/8 (arithmetic shift for negative offsets).
    mov ax, [scroll_src_pixel_x]
    sub ax, [scroll_dst_pixel_x]
    sar ax, 3
    mov si, di
    add si, ax
    mov bx, [scroll_pixel_height]
    xor ax, ax
    mov es, ax
    jmp .sm_row_loop

.sm_backward:
    cld
    ; Backward: start SI/DI at the RIGHTMOST byte of the last row.
    ; Compute DI from dst, then SI = DI - byte_delta.
    mov ax, [scroll_dst_pixel_y]
    add ax, [scroll_pixel_height]
    dec ax
    call scroll_aligned_rect.setup_row_at_y_dst
    add ax, [scroll_byte_span]
    mov di, ax                        ; DI = last dest byte of last row
    mov ax, [scroll_src_pixel_x]
    sub ax, [scroll_dst_pixel_x]
    sar ax, 3
    mov si, di
    add si, ax                        ; SI = DI + signed(src-dst)/8
    mov bx, [scroll_pixel_height]
    xor ax, ax
    mov es, ax
    jmp .sm_bwd_row_loop

.sm_bwd_row_loop:
    push si
    push di
    call .sm_copy_row_bwd
    pop di
    pop si
    sub si, LCD_STRIDE_BYTES
    sub di, LCD_STRIDE_BYTES
    dec bx
    jnz .sm_bwd_row_loop
    jmp .sm_done

.sm_row_loop:
    push si
    push di
    call .sm_copy_row
    pop di
    pop si
    add si, LCD_STRIDE_BYTES
    add di, LCD_STRIDE_BYTES
    dec bx
    jnz .sm_row_loop

.sm_done:
    pop es
    popa
    popf
    ret

; Copy one row with bit-shift across byte boundaries.
; SI=src row byte, DI=dst row byte (in segment 0 via ES).
; Uses scroll_left_shift (src_bit), scroll_right_bits (end_bit),
; scroll_byte_span, scroll_src_pixel_x, scroll_dst_pixel_x.
; The shift amount is (dst_bit - src_bit) & 7 or (src_bit - dst_bit) & 7
; depending on direction; we compute both complementary shifts.
; TODO: in text mode, redrawing from the shadow text buffer may be faster
; than shifting framebuffer bits. dwconsole does not currently track
; text-vs-graphics mode.

; Compute shift amounts from source/destination pixel bit offsets.
; Called once before the row loop; results go into scroll_shift_l/r.
.sm_setup_shifts:
    mov ax, [scroll_src_pixel_x]
    sub ax, [scroll_dst_pixel_x]
    and al, 7
    mov [scroll_shift_l], al
    neg al
    add al, 8
    and al, 7
    mov [scroll_shift_r], al
    ret

.sm_copy_row:
    push dx
    push bp

    mov bp, [scroll_byte_span]
    inc bp
    cmp bp, 1
    jbe .sm_row_done

    ; Initial carry: first source byte shifted left.
    mov al, [es:si]
    inc si
    mov cl, [scroll_shift_l]
    shl al, cl
    mov ah, al                        ; AH = (src[0] << shift_l)

    ; First dest byte: merge carry with next source byte.
    mov al, [es:si]
    inc si
    mov dl, al                        ; save for next carry
    mov cl, [scroll_shift_r]
    shr al, cl                        ; low bits from src[1]
    or al, ah                         ; dst[0] = carry | (src[1] >> shift_r)
    ; Mask: preserve bits left of dst_pixel_x within this byte.
    mov cl, [scroll_left_shift]
    or cl, cl
    jz .sm_first_full
    mov ch, 0xFF
    shr ch, cl
    and al, ch
    not ch
    and ch, [es:di]
    or al, ch
.sm_first_full:
    mov [es:di], al
    inc di
    dec bp
    jz .sm_row_done

    ; Carry for next byte: (src[1] << shift_l)
    mov al, dl
    mov cl, [scroll_shift_l]
    shl al, cl
    mov ah, al

    ; Middle bytes: dst[n] = (src[n] << shift_l) | (src[n+1] >> shift_r)
.sm_middle:
    or bp, bp
    jz .sm_row_done
    cmp bp, 1
    je .sm_last_byte
    mov al, [es:si]
    inc si
    mov dl, al
    mov cl, [scroll_shift_r]
    shr al, cl
    or al, ah
    mov [es:di], al
    inc di
    mov al, dl
    mov cl, [scroll_shift_l]
    shl al, cl
    mov ah, al
    dec bp
    jmp .sm_middle

.sm_last_byte:
    mov al, [es:si]
    mov cl, [scroll_shift_r]
    shr al, cl
    or al, ah
    ; Mask: preserve bits right of the scroll region end (MSB-first).
    ; scroll_right_bits = number of pixels in the last partial byte.
    ; Those pixels occupy the TOP right_bits bits of the byte.
    mov cl, [scroll_right_bits]
    or cl, cl
    jz .sm_last_full
    neg cl
    add cl, 8                         ; CL = 8 - right_bits
    mov ch, 0xFF
    shl ch, cl                        ; CH = write mask (top right_bits bits)
    and al, ch
    not ch
    and ch, [es:di]
    or al, ch
.sm_last_full:
    mov [es:di], al

.sm_row_done:
    pop bp
    pop dx
    ret

; Right-to-left row copy for backward (insert) scrolls.
; SI/DI point to the LAST byte of the source/dest row region.
; Processes from right to left to avoid overlap corruption.
.sm_copy_row_bwd:
    push dx
    push bp

    mov bp, [scroll_byte_span]
    inc bp
    cmp bp, 1
    jbe .sm_bwd_done
    cmp bp, LCD_VISIBLE_BYTES + 1
    ja .sm_bwd_done                   ; safety bound

    ; Initial carry: the byte at SI+1 provides the low bits for the
    ; rightmost destination byte.
    inc si
    mov al, [es:si]
    dec si
    mov cl, [scroll_shift_r]
    shr al, cl
    mov ah, al

    ; Process all bytes right to left.
    ; dst[n] = (src[n] << shift_l) | carry
    ; carry  = src[n] >> shift_r
.sm_bwd_byte:
    mov al, [es:si]
    dec si
    mov dl, al
    mov cl, [scroll_shift_l]
    shl al, cl
    or al, ah
    mov [es:di], al
    dec di
    mov al, dl
    mov cl, [scroll_shift_r]
    shr al, cl
    mov ah, al
    dec bp
    jnz .sm_bwd_byte

.sm_bwd_done:
    pop bp
    pop dx
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
    push dx
    push di
    push es
    push ds
    pop es
    cld
    mov al, [console_rows]
    dec al
    xor ah, ah
    mov bl, CONSOLE_COLS
    mul bl
    shl ax, 1
    mov di, console_text_buffer
    add di, ax
    mov cx, CONSOLE_COLS
    mov ax, (CONSOLE_ATTR_DEFAULT << 8) | " "
    rep stosw
    pop es

    mov al, [console_rows]
    dec al
    xor ah, ah
    shl ax, 3
    mov dx, ax
    mov ax, console_blank_half_line
    xor cx, cx
%if GW_BASIC_SPLIT_LOAD
    call dw_puts_ds_raw
%else
    call dw_puts_cs_raw
%endif
    mov ax, console_blank_half_line
    mov cx, CONSOLE_CLEAR_HALF_PIXELS
%if GW_BASIC_SPLIT_LOAD
    call dw_puts_ds_raw
%else
    call dw_puts_cs_raw
%endif

    pop di
    pop dx
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
    mov ax, (CONSOLE_ATTR_DEFAULT << 8) | " "
    call console_buffer_put_at_cursor
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

; AX = text cell: AL=character, AH=attribute.
console_draw_at_cursor:
    push ax
    push bx
    push cx
    push dx
    mov bx, ax
    call console_build_cell_string
    mov ax, console_cell
    call console_cell_xy
%if GW_BASIC_SPLIT_LOAD
    call dw_puts_ds_raw
%else
    call dw_puts_cs_raw
%endif
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; BL=character, BH=attribute. Builds the ROM text-vector string in console_cell.
console_build_cell_string:
    push ax
    push di
    mov di, console_cell
    mov ah, bh
    or ah, ah
    jnz .attr_ok
    mov ah, CONSOLE_ATTR_DEFAULT
.attr_ok:
    test ah, CONSOLE_ATTR_SMALL
    jz .small_done
    mov byte [di], 0xfa
    inc di
.small_done:
    test ah, CONSOLE_ATTR_BOLD
    jz .bold_done
    mov byte [di], 0xf8
    inc di
.bold_done:
    mov al, ah
    and al, 0x07
    cmp al, CONSOLE_ATTR_UNDERLINE
    jne .underline_done
    mov byte [di], 0xf0
    inc di
.underline_done:
    test ah, CONSOLE_ATTR_INVERSE
    jz .inverse_done
    mov byte [di], 0xf2
    inc di
.inverse_done:
    mov [di], bl
    inc di
    test ah, CONSOLE_ATTR_INVERSE
    jz .inverse_off_done
    mov byte [di], 0xf3
    inc di
.inverse_off_done:
    mov al, ah
    and al, 0x07
    cmp al, CONSOLE_ATTR_UNDERLINE
    jne .underline_off_done
    mov byte [di], 0xf1
    inc di
.underline_off_done:
    test ah, CONSOLE_ATTR_BOLD
    jz .bold_off_done
    mov byte [di], 0xf9
    inc di
.bold_off_done:
    test ah, CONSOLE_ATTR_SMALL
    jz .small_off_done
    mov byte [di], 0xfb
    inc di
.small_off_done:
    mov byte [di], 0
    pop di
    pop ax
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
    cmp dh, [console_rows]
    jb .row_ok
    mov dh, [console_rows]
    dec dh
.row_ok:
    ret

console_buffer_put_at_cursor:
    push di
    call console_buffer_offset_at_cursor
    mov [console_text_buffer + di], ax
    pop di
    ret

console_buffer_get_at_cursor:
    push di
    call console_buffer_offset_at_cursor
    mov ax, [console_text_buffer + di]
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
    shl ax, 1
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

%if GW_BASIC_SPLIT_LOAD
segment DSEG class=DATA use16
%endif

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
console_current_attr:
    db CONSOLE_ATTR_DEFAULT
console_rows:
    db CONSOLE_DEFAULT_ROWS
console_cursor_saved_cell:
    dw (CONSOLE_ATTR_DEFAULT << 8) | " "
console_cell:
    times 10 db 0
CONSOLE_CLEAR_HALF_COLS equ CONSOLE_COLS / 2
CONSOLE_CLEAR_HALF_PIXELS equ CONSOLE_CLEAR_HALF_COLS * CONSOLE_CELL_W
console_blank_half_line:
    times CONSOLE_CLEAR_HALF_COLS db " "
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
scroll_left_shift:
    db 0
scroll_right_bits:
    db 0
scroll_byte_span:
    dw 0
scroll_shift_l:
    db 0
scroll_shift_r:
    db 0
console_text_buffer:
    times CONSOLE_COLS * CONSOLE_MAX_ROWS dw (CONSOLE_ATTR_DEFAULT << 8) | " "
