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

%include "dwapi.asm"

CLRSCN:
    jmp console_clear

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
    push ds

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
    pop ds
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
