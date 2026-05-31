; DreamWriter GW-BASIC OEM keyboard and screen bridge.
;
; The converted Microsoft sources call these symbols as near OEM hooks. Keep
; the DreamWriter ROM-specific key bytes in this module; the shared console
; include remains a lower-level text/LCD primitive layer.

%include "dwoem.inc"

global CLREOL
global CLRSCN
global KEYINP
global SCRINP
global SCROLL
global SCROUT
global CSRDSP
global dw_cursor_init
global dw_cursor_pre_puts
global dw_cursor_post_puts

extern CSRX
extern CSRY

DW_KEY_RIGHT equ 0x10
DW_KEY_LEFT equ 0x11
DW_KEY_DOWN equ 0x12
DW_KEY_UP equ 0x13
DW_KEY_INSERT equ 0x0d
DW_KEY_ENTER equ 0xda

MSU_RIGHT equ 28
MSU_LEFT equ 29
MSU_UP equ 30
MSU_DOWN equ 31
MSU_INSERT equ 18
MSU_DELETE equ 127

%define DWAPI_CURSOR_AWARE 1
%include "dwapi.asm"

CLRSCN:
    jmp console_clear

dw_cursor_init:
    mov byte [console_cursor_visible], 0
    mov byte [console_cursor_col], 0
    mov byte [console_cursor_row], 0
    mov byte [console_cursor_logical_col], 0
    mov byte [console_cursor_logical_row], 0
    mov byte [console_cursor_saved_char], " "
    mov byte [dw_cursor_puts_depth], 0
    mov byte [dw_cursor_restore], 0
    mov byte [dw_cursor_requested_type], 0
    ret

; CSRDSP is passed AL=cursor type.  Use BASIC's 1-based CSRX/CSRY as the cursor
; position instead of trusting every SETCSR caller to have loaded DX.
CSRDSP:
    pushf
    push ax
    mov [dw_cursor_requested_type], al
    push dx
    mov al, [console_col]
    push ax
    mov al, [console_row]
    push ax

    call console_hide_cursor

    mov al, [CSRX]
    cmp al, 1
    jae .column_1_based
    mov al, 1
.column_1_based:
    dec al
    cmp al, CONSOLE_COLS - 1
    jbe .column_ok
    mov al, CONSOLE_COLS - 1
.column_ok:
    mov [console_col], al

    mov al, [CSRY]
    cmp al, 1
    jae .row_1_based
    mov al, 1
.row_1_based:
    dec al
    cmp al, CONSOLE_ROWS - 1
    jbe .row_ok
    mov al, CONSOLE_ROWS - 1
.row_ok:
    mov [console_row], al

    cmp byte [dw_cursor_requested_type], 0
    je .done
    call console_show_cursor

.done:
    pop ax
    mov [console_row], al
    pop ax
    mov [console_col], al
    pop dx
    pop ax
    popf
    ret

dw_cursor_pre_puts:
    pushf
    push ax

    cmp byte [dw_cursor_puts_depth], 0
    je .outer
    inc byte [dw_cursor_puts_depth]
    jmp .done

.outer:
    inc byte [dw_cursor_puts_depth]
    mov al, [console_cursor_visible]
    mov [dw_cursor_restore], al
    or al, al
    jz .done
    call console_hide_cursor

.done:
    pop ax
    popf
    ret

dw_cursor_post_puts:
    pushf
    push ax

    cmp byte [dw_cursor_puts_depth], 0
    je .done
    cmp byte [dw_cursor_puts_depth], 1
    je .outer
    dec byte [dw_cursor_puts_depth]
    jmp .done

.outer:
    cmp byte [dw_cursor_restore], 0
    je .clear
    mov al, [console_col]
    push ax
    mov al, [console_row]
    push ax
    mov al, [console_cursor_logical_col]
    mov [console_col], al
    mov al, [console_cursor_logical_row]
    mov [console_row], al
    call console_show_cursor
    pop ax
    mov [console_row], al
    pop ax
    mov [console_col], al
.clear:
    mov byte [dw_cursor_restore], 0
    mov byte [dw_cursor_puts_depth], 0

.done:
    pop ax
    popf
    ret

; KEYINP is the GW-BASIC OEM poll primitive. It must return with ZF set when no
; key is ready. Normal one-byte keys return CF clear in AL. MS Universal editor
; controls return CF set as AX=FFxx so POLKEY can run ON KEY trapping and the
; screen editor can distinguish control functions from printable bytes.
KEYINP:
    push bp
    mov bp, sp
    sub sp, 2
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    mov bx, ds
    mov es, bx

    mov ah, 0x0b
    int 0x21
    cmp al, 0xff
    jne .no_key

    mov ah, 0x08
    int 0x21
    xor ah, ah
    call keyinp_map
    jmp .store_result

.no_key:
    xor ax, ax

.store_result:
    mov [bp - 2], ax
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    mov ax, [bp - 2]
    mov sp, bp
    pop bp

    test ax, ax
    jz .return_no_key
    cmp ah, 0xff
    je .return_two_byte
    or al, al
    clc
    ret

.return_two_byte:
    or al, al
    stc
    ret

.return_no_key:
    clc
    ret

keyinp_map:
    cmp al, DW_KEY_ENTER
    je .enter
    cmp al, DW_KEY_INSERT
    je .insert
    cmp al, DW_KEY_RIGHT
    je .right
    cmp al, DW_KEY_LEFT
    je .left
    cmp al, DW_KEY_UP
    je .up
    cmp al, DW_KEY_DOWN
    je .down
    cmp al, MSU_DELETE
    je .delete
    ret

.enter:
    mov al, 0x0d
    ret
.insert:
    mov ax, (0xff << 8) | MSU_INSERT
    ret
.right:
    mov ax, (0xff << 8) | MSU_RIGHT
    ret
.left:
    mov ax, (0xff << 8) | MSU_LEFT
    ret
.up:
    mov ax, (0xff << 8) | MSU_UP
    ret
.down:
    mov ax, (0xff << 8) | MSU_DOWN
    ret
.delete:
    mov ax, (0xff << 8) | MSU_DELETE
    ret

%define DWCONSOLE_NO_LOCAL_SETCSR 1
%include "dwconsole.asm"

dw_cursor_puts_depth:
    db 0
dw_cursor_restore:
    db 0
dw_cursor_requested_type:
    db 0
