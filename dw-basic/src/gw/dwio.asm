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
global SCRATR
global SCROLL
global SCROUT
global SETCLR
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
DW_KEY_CAN equ 0x03
DW_KEY_ORGN equ 0x02
DW_KEY_WP equ 0x0b
DW_PHYS_LSHIFT equ 0x00
DW_PHYS_RSHIFT equ 0x01
DW_PHYS_ALT equ 0x08
DW_PHYS_CONTROL equ 0x10
DW_PHYS_CAPS equ 0x11
DW_PHYS_ORGN equ 0x3a
DW_KEY_MOD_CONTROL equ 0x40
DW_KEY_QUEUE_BASE equ 0x70a6
DW_KEY_QUEUE_END equ 0x70e2
DW_KEY_QUEUE_READ equ 0x70e2
DW_KEY_QUEUE_WRITE equ 0x70e3

MSU_RIGHT equ 28
MSU_LEFT equ 29
MSU_UP equ 30
MSU_DOWN equ 31
MSU_INSERT equ 18
MSU_DELETE equ 127
MSU_BREAK equ 3
MSU_HOME equ 11
MSU_ESCAPE equ 27

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
    mov byte [console_current_attr], CONSOLE_ATTR_DEFAULT
    mov word [console_cursor_saved_cell], (CONSOLE_ATTR_DEFAULT << 8) | " "
    mov byte [dw_cursor_puts_depth], 0
    mov byte [dw_cursor_restore], 0
    mov byte [dw_cursor_requested_type], 0
    ret

; COLOR passes a GW-BASIC parameter list at BX: count byte followed by
; two-byte entries, where entry byte 0 is nonzero when the parameter exists and
; entry byte 1 is the byte value. Map foreground/background onto the IBM MDA
; attribute byte and use the blink slot as the DreamWriter "small" extension.
SETCLR:
    push ax
    push bx
    push cx
    push dx
    mov dl, [console_current_attr]
    mov cl, [bx]
    xor ch, ch
    inc bx
    jcxz .store

    cmp byte [bx], 0
    je .background
    mov al, [bx + 1]
    mov ah, al
    and al, 0x0f
    and dl, 0xf0
    or dl, al
    test ah, CONSOLE_ATTR_SMALL
    jz .fg_not_small
    or dl, CONSOLE_ATTR_SMALL
    jmp .background
.fg_not_small:
    and dl, ~CONSOLE_ATTR_SMALL

.background:
    cmp cl, 2
    jb .store
    add bx, 2
    cmp byte [bx], 0
    je .store
    mov al, [bx + 1]
    cmp al, 7
    ja .error
    shl al, 4
    and dl, 0x8f
    or dl, al

.store:
    mov [console_current_attr], dl
    pop dx
    pop cx
    pop bx
    pop ax
    clc
    ret

.error:
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret

; SCREEN(row, col, nonzero) asks for the attribute at a 1-based cell.
; gwsts passes the X parameter in AL and the Y parameter in BL.
SCRATR:
    push bx
    push dx
    mov dh, al
    mov dl, bl
    mov ax, CONSOLE_ATTR_DEFAULT
    cmp dh, 1
    jb .done
    cmp dh, CONSOLE_COLS
    ja .done
    cmp dl, 1
    jb .done
    cmp dl, CONSOLE_ROWS
    ja .done
    mov bl, [console_col]
    mov bh, [console_row]
    push bx
    dec dh
    dec dl
    mov [console_col], dh
    mov [console_row], dl
    call console_buffer_get_at_cursor
    mov al, ah
    xor ah, ah
    pop bx
    mov [console_col], bl
    mov [console_row], bh
.done:
    pop dx
    pop bx
    clc
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
extern DWSND_ACTIVE
KEYINP:
    push bp
    mov bp, sp
    sub sp, 4
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    mov bx, ds
    mov es, bx
    mov byte [bp - 3], 0

    call DWSND_ACTIVE
    jz .rom_status
    push ds
    xor bx, bx
    mov ds, bx
    mov al, [DW_KEY_QUEUE_READ]
    cmp al, [DW_KEY_QUEUE_WRITE]
    pop ds
    je .no_key

    call keyinp_peek_orgn_break
    jnc .sound_read
    mov byte [bp - 3], 1
.sound_read:
    mov ah, 0x08
    int 0x21
    cmp byte [bp - 3], 0
    jne .force_break
    xor ah, ah
    call keyinp_map
    jmp .store_result

.rom_status:
    mov ah, 0x0b
    int 0x21
    cmp al, 0xff
    jne .no_key

    call keyinp_peek_orgn_break
    jnc .rom_read
    mov byte [bp - 3], 1
.rom_read:
    mov ah, 0x08
    int 0x21
    cmp byte [bp - 3], 0
    jne .force_break
    xor ah, ah
    call keyinp_map
    jmp .store_result

.force_break:
    mov ax, (0xff << 8) | MSU_BREAK
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

keyinp_peek_orgn_break:
    push bx
    push dx
    push ds
    xor bx, bx
    mov ds, bx
    mov bl, [DW_KEY_QUEUE_READ]
.scan:
    cmp bl, [DW_KEY_QUEUE_WRITE]
    je .not_break
    cmp bl, DW_KEY_QUEUE_END - DW_KEY_QUEUE_BASE
    jae .not_break
    mov dx, [bx + DW_KEY_QUEUE_BASE]
    cmp dl, DW_PHYS_ORGN
    je .check_orgn
    cmp dl, DW_PHYS_LSHIFT
    je .next
    cmp dl, DW_PHYS_RSHIFT
    je .next
    cmp dl, DW_PHYS_ALT
    je .next
    cmp dl, DW_PHYS_CONTROL
    je .next
    cmp dl, DW_PHYS_CAPS
    je .next
    jmp .not_break

.check_orgn:
    test dh, DW_KEY_MOD_CONTROL
    jnz .is_break
    jmp .not_break

.next:
    add bl, 2
    cmp bl, DW_KEY_QUEUE_END - DW_KEY_QUEUE_BASE
    jb .scan
    xor bl, bl
    jmp .scan

.is_break:
    pop ds
    pop dx
    pop bx
    stc
    ret
.not_break:
    pop ds
    pop dx
    pop bx
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
    cmp al, DW_KEY_CAN
    je .escape
    cmp al, DW_KEY_ORGN
    je .home
    cmp al, DW_KEY_WP
    je .home
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
.escape:
    mov ax, (0xff << 8) | MSU_ESCAPE
    ret
.home:
    mov ax, (0xff << 8) | MSU_HOME
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
