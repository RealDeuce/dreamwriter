#!/usr/bin/env python3
"""Build an experimental DreamWriter BASIC EROMCARD.X SRAM image.

This is deliberately narrow: it targets the current 1 MiB SRAM-card experiment,
the MAME PCMCIA bank model, and ROM-card smoke tests documented in
docs/basic-eromcard.md.
"""

from __future__ import annotations

import argparse
import math
import struct
import subprocess
import tempfile
from pathlib import Path


SECTOR_SIZE = 0x80
CARD_PAGE_SIZE = 0x20000
ROOT_SECTORS = 0x20
ROOT_ENTRY_SIZE = 0x20

EDITOR_HEADER = bytes.fromhex("3c0086018601c20184000c0076001eda")
DEFAULT_BASIC_LINES = [
    '10 PRINT "BASIC EXEC OK"',
    '20 INPUT "PRESS ENTER";A$',
]


BASIC_STUB_ASM = """\
bits 16
org 0

    dw 0xA4F0
    dw 0x1997
    dw entry
    dw 0x0A4F

entry:
    mov [cs:loader_limit], ax

    mov al, {bank:#04x}
    out 0x17, al

    push cs
    pop ds
    xor ax, ax
    mov es, ax
    mov si, fixed_path
    mov di, 0x7f5f
    mov cx, fixed_path_end - fixed_path
    cld
    rep movsb

    push ds
    push es
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov byte [0x7653], 0x01
    mov si, 0x1000
    mov di, {lcd_base:#06x}
    mov cx, 0x0800
    cld
    rep movsw
    pop es
    pop ds

    mov al, {lcd_value:#04x}
    out 0x00, al

    mov ax, {work_segment:#06x}
    mov es, ax
    xor ax, ax
    mov ds, ax

    mov bx, {work_limit:#06x}
    mov ax, {work_segment:#06x}
    mov cx, 0x7f5f
    call 0xf200:0x7dab

    push ax
    mov al, {restore_lcd_value:#04x}
    out 0x00, al
    push ds
    xor ax, ax
    mov ds, ax
    mov byte [0x7653], 0x00
    pop ds
    ; The copied loader still reads the BASIC keyword table at F200:65A5.
    ; Keep the 325 page mapped while tokenizing the source file.
    mov al, {bank:#04x}
    out 0x17, al
    pop ax
    retf

loader_limit:
    dw 0

fixed_path:
    db {path_bytes}
fixed_path_end:
"""


BASIC_EXEC_STUB_ASM = """\
bits 16
org 0

    dw 0xA4F0
    dw 0x1997
    dw entry
    dw 0x0A4F

entry:
    mov al, {bank:#04x}
    out 0x17, al

    call {routine_segment:#06x}:{routine_offset:#06x}

    ; The copied loader still reads the BASIC keyword table at F200:65A5.
    ; Keep the 325 page mapped while tokenizing the source file.
    mov al, {bank:#04x}
    out 0x17, al
    retf
"""


BASIC_LOAD_PROBE_STUB_ASM = """\
bits 16
org 0

    dw 0xA4F0
    dw 0x1997
    dw entry
    dw 0x0A4F

%macro show_message 1
    xor ax, ax
    mov ds, ax
    mov ax, %1
    push cs
    pop bx
    mov cx, {x_pos:#06x}
    mov dx, {y_pos:#06x}
    call far [0x0204]
    call far [0x0230]
%endmacro

entry:
    mov al, {bank:#04x}
    out 0x17, al

    push cs
    pop ds
    xor ax, ax
    mov es, ax
    mov si, fixed_path
    mov di, 0x7f5f
    mov cx, fixed_path_end - fixed_path
    cld
    rep movsb

    show_message before_message

    xor ax, ax
    mov ds, ax
    mov word [0x479a], 0x0400
    mov word [0x479e], 0x0400

    mov ax, {work_segment:#06x}
    shl ax, 1
    shl ax, 1
    shl ax, 1
    shl ax, 1
    mov [0x478e], ax

    mov ax, [0x478e]
    add ax, {work_limit:#06x}
    sub ax, 0x0484
    mov [0x4796], ax

    mov ax, [0x4796]
    sub ax, [0x479e]
    mov [0x4794], ax

    mov ax, [0x4794]
    sub ax, [0x478e]
    sub ax, [0x479a]
    mov bx, 0x7f5f

    call {routine_segment:#06x}:{routine_offset:#06x}
    mov [cs:load_result], ax

    ; The copied loader still reads the BASIC keyword table at F200:65A5.
    ; Keep the 325 page mapped while tokenizing the source file.
    mov al, {bank:#04x}
    out 0x17, al

    cmp word [cs:load_result], 0xffff
    jne .load_ok
    show_message fail_message
    retf

.load_ok:
    show_message ok_message
    retf

load_result:
    dw 0
before_message:
    db {before_message_bytes}
ok_message:
    db {ok_message_bytes}
fail_message:
    db {fail_message_bytes}
fixed_path:
    db {path_bytes}
fixed_path_end:
"""


BASIC_LOAD_PROBE_ROUTINE_ASM = """\
bits 16
org {routine_offset:#06x}

entry:
    call 0x31b6
    retf
"""


BASIC_FILE_PROBE_STUB_ASM = """\
bits 16
org 0

    dw 0xA4F0
    dw 0x1997
    dw entry
    dw 0x0A4F

%macro show_message 1
    xor ax, ax
    mov ds, ax
    mov ax, %1
    push cs
    pop bx
    mov cx, {x_pos:#06x}
    mov dx, {y_pos:#06x}
    call far [0x0204]
    call far [0x0230]
%endmacro

entry:
    push cs
    pop ds
    xor ax, ax
    mov es, ax
    mov si, fixed_path
    mov di, 0x7f5f
    mov cx, fixed_path_end - fixed_path
    cld
    rep movsb

    show_message before_message

    xor ax, ax
    mov ds, ax
    push word 0x0000
    push word 0x7f5f
    call far [0x0244]
    add sp, 4
    mov [cs:file_handle], ax
    cmp ax, 0xffff
    jne .open_ok
    show_message open_fail_message
    retf

.open_ok:
    show_message open_ok_message

    xor ax, ax
    mov ds, ax
    mov ax, [cs:file_handle]
    mov bx, 0x7f80
    mov cx, 0x0002
    call far [0x0248]
    mov [cs:read_count], ax
    cmp ax, 0x0002
    jne .read_fail
    cmp byte [0x7f80], 0xff
    jne .read_fail

    mov ax, [cs:file_handle]
    call far [0x0250]
    show_message read_ok_message
    retf

.read_fail:
    mov ax, [cs:file_handle]
    call far [0x0250]
    show_message read_fail_message
    retf

file_handle:
    dw 0
read_count:
    dw 0
before_message:
    db {before_message_bytes}
open_ok_message:
    db {open_ok_message_bytes}
open_fail_message:
    db {open_fail_message_bytes}
read_ok_message:
    db {read_ok_message_bytes}
read_fail_message:
    db {read_fail_message_bytes}
fixed_path:
    db {path_bytes}
fixed_path_end:
"""


BASIC_RAM_LOAD_PROBE_STUB_ASM = """\
bits 16
org 0

    dw 0xA4F0
    dw 0x1997
    dw entry
    dw 0x0A4F

%macro show_message 1
    xor ax, ax
    mov ds, ax
    mov ax, %1
    push cs
    pop bx
    mov cx, {x_pos:#06x}
    mov dx, {y_pos:#06x}
    call far [0x0204]
    call far [0x0230]
%endmacro

entry:
    push cs
    pop ds
    mov ax, {reloc_segment:#06x}
    mov es, ax
    mov di, ({reloc_words:#06x} * 2) - 2
    mov si, reloc_image + ({reloc_words:#06x} * 2) - 2
    mov cx, {reloc_words:#06x}
    std
    rep movsw
    cld

    push cs
    pop ds
    xor ax, ax
    mov es, ax
    mov si, fixed_path
    mov di, 0x7f5f
    mov cx, fixed_path_end - fixed_path
    cld
    rep movsb

    show_message before_message

    xor ax, ax
    mov ds, ax
    mov word [0x479a], 0x0400
    mov word [0x479e], 0x0400

    mov ax, {work_segment:#06x}
    shl ax, 1
    shl ax, 1
    shl ax, 1
    shl ax, 1
    mov [0x478e], ax

    mov ax, [0x478e]
    add ax, {work_limit:#06x}
    sub ax, 0x0484
    mov [0x4796], ax

    mov ax, [0x4796]
    sub ax, [0x479e]
    mov [0x4794], ax

    mov ax, [0x4794]
    sub ax, [0x478e]
    sub ax, [0x479a]
    mov bx, 0x7f5f

    ; The copied loader still reads the BASIC keyword table at F200:65A5.
    ; Keep the 325 page mapped while tokenizing the source file.
    mov al, {bank:#04x}
    out 0x17, al
    call {reloc_segment:#06x}:{wrapper_offset:#06x}
    mov [cs:load_result], ax

    cmp word [cs:load_result], 0xffff
    jne .load_ok
    show_message fail_message
    retf

.load_ok:
    show_message ok_message
    retf

load_result:
    dw 0
before_message:
    db {before_message_bytes}
ok_message:
    db {ok_message_bytes}
fail_message:
    db {fail_message_bytes}
fixed_path:
    db {path_bytes}
fixed_path_end:
reloc_image:
    db {reloc_bytes}
"""


BASIC_INIT_STEPS_PROBE_STUB_ASM = """\
bits 16
org 0

    dw 0xA4F0
    dw 0x1997
    dw entry
    dw 0x0A4F

%macro show_message 1
    xor ax, ax
    mov ds, ax
    mov ax, %1
    push cs
    pop bx
    mov cx, {x_pos:#06x}
    mov dx, {y_pos:#06x}
    call far [0x0204]
    call far [0x0230]
%endmacro

entry:
    push cs
    pop ds
    mov ax, {reloc_segment:#06x}
    mov es, ax
    mov di, ({reloc_words:#06x} * 2) - 2
    mov si, reloc_image + ({reloc_words:#06x} * 2) - 2
    mov cx, {reloc_words:#06x}
    std
    rep movsw
    cld

    push cs
    pop ds
    xor ax, ax
    mov es, ax
    mov si, fixed_path
    mov di, 0x7f5f
    mov cx, fixed_path_end - fixed_path
    cld
    rep movsb

    show_message before_load_message

    xor ax, ax
    mov ds, ax
    mov word [0x479a], 0x0400
    mov word [0x479e], 0x0400

    mov ax, {work_segment:#06x}
    shl ax, 1
    shl ax, 1
    shl ax, 1
    shl ax, 1
    mov [0x478e], ax

    mov ax, [0x478e]
    add ax, {work_limit:#06x}
    sub ax, 0x0484
    mov [0x4796], ax

    mov ax, [0x4796]
    sub ax, [0x479e]
    mov [0x4794], ax

    mov ax, [0x4794]
    sub ax, [0x478e]
    sub ax, [0x479a]
    mov bx, 0x7f5f

    ; The copied loader still reads the BASIC keyword table at F200:65A5.
    ; Keep the 325 page mapped while tokenizing the source file.
    mov al, {bank:#04x}
    out 0x17, al
    call {reloc_segment:#06x}:{load_wrapper_offset:#06x}
    mov [cs:load_result], ax
    mov [0x4798], ax

    cmp word [cs:load_result], 0xffff
    jne .load_ok
    show_message load_fail_message
    retf

.load_ok:
    show_message load_ok_message

    mov al, {bank:#04x}
    out 0x17, al

    show_message before_83eb_message
    call {mapped_wrapper_segment:#06x}:{init_83eb_wrapper_offset:#06x}
    show_message after_83eb_message

    show_message before_7c82_message
    call {mapped_wrapper_segment:#06x}:{init_7c82_wrapper_offset:#06x}
    show_message after_7c82_message

    show_message before_7c1e_message
    call {mapped_wrapper_segment:#06x}:{init_7c1e_wrapper_offset:#06x}
    show_message after_7c1e_message

    ; The copied loader still reads the BASIC keyword table at F200:65A5.
    ; Keep the 325 page mapped while tokenizing the source file.
    mov al, {bank:#04x}
    out 0x17, al
    retf

load_result:
    dw 0
before_load_message:
    db {before_load_message_bytes}
load_ok_message:
    db {load_ok_message_bytes}
load_fail_message:
    db {load_fail_message_bytes}
before_83eb_message:
    db "BEFORE 83EB - PRESS KEY", 0
after_83eb_message:
    db "AFTER 83EB - PRESS KEY", 0
before_7c82_message:
    db "BEFORE 7C82 - PRESS KEY", 0
after_7c82_message:
    db "AFTER 7C82 - PRESS KEY", 0
before_7c1e_message:
    db "BEFORE 7C1E - PRESS KEY", 0
after_7c1e_message:
    db "AFTER 7C1E - PRESS KEY", 0
fixed_path:
    db {path_bytes}
fixed_path_end:
reloc_image:
    db {reloc_bytes}
"""


BASIC_RUNTIME_PROBE_STUB_ASM = """\
bits 16
org 0

    dw 0xA4F0
    dw 0x1997
    dw entry
    dw 0x0A4F

%macro show_message 1
    xor ax, ax
    mov ds, ax
    mov ax, %1
    push cs
    pop bx
    mov cx, {x_pos:#06x}
    mov dx, {y_pos:#06x}
    call far [0x0204]
    call far [0x0230]
%endmacro

entry:
    push cs
    pop ds
    mov ax, {reloc_segment:#06x}
    mov es, ax
    mov di, ({reloc_words:#06x} * 2) - 2
    mov si, reloc_image + ({reloc_words:#06x} * 2) - 2
    mov cx, {reloc_words:#06x}
    std
    rep movsw
    cld

    push cs
    pop ds
    xor ax, ax
    mov es, ax
    mov si, fixed_path
    mov di, 0x7f5f
    mov cx, fixed_path_end - fixed_path
    cld
    rep movsb

    show_message before_load_message

    xor ax, ax
    mov ds, ax
    mov word [0x479a], 0x0400
    mov word [0x479e], 0x0400

    mov ax, {work_segment:#06x}
    shl ax, 1
    shl ax, 1
    shl ax, 1
    shl ax, 1
    mov [0x478e], ax

    mov ax, [0x478e]
    add ax, {work_limit:#06x}
    sub ax, 0x0484
    mov [0x4796], ax

    mov ax, [0x4796]
    sub ax, [0x479e]
    mov [0x4794], ax

    mov ax, [0x4794]
    sub ax, [0x478e]
    sub ax, [0x479a]
    mov bx, 0x7f5f

    ; The copied loader still reads the BASIC keyword table at F200:65A5.
    ; Keep the 325 page mapped while tokenizing the source file.
    mov al, {bank:#04x}
    out 0x17, al
    call {reloc_segment:#06x}:{load_wrapper_offset:#06x}
    mov [cs:load_result], ax
    mov [0x4798], ax

    cmp word [cs:load_result], 0xffff
    jne .load_ok
    show_message load_fail_message
    retf

.load_ok:
    show_message load_ok_message

    mov al, {bank:#04x}
    out 0x17, al

    call {mapped_wrapper_segment:#06x}:{init_83eb_wrapper_offset:#06x}
    call {mapped_wrapper_segment:#06x}:{init_7c82_wrapper_offset:#06x}
    call {mapped_wrapper_segment:#06x}:{init_7c1e_wrapper_offset:#06x}

    show_message before_runtime_message

    xor ax, ax
    mov ds, ax
    mov es, ax
    mov byte [0x7653], 0x01
    mov si, 0x1000
    mov di, {lcd_base:#06x}
    mov cx, 0x0800
    cld
    rep movsw

    mov al, {lcd_value:#04x}
    out 0x00, al

    xor ax, ax
    mov ds, ax
    call {mapped_wrapper_segment:#06x}:{runtime_wrapper_offset:#06x}

    mov al, {restore_lcd_value:#04x}
    out 0x00, al
    xor ax, ax
    mov ds, ax
    mov byte [0x7653], 0x00

    show_message runtime_returned_message
    ; The copied loader still reads the BASIC keyword table at F200:65A5.
    ; Keep the 325 page mapped while tokenizing the source file.
    mov al, {bank:#04x}
    out 0x17, al
    retf

load_result:
    dw 0
before_load_message:
    db {before_load_message_bytes}
load_ok_message:
    db {load_ok_message_bytes}
load_fail_message:
    db {load_fail_message_bytes}
before_runtime_message:
    db "BEFORE RUNTIME - PRESS KEY", 0
runtime_returned_message:
    db "RUNTIME RETURNED - PRESS KEY", 0
fixed_path:
    db {path_bytes}
fixed_path_end:
reloc_image:
    db {reloc_bytes}
"""


BASIC_RUNTIME_STEPS_PROBE_STUB_ASM = """\
bits 16
org 0

    dw 0xA4F0
    dw 0x1997
    dw entry
    dw 0x0A4F

%macro show_message 1
    xor ax, ax
    mov ds, ax
    mov ax, %1
    push cs
    pop bx
    mov cx, {x_pos:#06x}
    mov dx, {y_pos:#06x}
    call far [0x0204]
    call far [0x0230]
%endmacro

entry:
    push cs
    pop ds
    mov ax, {reloc_segment:#06x}
    mov es, ax
    mov di, ({reloc_words:#06x} * 2) - 2
    mov si, reloc_image + ({reloc_words:#06x} * 2) - 2
    mov cx, {reloc_words:#06x}
    std
    rep movsw
    cld

    push cs
    pop ds
    xor ax, ax
    mov es, ax
    mov si, fixed_path
    mov di, 0x7f5f
    mov cx, fixed_path_end - fixed_path
    cld
    rep movsb

    show_message before_load_message

    xor ax, ax
    mov ds, ax
    mov word [0x479a], 0x0400
    mov word [0x479e], 0x0400

    mov ax, {work_segment:#06x}
    shl ax, 1
    shl ax, 1
    shl ax, 1
    shl ax, 1
    mov [0x478e], ax

    mov ax, [0x478e]
    add ax, {work_limit:#06x}
    sub ax, 0x0484
    mov [0x4796], ax

    mov ax, [0x4796]
    sub ax, [0x479e]
    mov [0x4794], ax

    mov ax, [0x4794]
    sub ax, [0x478e]
    sub ax, [0x479a]
    mov bx, 0x7f5f

    ; The copied loader still reads the BASIC keyword table at F200:65A5.
    ; Keep the 325 page mapped while tokenizing the source file.
    mov al, {bank:#04x}
    out 0x17, al
    call {reloc_segment:#06x}:{load_wrapper_offset:#06x}
    mov [cs:load_result], ax
    mov [0x4798], ax

    cmp word [cs:load_result], 0xffff
    jne .load_ok
    show_message load_fail_message
    retf

.load_ok:
    show_message load_ok_message

    mov al, {bank:#04x}
    out 0x17, al

    call {mapped_wrapper_segment:#06x}:{init_83eb_wrapper_offset:#06x}
    call {mapped_wrapper_segment:#06x}:{init_7c82_wrapper_offset:#06x}
    call {mapped_wrapper_segment:#06x}:{init_7c1e_wrapper_offset:#06x}

    show_message before_6800_message
    call {mapped_wrapper_segment:#06x}:{poll_wrapper_offset:#06x}
    mov [cs:poll_result], ax
    show_message after_6800_message

    show_message before_c3fd_message
    call {mapped_wrapper_segment:#06x}:{token_wrapper_offset:#06x}
    mov [cs:token_result], ax
    show_message after_c3fd_message

    mov al, 0x00
    out 0x17, al
    retf

load_result:
    dw 0
poll_result:
    dw 0
token_result:
    dw 0
before_load_message:
    db {before_load_message_bytes}
load_ok_message:
    db {load_ok_message_bytes}
load_fail_message:
    db {load_fail_message_bytes}
before_6800_message:
    db "BEFORE 6800 - PRESS KEY", 0
after_6800_message:
    db "AFTER 6800 - PRESS KEY", 0
before_c3fd_message:
    db "BEFORE C3FD - PRESS KEY", 0
after_c3fd_message:
    db "AFTER C3FD - PRESS KEY", 0
fixed_path:
    db {path_bytes}
fixed_path_end:
reloc_image:
    db {reloc_bytes}
"""


BASIC_RUNTIME_BRANCH_PROBE_STUB_ASM = """\
bits 16
org 0

    dw 0xA4F0
    dw 0x1997
    dw entry
    dw 0x0A4F

%macro show_message 1
    xor ax, ax
    mov ds, ax
    mov ax, %1
    push cs
    pop bx
    mov cx, {x_pos:#06x}
    mov dx, {y_pos:#06x}
    call far [0x0204]
    call far [0x0230]
%endmacro

entry:
    push cs
    pop ds
    mov ax, {reloc_segment:#06x}
    mov es, ax
    mov di, ({reloc_words:#06x} * 2) - 2
    mov si, reloc_image + ({reloc_words:#06x} * 2) - 2
    mov cx, {reloc_words:#06x}
    std
    rep movsw
    cld

    push cs
    pop ds
    xor ax, ax
    mov es, ax
    mov si, fixed_path
    mov di, 0x7f5f
    mov cx, fixed_path_end - fixed_path
    cld
    rep movsb

    show_message before_load_message

    xor ax, ax
    mov ds, ax
    mov word [0x479a], 0x0400
    mov word [0x479e], 0x0400

    mov ax, {work_segment:#06x}
    shl ax, 1
    shl ax, 1
    shl ax, 1
    shl ax, 1
    mov [0x478e], ax

    mov ax, [0x478e]
    add ax, {work_limit:#06x}
    sub ax, 0x0484
    mov [0x4796], ax

    mov ax, [0x4796]
    sub ax, [0x479e]
    mov [0x4794], ax

    mov ax, [0x4794]
    sub ax, [0x478e]
    sub ax, [0x479a]
    mov bx, 0x7f5f

    ; The copied loader still reads the BASIC keyword table at F200:65A5.
    ; Keep the 325 page mapped while tokenizing the source file.
    mov al, {bank:#04x}
    out 0x17, al
    call {reloc_segment:#06x}:{load_wrapper_offset:#06x}
    mov [cs:load_result], ax
    mov [0x4798], ax

    cmp word [cs:load_result], 0xffff
    jne .load_ok
    show_message load_fail_message
    retf

.load_ok:
    show_message load_ok_message

    mov al, {bank:#04x}
    out 0x17, al

    call {mapped_wrapper_segment:#06x}:{init_83eb_wrapper_offset:#06x}
    call {mapped_wrapper_segment:#06x}:{init_7c82_wrapper_offset:#06x}
    call {mapped_wrapper_segment:#06x}:{init_7c1e_wrapper_offset:#06x}

    call {mapped_wrapper_segment:#06x}:{poll_wrapper_offset:#06x}
    call {mapped_wrapper_segment:#06x}:{token_wrapper_offset:#06x}
    mov [cs:token_result], ax
    mov [cs:token_byte], al
    show_message token_read_message

    mov bl, [cs:token_byte]
    cmp bl, 0x3a
    je .colon
    test bl, bl
    jz .end_of_line
    cmp bl, 0x80
    jb .not_command
    cmp bl, 0xb0
    jbe .command
.not_command:
    cmp bl, 0x41
    jb .not_letter
    cmp bl, 0x5a
    jbe .letter
.not_letter:
    cmp bl, 0xe7
    je .e7_token
    jmp .error_token

.colon:
    show_message colon_message
    jmp .done

.end_of_line:
    show_message eol_message
    jmp .done

.command:
    show_message command_message
    jmp .done

.letter:
    mov al, [cs:token_byte]
    mov [cs:letter_char], al
    show_message letter_message
    jmp .done

.e7_token:
    show_message e7_message
    jmp .done

.error_token:
    show_message error_message

.done:
    mov al, 0x00
    out 0x17, al
    retf

load_result:
    dw 0
token_result:
    dw 0
token_byte:
    db 0
before_load_message:
    db {before_load_message_bytes}
load_ok_message:
    db {load_ok_message_bytes}
load_fail_message:
    db {load_fail_message_bytes}
token_read_message:
    db "TOKEN READ - PRESS KEY", 0
colon_message:
    db "BRANCH COLON - PRESS KEY", 0
eol_message:
    db "BRANCH EOL - PRESS KEY", 0
command_message:
    db "BRANCH COMMAND - PRESS KEY", 0
letter_message:
    db "BRANCH LETTER "
letter_char:
    db "?"
    db " - PRESS KEY", 0
e7_message:
    db "BRANCH E7 - PRESS KEY", 0
error_message:
    db "BRANCH ERROR - PRESS KEY", 0
fixed_path:
    db {path_bytes}
fixed_path_end:
reloc_image:
    db {reloc_bytes}
"""


BASIC_RUNTIME_LETTER_PROBE_STUB_ASM = """\
bits 16
org 0

    dw 0xA4F0
    dw 0x1997
    dw entry
    dw 0x0A4F

%macro show_message 1
    xor ax, ax
    mov ds, ax
    mov ax, %1
    push cs
    pop bx
    mov cx, {x_pos:#06x}
    mov dx, {y_pos:#06x}
    call far [0x0204]
    call far [0x0230]
%endmacro

entry:
    push cs
    pop ds
    mov ax, {reloc_segment:#06x}
    mov es, ax
    mov di, ({reloc_words:#06x} * 2) - 2
    mov si, reloc_image + ({reloc_words:#06x} * 2) - 2
    mov cx, {reloc_words:#06x}
    std
    rep movsw
    cld

    push cs
    pop ds
    xor ax, ax
    mov es, ax
    mov si, fixed_path
    mov di, 0x7f5f
    mov cx, fixed_path_end - fixed_path
    cld
    rep movsb

    show_message before_load_message

    xor ax, ax
    mov ds, ax
    mov word [0x479a], 0x0400
    mov word [0x479e], 0x0400

    mov ax, {work_segment:#06x}
    shl ax, 1
    shl ax, 1
    shl ax, 1
    shl ax, 1
    mov [0x478e], ax

    mov ax, [0x478e]
    add ax, {work_limit:#06x}
    sub ax, 0x0484
    mov [0x4796], ax

    mov ax, [0x4796]
    sub ax, [0x479e]
    mov [0x4794], ax

    mov ax, [0x4794]
    sub ax, [0x478e]
    sub ax, [0x479a]
    mov bx, 0x7f5f

    ; The copied loader still reads the BASIC keyword table at F200:65A5.
    ; Keep the 325 page mapped while tokenizing the source file.
    mov al, {bank:#04x}
    out 0x17, al
    call {reloc_segment:#06x}:{load_wrapper_offset:#06x}
    mov [cs:load_result], ax
    mov [0x4798], ax

    cmp word [cs:load_result], 0xffff
    jne .load_ok
    show_message load_fail_message
    retf

.load_ok:
    show_message load_ok_message

    mov al, {bank:#04x}
    out 0x17, al

    call {mapped_wrapper_segment:#06x}:{init_83eb_wrapper_offset:#06x}
    call {mapped_wrapper_segment:#06x}:{init_7c82_wrapper_offset:#06x}
    call {mapped_wrapper_segment:#06x}:{init_7c1e_wrapper_offset:#06x}

    show_message before_letter_message
    call {mapped_wrapper_segment:#06x}:{letter_wrapper_offset:#06x}
    mov [cs:letter_result], ax
    show_message after_letter_message

    mov al, 0x00
    out 0x17, al
    retf

load_result:
    dw 0
letter_result:
    dw 0
before_load_message:
    db {before_load_message_bytes}
load_ok_message:
    db {load_ok_message_bytes}
load_fail_message:
    db {load_fail_message_bytes}
before_letter_message:
    db "BEFORE 84D5 - PRESS KEY", 0
after_letter_message:
    db "AFTER 84D5 - PRESS KEY", 0
fixed_path:
    db {path_bytes}
fixed_path_end:
reloc_image:
    db {reloc_bytes}
"""


BASIC_MAPPED_WRAPPER_ASM = """\
bits 16
org {routine_offset:#06x}

entry:
    push cs
    pop ds
    xor ax, ax
    mov es, ax
    mov si, fixed_path
    mov di, 0x7f5f
    mov cx, fixed_path_end - fixed_path
    cld
    rep movsb

    push ds
    push es
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov byte [0x7653], 0x01
    mov si, 0x1000
    mov di, {lcd_base:#06x}
    mov cx, 0x0800
    cld
    rep movsw
    pop es
    pop ds

    mov al, {lcd_value:#04x}
    out 0x00, al

    mov ax, {work_segment:#06x}
    mov es, ax
    xor ax, ax
    mov ds, ax

    mov bx, {work_limit:#06x}
    mov ax, {work_segment:#06x}
    mov cx, 0x7f5f
    call 0xf200:0x7dab

    mov al, {restore_lcd_value:#04x}
    out 0x00, al
    push ds
    xor ax, ax
    mov ds, ax
    mov byte [0x7653], 0x00
    pop ds
    retf

fixed_path:
    db {path_bytes}
fixed_path_end:
"""


BASIC_PROBE_MAPPED_WRAPPER_ASM = """\
bits 16
org {routine_offset:#06x}

entry:
    mov ax, before_message
    mov bx, {routine_segment:#06x}
    mov cx, {x_pos:#06x}
    mov dx, {y_pos:#06x}
    call 0xf200:0x0004
    call 0xf200:0x0030

    push cs
    pop ds
    xor ax, ax
    mov es, ax
    mov si, fixed_path
    mov di, 0x7f5f
    mov cx, fixed_path_end - fixed_path
    cld
    rep movsb

    push ds
    push es
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov byte [0x7653], 0x01
    mov si, 0x1000
    mov di, {lcd_base:#06x}
    mov cx, 0x0800
    cld
    rep movsw
    pop es
    pop ds

    mov al, {lcd_value:#04x}
    out 0x00, al

    mov ax, {work_segment:#06x}
    mov es, ax
    xor ax, ax
    mov ds, ax

    mov bx, {work_limit:#06x}
    mov ax, {work_segment:#06x}
    mov cx, 0x7f5f
    call 0xf200:0x7dab

    mov al, {restore_lcd_value:#04x}
    out 0x00, al
    push ds
    xor ax, ax
    mov ds, ax
    mov byte [0x7653], 0x00
    pop ds

    xor ax, ax
    mov ds, ax
    mov ax, after_message
    mov bx, {routine_segment:#06x}
    mov cx, {x_pos:#06x}
    mov dx, {y_pos:#06x}
    call 0xf200:0x0004
    call 0xf200:0x0030
    retf

before_message:
    db {before_message_bytes}
after_message:
    db {after_message_bytes}
fixed_path:
    db {path_bytes}
fixed_path_end:
"""


BASIC_STEPS_MAPPED_WRAPPER_ASM = """\
bits 16
org {routine_offset:#06x}

%macro show_step 1
    push ds
    xor ax, ax
    mov ds, ax
    mov ax, %1
    mov bx, {routine_segment:#06x}
    mov cx, {x_pos:#06x}
    mov dx, {y_pos:#06x}
    call 0xf200:0x0004
    call 0xf200:0x0030
    pop ds
%endmacro

entry:
    show_step step_entry

    push cs
    pop ds
    xor ax, ax
    mov es, ax
    mov si, fixed_path
    mov di, 0x7f5f
    mov cx, fixed_path_end - fixed_path
    cld
    rep movsb
    show_step step_path

    push ds
    xor ax, ax
    mov ds, ax
    mov byte [0x7653], 0x01
    pop ds
    show_step step_flag

    mov ax, {work_segment:#06x}
    mov es, ax
    xor ax, ax
    mov ds, ax
    mov bx, {work_limit:#06x}
    mov ax, {work_segment:#06x}
    mov cx, 0x7f5f
    show_step step_regs

    show_step step_lcd_next
    push ds
    push es
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov si, 0x1000
    mov di, {lcd_base:#06x}
    mov cx, 0x0800
    cld
    rep movsw
    pop es
    pop ds
    mov al, {lcd_value:#04x}
    out 0x00, al
    call 0xf200:0x0030
    mov al, {restore_lcd_value:#04x}
    out 0x00, al
    show_step step_lcd_back

    show_step step_ready
    push ds
    xor ax, ax
    mov ds, ax
    mov byte [0x7653], 0x00
    pop ds
    retf

step_entry:
    db "STEP 1 WRAPPER ENTRY", 0
step_path:
    db "STEP 2 PATH COPIED", 0
step_flag:
    db "STEP 3 BASIC FLAG SET", 0
step_regs:
    db "STEP 4 REGS READY", 0
step_lcd_next:
    db "STEP 5 LCD SWITCH NEXT", 0
step_lcd_back:
    db "STEP 6 LCD RESTORED", 0
step_ready:
    db "STEP 7 WOULD CALL BASIC", 0
fixed_path:
    db {path_bytes}
fixed_path_end:
"""


SMOKE_STUB_ASM = """\
bits 16
org 0

    dw 0xA4F0
    dw 0x1997
    dw entry
    dw 0x0A4F

entry:
    xor ax, ax
    mov ds, ax

    mov ax, message
    push cs
    pop bx
    mov cx, {x_pos:#06x}
    mov dx, {y_pos:#06x}
    call far [0x0204]

    call far [0x0230]
    retf

message:
    db {message_bytes}
"""


SMOKE_MAP_STUB_ASM = """\
bits 16
org 0

    dw 0xA4F0
    dw 0x1997
    dw entry
    dw 0x0A4F

entry:
    xor ax, ax
    mov ds, ax

    mov al, {bank:#04x}
    out 0x17, al

    mov ax, {message_offset:#06x}
    mov bx, {message_segment:#06x}
    mov cx, {x_pos:#06x}
    mov dx, {y_pos:#06x}
    call far [0x0204]

    call far [0x0230]

    mov al, 0x00
    out 0x17, al
    retf
"""


SMOKE_EXEC_STUB_ASM = """\
bits 16
org 0

    dw 0xA4F0
    dw 0x1997
    dw entry
    dw 0x0A4F

entry:
    xor ax, ax
    mov ds, ax

    mov al, {bank:#04x}
    out 0x17, al

    call {routine_segment:#06x}:{routine_offset:#06x}

    mov al, 0x00
    out 0x17, al
    retf
"""


F200_SMOKE_ROUTINE_ASM = """\
bits 16
org {routine_offset:#06x}

entry:
    mov ax, message
    mov bx, {routine_segment:#06x}
    mov cx, {x_pos:#06x}
    mov dx, {y_pos:#06x}
    call 0xf200:0x0004

    call 0xf200:0x0030
    retf

message:
    db {message_bytes}
"""


MAPPED_ROUTINE_ASM = """\
bits 16
org {routine_offset:#06x}

entry:
    push ds
    xor ax, ax
    mov ds, ax

    mov ax, message
    mov bx, {routine_segment:#06x}
    mov cx, {x_pos:#06x}
    mov dx, {y_pos:#06x}
    call far [0x0204]

    call far [0x0230]
    pop ds
    retf

message:
    db {message_bytes}
"""


def read_word(data: bytes | bytearray, offset: int) -> int:
    return struct.unpack_from("<H", data, offset)[0]


def write_word(data: bytearray, offset: int, value: int) -> None:
    struct.pack_into("<H", data, offset, value & 0xFFFF)


def write_dword(data: bytearray, offset: int, value: int) -> None:
    struct.pack_into("<I", data, offset, value & 0xFFFFFFFF)


def root_offset(geometry: int) -> int:
    # Matches C000:3B01/C000:2D44 for card storage.
    first_root_sector = 3 * geometry + 1
    return first_root_sector * SECTOR_SIZE


def data_offset(geometry: int, cluster: int) -> int:
    # Matches C000:3994 for cluster-to-sector conversion.
    first_data_sector = 3 * geometry + 0x21
    return (first_data_sector + (cluster - 2)) * SECTOR_SIZE


def max_cluster(geometry: int) -> int:
    # C000:3BBD..3BE9 stores this value in [6FAA].
    return (geometry * 0x100) - (3 * geometry + 0x1F)


def get_fat12(data: bytes | bytearray, cluster: int) -> int:
    fat = SECTOR_SIZE
    pos = fat + (cluster * 3) // 2
    pair = data[pos] | (data[pos + 1] << 8)
    if cluster & 1:
        return (pair >> 4) & 0x0FFF
    return pair & 0x0FFF


def set_fat12(data: bytearray, cluster: int, value: int) -> None:
    fat = SECTOR_SIZE
    pos = fat + (cluster * 3) // 2
    value &= 0x0FFF
    pair = data[pos] | (data[pos + 1] << 8)
    if cluster & 1:
        pair = (pair & 0x000F) | (value << 4)
    else:
        pair = (pair & 0xF000) | value
    data[pos] = pair & 0xFF
    data[pos + 1] = (pair >> 8) & 0xFF


def encode_83(name: str) -> bytes:
    base, dot, ext = name.partition(".")
    if not dot:
        ext = ""
    base = base.upper()
    ext = ext.upper()
    if not (1 <= len(base) <= 8 and len(ext) <= 3):
        raise ValueError(f"not an 8.3 filename: {name}")
    return base.encode("ascii").ljust(8, b" ") + ext.encode("ascii").ljust(3, b" ")


def find_root_entry(card: bytes | bytearray, geometry: int, raw_name: bytes, display_name: str) -> int:
    root = root_offset(geometry)
    for index in range(ROOT_SECTORS * SECTOR_SIZE // ROOT_ENTRY_SIZE):
        off = root + index * ROOT_ENTRY_SIZE
        first = card[off]
        if card[off : off + 11] == raw_name:
            raise ValueError(f"{display_name} already exists in image")
        if first in (0x00, 0xE5):
            return off
    raise ValueError("root directory is full")


def allocate_clusters(card: bytearray, geometry: int, size: int) -> list[int]:
    needed = max(1, math.ceil(size / SECTOR_SIZE))
    clusters: list[int] = []
    for cluster in range(2, max_cluster(geometry)):
        if get_fat12(card, cluster) == 0:
            clusters.append(cluster)
            if len(clusters) == needed:
                break
    if len(clusters) != needed:
        raise ValueError("not enough free clusters")
    for index, cluster in enumerate(clusters):
        set_fat12(card, cluster, clusters[index + 1] if index + 1 < len(clusters) else 0xFFF)
    return clusters


def write_file(card: bytearray, geometry: int, name: str, payload: bytes) -> None:
    raw_name = encode_83(name)
    entry = find_root_entry(card, geometry, raw_name, name)
    clusters = allocate_clusters(card, geometry, len(payload))

    for index, cluster in enumerate(clusters):
        off = data_offset(geometry, cluster)
        chunk = payload[index * SECTOR_SIZE : (index + 1) * SECTOR_SIZE]
        card[off : off + SECTOR_SIZE] = b"\x00" * SECTOR_SIZE
        card[off : off + len(chunk)] = chunk

    card[entry : entry + ROOT_ENTRY_SIZE] = b"\x00" * ROOT_ENTRY_SIZE
    card[entry : entry + 11] = raw_name
    card[entry + 11] = 0x20
    write_word(card, entry + 0x1A, clusters[0])
    write_dword(card, entry + 0x1C, len(payload))


def build_basic_file(lines: list[str]) -> bytes:
    source = b"".join(line.encode("ascii") + b"\x0c" for line in lines)
    if len(EDITOR_HEADER) > 0xFF:
        raise ValueError("editor header is too long")
    return bytes([0xFF, len(EDITOR_HEADER)]) + EDITOR_HEADER + source


def assemble(asm: str) -> bytes:
    with tempfile.TemporaryDirectory() as tmpdir:
        asm_path = Path(tmpdir) / "eromcard.asm"
        bin_path = Path(tmpdir) / "eromcard.x"
        asm_path.write_text(asm, encoding="ascii")
        subprocess.run(["nasm", "-f", "bin", "-o", str(bin_path), str(asm_path)], check=True)
        return bin_path.read_bytes()


def build_basic_stub(
    path: str,
    bank: int,
    work_segment: int,
    work_limit: int,
    lcd_value: int,
    restore_lcd_value: int,
) -> bytes:
    path_literal = ", ".join(f"0x{byte:02x}" for byte in path.encode("ascii") + b"\x00")
    asm = BASIC_STUB_ASM.format(
        bank=bank,
        path_bytes=path_literal,
        work_segment=work_segment,
        work_limit=work_limit,
        lcd_value=lcd_value,
        restore_lcd_value=restore_lcd_value,
        lcd_base=(lcd_value << 9) & 0xFFFF,
    )
    return assemble(asm)


def build_basic_exec_stub(bank: int, routine_segment: int, routine_offset: int) -> bytes:
    asm = BASIC_EXEC_STUB_ASM.format(
        bank=bank,
        routine_segment=routine_segment,
        routine_offset=routine_offset,
    )
    return assemble(asm)


def build_basic_load_probe_stub(
    path: str,
    bank: int,
    routine_segment: int,
    routine_offset: int,
    work_segment: int,
    work_limit: int,
    before_message: str,
    ok_message: str,
    fail_message: str,
    x_pos: int,
    y_pos: int,
) -> bytes:
    path_literal = ", ".join(f"0x{byte:02x}" for byte in path.encode("ascii") + b"\x00")
    before_literal = ", ".join(f"0x{byte:02x}" for byte in before_message.encode("ascii") + b"\x00")
    ok_literal = ", ".join(f"0x{byte:02x}" for byte in ok_message.encode("ascii") + b"\x00")
    fail_literal = ", ".join(f"0x{byte:02x}" for byte in fail_message.encode("ascii") + b"\x00")
    asm = BASIC_LOAD_PROBE_STUB_ASM.format(
        path_bytes=path_literal,
        bank=bank,
        routine_segment=routine_segment,
        routine_offset=routine_offset,
        work_segment=work_segment,
        work_limit=work_limit,
        before_message_bytes=before_literal,
        ok_message_bytes=ok_literal,
        fail_message_bytes=fail_literal,
        x_pos=x_pos,
        y_pos=y_pos,
    )
    return assemble(asm)


def build_basic_load_probe_routine(routine_offset: int) -> bytes:
    asm = BASIC_LOAD_PROBE_ROUTINE_ASM.format(routine_offset=routine_offset)
    return assemble(asm)


def build_basic_file_probe_stub(
    path: str,
    before_message: str,
    open_ok_message: str,
    open_fail_message: str,
    read_ok_message: str,
    read_fail_message: str,
    x_pos: int,
    y_pos: int,
) -> bytes:
    path_literal = ", ".join(f"0x{byte:02x}" for byte in path.encode("ascii") + b"\x00")
    before_literal = ", ".join(f"0x{byte:02x}" for byte in before_message.encode("ascii") + b"\x00")
    open_ok_literal = ", ".join(f"0x{byte:02x}" for byte in open_ok_message.encode("ascii") + b"\x00")
    open_fail_literal = ", ".join(f"0x{byte:02x}" for byte in open_fail_message.encode("ascii") + b"\x00")
    read_ok_literal = ", ".join(f"0x{byte:02x}" for byte in read_ok_message.encode("ascii") + b"\x00")
    read_fail_literal = ", ".join(f"0x{byte:02x}" for byte in read_fail_message.encode("ascii") + b"\x00")
    asm = BASIC_FILE_PROBE_STUB_ASM.format(
        path_bytes=path_literal,
        before_message_bytes=before_literal,
        open_ok_message_bytes=open_ok_literal,
        open_fail_message_bytes=open_fail_literal,
        read_ok_message_bytes=read_ok_literal,
        read_fail_message_bytes=read_fail_literal,
        x_pos=x_pos,
        y_pos=y_pos,
    )
    return assemble(asm)


def patch_f200_calls_for_low_vectors(data: bytes) -> tuple[bytes, int]:
    patched = bytearray(data)
    patched_count = 0
    for off in range(len(patched) - 4):
        if patched[off] != 0x9A or patched[off + 3] != 0x00 or patched[off + 4] != 0xF2:
            continue
        target = patched[off + 1] | (patched[off + 2] << 8)
        vector = 0x0204 + target
        if target > 0x9C or target % 4:
            raise ValueError(f"unmapped F200 call in RAM loader slice at 0x{off:04x}: F200:{target:04x}")
        patched[off : off + 5] = bytes((0xFF, 0x1E, vector & 0xFF, vector >> 8, 0x90))
        patched_count += 1
    if patched_count < 5:
        raise ValueError(f"expected to patch at least 5 F200 service calls, patched {patched_count}")
    return bytes(patched), patched_count


def near_to_far_wrapper(target: int, wrapper_offset: int) -> bytes:
    wrapper_return = wrapper_offset + 7
    if wrapper_return > 0xFFFF:
        raise ValueError("RAM wrapper return offset is outside the copied segment")
    return bytes((0x68, wrapper_return & 0xFF, wrapper_return >> 8, 0x68, target & 0xFF, target >> 8, 0xC3, 0xCB))


def build_basic_ram_load_probe_stub(
    rom: bytes,
    path: str,
    reloc_segment: int,
    reloc_size: int,
    work_segment: int,
    work_limit: int,
    before_message: str,
    ok_message: str,
    fail_message: str,
    x_pos: int,
    y_pos: int,
) -> bytes:
    if reloc_size & 1:
        raise ValueError("RAM loader slice size must be even")
    reloc, _patched_count = patch_f200_calls_for_low_vectors(rom[0x72000 : 0x72000 + reloc_size])
    wrapper_offset = reloc_size
    wrapper = near_to_far_wrapper(0x31B6, wrapper_offset)
    reloc += wrapper
    if len(reloc) & 1:
        reloc += b"\x90"
    path_literal = ", ".join(f"0x{byte:02x}" for byte in path.encode("ascii") + b"\x00")
    before_literal = ", ".join(f"0x{byte:02x}" for byte in before_message.encode("ascii") + b"\x00")
    ok_literal = ", ".join(f"0x{byte:02x}" for byte in ok_message.encode("ascii") + b"\x00")
    fail_literal = ", ".join(f"0x{byte:02x}" for byte in fail_message.encode("ascii") + b"\x00")
    reloc_literal = ", ".join(f"0x{byte:02x}" for byte in reloc)
    asm = BASIC_RAM_LOAD_PROBE_STUB_ASM.format(
        path_bytes=path_literal,
        reloc_bytes=reloc_literal,
        reloc_segment=reloc_segment,
        reloc_words=len(reloc) // 2,
        wrapper_offset=wrapper_offset,
        work_segment=work_segment,
        work_limit=work_limit,
        before_message_bytes=before_literal,
        ok_message_bytes=ok_literal,
        fail_message_bytes=fail_literal,
        x_pos=x_pos,
        y_pos=y_pos,
    )
    return assemble(asm)


def build_basic_init_steps_probe_stub(
    rom: bytes,
    path: str,
    bank: int,
    reloc_segment: int,
    reloc_size: int,
    mapped_wrapper_segment: int,
    init_83eb_wrapper_offset: int,
    init_7c82_wrapper_offset: int,
    init_7c1e_wrapper_offset: int,
    work_segment: int,
    work_limit: int,
    before_load_message: str,
    load_ok_message: str,
    load_fail_message: str,
    x_pos: int,
    y_pos: int,
) -> bytes:
    if reloc_size & 1:
        raise ValueError("RAM init slice size must be even")
    reloc, _patched_count = patch_f200_calls_for_low_vectors(rom[0x72000 : 0x72000 + reloc_size])
    load_wrapper_offset = len(reloc)
    reloc += near_to_far_wrapper(0x31B6, load_wrapper_offset)
    if len(reloc) & 1:
        reloc += b"\x90"
    path_literal = ", ".join(f"0x{byte:02x}" for byte in path.encode("ascii") + b"\x00")
    before_literal = ", ".join(f"0x{byte:02x}" for byte in before_load_message.encode("ascii") + b"\x00")
    ok_literal = ", ".join(f"0x{byte:02x}" for byte in load_ok_message.encode("ascii") + b"\x00")
    fail_literal = ", ".join(f"0x{byte:02x}" for byte in load_fail_message.encode("ascii") + b"\x00")
    reloc_literal = ", ".join(f"0x{byte:02x}" for byte in reloc)
    asm = BASIC_INIT_STEPS_PROBE_STUB_ASM.format(
        path_bytes=path_literal,
        reloc_bytes=reloc_literal,
        bank=bank,
        reloc_segment=reloc_segment,
        reloc_words=len(reloc) // 2,
        load_wrapper_offset=load_wrapper_offset,
        mapped_wrapper_segment=mapped_wrapper_segment,
        init_83eb_wrapper_offset=init_83eb_wrapper_offset,
        init_7c82_wrapper_offset=init_7c82_wrapper_offset,
        init_7c1e_wrapper_offset=init_7c1e_wrapper_offset,
        work_segment=work_segment,
        work_limit=work_limit,
        before_load_message_bytes=before_literal,
        load_ok_message_bytes=ok_literal,
        load_fail_message_bytes=fail_literal,
        x_pos=x_pos,
        y_pos=y_pos,
    )
    return assemble(asm)


def build_basic_runtime_probe_stub(
    rom: bytes,
    path: str,
    bank: int,
    reloc_segment: int,
    reloc_size: int,
    mapped_wrapper_segment: int,
    init_83eb_wrapper_offset: int,
    init_7c82_wrapper_offset: int,
    init_7c1e_wrapper_offset: int,
    runtime_wrapper_offset: int,
    work_segment: int,
    work_limit: int,
    lcd_value: int,
    restore_lcd_value: int,
    before_load_message: str,
    load_ok_message: str,
    load_fail_message: str,
    x_pos: int,
    y_pos: int,
) -> bytes:
    if reloc_size & 1:
        raise ValueError("RAM runtime-probe slice size must be even")
    reloc, _patched_count = patch_f200_calls_for_low_vectors(rom[0x72000 : 0x72000 + reloc_size])
    load_wrapper_offset = len(reloc)
    reloc += near_to_far_wrapper(0x31B6, load_wrapper_offset)
    if len(reloc) & 1:
        reloc += b"\x90"
    path_literal = ", ".join(f"0x{byte:02x}" for byte in path.encode("ascii") + b"\x00")
    before_literal = ", ".join(f"0x{byte:02x}" for byte in before_load_message.encode("ascii") + b"\x00")
    ok_literal = ", ".join(f"0x{byte:02x}" for byte in load_ok_message.encode("ascii") + b"\x00")
    fail_literal = ", ".join(f"0x{byte:02x}" for byte in load_fail_message.encode("ascii") + b"\x00")
    reloc_literal = ", ".join(f"0x{byte:02x}" for byte in reloc)
    asm = BASIC_RUNTIME_PROBE_STUB_ASM.format(
        path_bytes=path_literal,
        reloc_bytes=reloc_literal,
        bank=bank,
        reloc_segment=reloc_segment,
        reloc_words=len(reloc) // 2,
        load_wrapper_offset=load_wrapper_offset,
        mapped_wrapper_segment=mapped_wrapper_segment,
        init_83eb_wrapper_offset=init_83eb_wrapper_offset,
        init_7c82_wrapper_offset=init_7c82_wrapper_offset,
        init_7c1e_wrapper_offset=init_7c1e_wrapper_offset,
        runtime_wrapper_offset=runtime_wrapper_offset,
        work_segment=work_segment,
        work_limit=work_limit,
        lcd_value=lcd_value,
        restore_lcd_value=restore_lcd_value,
        lcd_base=(lcd_value << 9) & 0xFFFF,
        before_load_message_bytes=before_literal,
        load_ok_message_bytes=ok_literal,
        load_fail_message_bytes=fail_literal,
        x_pos=x_pos,
        y_pos=y_pos,
    )
    return assemble(asm)


def build_basic_runtime_steps_probe_stub(
    rom: bytes,
    path: str,
    bank: int,
    reloc_segment: int,
    reloc_size: int,
    mapped_wrapper_segment: int,
    init_83eb_wrapper_offset: int,
    init_7c82_wrapper_offset: int,
    init_7c1e_wrapper_offset: int,
    poll_wrapper_offset: int,
    token_wrapper_offset: int,
    work_segment: int,
    work_limit: int,
    before_load_message: str,
    load_ok_message: str,
    load_fail_message: str,
    x_pos: int,
    y_pos: int,
) -> bytes:
    if reloc_size & 1:
        raise ValueError("RAM runtime-steps probe slice size must be even")
    reloc, _patched_count = patch_f200_calls_for_low_vectors(rom[0x72000 : 0x72000 + reloc_size])
    load_wrapper_offset = len(reloc)
    reloc += near_to_far_wrapper(0x31B6, load_wrapper_offset)
    if len(reloc) & 1:
        reloc += b"\x90"
    path_literal = ", ".join(f"0x{byte:02x}" for byte in path.encode("ascii") + b"\x00")
    before_literal = ", ".join(f"0x{byte:02x}" for byte in before_load_message.encode("ascii") + b"\x00")
    ok_literal = ", ".join(f"0x{byte:02x}" for byte in load_ok_message.encode("ascii") + b"\x00")
    fail_literal = ", ".join(f"0x{byte:02x}" for byte in load_fail_message.encode("ascii") + b"\x00")
    reloc_literal = ", ".join(f"0x{byte:02x}" for byte in reloc)
    asm = BASIC_RUNTIME_STEPS_PROBE_STUB_ASM.format(
        path_bytes=path_literal,
        reloc_bytes=reloc_literal,
        bank=bank,
        reloc_segment=reloc_segment,
        reloc_words=len(reloc) // 2,
        load_wrapper_offset=load_wrapper_offset,
        mapped_wrapper_segment=mapped_wrapper_segment,
        init_83eb_wrapper_offset=init_83eb_wrapper_offset,
        init_7c82_wrapper_offset=init_7c82_wrapper_offset,
        init_7c1e_wrapper_offset=init_7c1e_wrapper_offset,
        poll_wrapper_offset=poll_wrapper_offset,
        token_wrapper_offset=token_wrapper_offset,
        work_segment=work_segment,
        work_limit=work_limit,
        before_load_message_bytes=before_literal,
        load_ok_message_bytes=ok_literal,
        load_fail_message_bytes=fail_literal,
        x_pos=x_pos,
        y_pos=y_pos,
    )
    return assemble(asm)


def build_basic_runtime_branch_probe_stub(
    rom: bytes,
    path: str,
    bank: int,
    reloc_segment: int,
    reloc_size: int,
    mapped_wrapper_segment: int,
    init_83eb_wrapper_offset: int,
    init_7c82_wrapper_offset: int,
    init_7c1e_wrapper_offset: int,
    poll_wrapper_offset: int,
    token_wrapper_offset: int,
    work_segment: int,
    work_limit: int,
    before_load_message: str,
    load_ok_message: str,
    load_fail_message: str,
    x_pos: int,
    y_pos: int,
) -> bytes:
    if reloc_size & 1:
        raise ValueError("RAM runtime-branch probe slice size must be even")
    reloc, _patched_count = patch_f200_calls_for_low_vectors(rom[0x72000 : 0x72000 + reloc_size])
    load_wrapper_offset = len(reloc)
    reloc += near_to_far_wrapper(0x31B6, load_wrapper_offset)
    if len(reloc) & 1:
        reloc += b"\x90"
    path_literal = ", ".join(f"0x{byte:02x}" for byte in path.encode("ascii") + b"\x00")
    before_literal = ", ".join(f"0x{byte:02x}" for byte in before_load_message.encode("ascii") + b"\x00")
    ok_literal = ", ".join(f"0x{byte:02x}" for byte in load_ok_message.encode("ascii") + b"\x00")
    fail_literal = ", ".join(f"0x{byte:02x}" for byte in load_fail_message.encode("ascii") + b"\x00")
    reloc_literal = ", ".join(f"0x{byte:02x}" for byte in reloc)
    asm = BASIC_RUNTIME_BRANCH_PROBE_STUB_ASM.format(
        path_bytes=path_literal,
        reloc_bytes=reloc_literal,
        bank=bank,
        reloc_segment=reloc_segment,
        reloc_words=len(reloc) // 2,
        load_wrapper_offset=load_wrapper_offset,
        mapped_wrapper_segment=mapped_wrapper_segment,
        init_83eb_wrapper_offset=init_83eb_wrapper_offset,
        init_7c82_wrapper_offset=init_7c82_wrapper_offset,
        init_7c1e_wrapper_offset=init_7c1e_wrapper_offset,
        poll_wrapper_offset=poll_wrapper_offset,
        token_wrapper_offset=token_wrapper_offset,
        work_segment=work_segment,
        work_limit=work_limit,
        before_load_message_bytes=before_literal,
        load_ok_message_bytes=ok_literal,
        load_fail_message_bytes=fail_literal,
        x_pos=x_pos,
        y_pos=y_pos,
    )
    return assemble(asm)


def build_basic_runtime_letter_probe_stub(
    rom: bytes,
    path: str,
    bank: int,
    reloc_segment: int,
    reloc_size: int,
    mapped_wrapper_segment: int,
    init_83eb_wrapper_offset: int,
    init_7c82_wrapper_offset: int,
    init_7c1e_wrapper_offset: int,
    letter_wrapper_offset: int,
    work_segment: int,
    work_limit: int,
    before_load_message: str,
    load_ok_message: str,
    load_fail_message: str,
    x_pos: int,
    y_pos: int,
) -> bytes:
    if reloc_size & 1:
        raise ValueError("RAM runtime-letter probe slice size must be even")
    reloc, _patched_count = patch_f200_calls_for_low_vectors(rom[0x72000 : 0x72000 + reloc_size])
    load_wrapper_offset = len(reloc)
    reloc += near_to_far_wrapper(0x31B6, load_wrapper_offset)
    if len(reloc) & 1:
        reloc += b"\x90"
    path_literal = ", ".join(f"0x{byte:02x}" for byte in path.encode("ascii") + b"\x00")
    before_literal = ", ".join(f"0x{byte:02x}" for byte in before_load_message.encode("ascii") + b"\x00")
    ok_literal = ", ".join(f"0x{byte:02x}" for byte in load_ok_message.encode("ascii") + b"\x00")
    fail_literal = ", ".join(f"0x{byte:02x}" for byte in load_fail_message.encode("ascii") + b"\x00")
    reloc_literal = ", ".join(f"0x{byte:02x}" for byte in reloc)
    asm = BASIC_RUNTIME_LETTER_PROBE_STUB_ASM.format(
        path_bytes=path_literal,
        reloc_bytes=reloc_literal,
        bank=bank,
        reloc_segment=reloc_segment,
        reloc_words=len(reloc) // 2,
        load_wrapper_offset=load_wrapper_offset,
        mapped_wrapper_segment=mapped_wrapper_segment,
        init_83eb_wrapper_offset=init_83eb_wrapper_offset,
        init_7c82_wrapper_offset=init_7c82_wrapper_offset,
        init_7c1e_wrapper_offset=init_7c1e_wrapper_offset,
        letter_wrapper_offset=letter_wrapper_offset,
        work_segment=work_segment,
        work_limit=work_limit,
        before_load_message_bytes=before_literal,
        load_ok_message_bytes=ok_literal,
        load_fail_message_bytes=fail_literal,
        x_pos=x_pos,
        y_pos=y_pos,
    )
    return assemble(asm)


def build_basic_mapped_wrapper(
    path: str,
    routine_segment: int,
    routine_offset: int,
    work_segment: int,
    work_limit: int,
    lcd_value: int,
    restore_lcd_value: int,
) -> bytes:
    path_literal = ", ".join(f"0x{byte:02x}" for byte in path.encode("ascii") + b"\x00")
    asm = BASIC_MAPPED_WRAPPER_ASM.format(
        path_bytes=path_literal,
        routine_segment=routine_segment,
        routine_offset=routine_offset,
        work_segment=work_segment,
        work_limit=work_limit,
        lcd_value=lcd_value,
        restore_lcd_value=restore_lcd_value,
        lcd_base=(lcd_value << 9) & 0xFFFF,
    )
    return assemble(asm)


def build_basic_probe_mapped_wrapper(
    path: str,
    routine_segment: int,
    routine_offset: int,
    work_segment: int,
    work_limit: int,
    before_message: str,
    after_message: str,
    x_pos: int,
    y_pos: int,
    lcd_value: int,
    restore_lcd_value: int,
) -> bytes:
    path_literal = ", ".join(f"0x{byte:02x}" for byte in path.encode("ascii") + b"\x00")
    before_literal = ", ".join(f"0x{byte:02x}" for byte in before_message.encode("ascii") + b"\x00")
    after_literal = ", ".join(f"0x{byte:02x}" for byte in after_message.encode("ascii") + b"\x00")
    asm = BASIC_PROBE_MAPPED_WRAPPER_ASM.format(
        path_bytes=path_literal,
        before_message_bytes=before_literal,
        after_message_bytes=after_literal,
        routine_segment=routine_segment,
        routine_offset=routine_offset,
        work_segment=work_segment,
        work_limit=work_limit,
        x_pos=x_pos,
        y_pos=y_pos,
        lcd_value=lcd_value,
        restore_lcd_value=restore_lcd_value,
        lcd_base=(lcd_value << 9) & 0xFFFF,
    )
    return assemble(asm)


def build_basic_steps_mapped_wrapper(
    path: str,
    routine_segment: int,
    routine_offset: int,
    work_segment: int,
    work_limit: int,
    lcd_value: int,
    restore_lcd_value: int,
    x_pos: int,
    y_pos: int,
) -> bytes:
    path_literal = ", ".join(f"0x{byte:02x}" for byte in path.encode("ascii") + b"\x00")
    asm = BASIC_STEPS_MAPPED_WRAPPER_ASM.format(
        path_bytes=path_literal,
        routine_segment=routine_segment,
        routine_offset=routine_offset,
        work_segment=work_segment,
        work_limit=work_limit,
        lcd_value=lcd_value,
        restore_lcd_value=restore_lcd_value,
        lcd_base=(lcd_value << 9) & 0xFFFF,
        x_pos=x_pos,
        y_pos=y_pos,
    )
    return assemble(asm)


def build_smoke_stub(message: str, x_pos: int, y_pos: int) -> bytes:
    message_literal = ", ".join(f"0x{byte:02x}" for byte in message.encode("ascii") + b"\x00")
    asm = SMOKE_STUB_ASM.format(
        message_bytes=message_literal,
        x_pos=x_pos,
        y_pos=y_pos,
    )
    return assemble(asm)


def build_smoke_map_stub(bank: int, message_segment: int, message_offset: int, x_pos: int, y_pos: int) -> bytes:
    asm = SMOKE_MAP_STUB_ASM.format(
        bank=bank,
        message_segment=message_segment,
        message_offset=message_offset,
        x_pos=x_pos,
        y_pos=y_pos,
    )
    return assemble(asm)


def build_smoke_exec_stub(bank: int, routine_segment: int, routine_offset: int) -> bytes:
    asm = SMOKE_EXEC_STUB_ASM.format(
        bank=bank,
        routine_segment=routine_segment,
        routine_offset=routine_offset,
    )
    return assemble(asm)


def build_mapped_routine(message: str, routine_segment: int, routine_offset: int, x_pos: int, y_pos: int) -> bytes:
    message_literal = ", ".join(f"0x{byte:02x}" for byte in message.encode("ascii") + b"\x00")
    asm = MAPPED_ROUTINE_ASM.format(
        message_bytes=message_literal,
        routine_segment=routine_segment,
        routine_offset=routine_offset,
        x_pos=x_pos,
        y_pos=y_pos,
    )
    return assemble(asm)


def build_f200_smoke_routine(message: str, routine_segment: int, routine_offset: int, x_pos: int, y_pos: int) -> bytes:
    message_literal = ", ".join(f"0x{byte:02x}" for byte in message.encode("ascii") + b"\x00")
    asm = F200_SMOKE_ROUTINE_ASM.format(
        message_bytes=message_literal,
        routine_segment=routine_segment,
        routine_offset=routine_offset,
        x_pos=x_pos,
        y_pos=y_pos,
    )
    return assemble(asm)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rom325", default="../tmp/dw325 - 2_0US.BIN", help="DreamWriter 325 ROM image")
    parser.add_argument("--card-in", default="/tmp/dw-card-1m.bin", help="formatted SRAM card image")
    parser.add_argument("--card-out", default="/tmp/dw-card-1m-basic.bin", help="output SRAM card image")
    parser.add_argument(
        "--stub",
        choices=(
            "basic",
            "basic-exec",
            "basic-file-probe",
            "basic-init-steps-probe",
            "basic-load-probe",
            "basic-probe",
            "basic-ram-load-probe",
            "basic-runtime-branch-probe",
            "basic-runtime-letter-probe",
            "basic-runtime-probe",
            "basic-runtime-steps-probe",
            "basic-steps",
            "smoke",
            "smoke-map",
            "smoke-exec",
            "f200-smoke",
        ),
        default="basic",
        help="EROMCARD.X payload to generate",
    )
    parser.add_argument("--program-path", default="I:BASIC.BAS", help="fixed BASIC program path copied to 0x7F5F")
    parser.add_argument("--basic-name", default="BASIC.BAS", help="BASIC program filename to insert on the card")
    parser.add_argument(
        "--basic-line",
        action="append",
        default=None,
        help="BASIC source line to insert; repeat for multiple lines",
    )
    parser.add_argument("--basic-out", default="/tmp/BASIC.BAS", help="also write the generated BASIC file here")
    parser.add_argument("--work-segment", type=lambda s: int(s, 0), default=0x0800, help="BASIC work segment passed in AX/ES")
    parser.add_argument("--work-limit", type=lambda s: int(s, 0), default=0x2000, help="BASIC work byte limit passed in BX")
    parser.add_argument("--lcd-value", type=lambda s: int(s, 0), default=None, help="LCD scanout value for BASIC; defaults to work_segment >> 5")
    parser.add_argument("--restore-lcd-value", type=lambda s: int(s, 0), default=0x08, help="LCD scanout value restored after BASIC returns")
    parser.add_argument("--probe-before-message", default="BEFORE BASIC - PRESS KEY", help="message displayed before calling BASIC in --stub basic-probe")
    parser.add_argument("--probe-after-message", default="BASIC RETURNED - PRESS KEY", help="message displayed after BASIC returns in --stub basic-probe")
    parser.add_argument("--load-probe-before-message", default="BEFORE LOAD - PRESS KEY", help="message displayed before calling the BASIC file-loader probe")
    parser.add_argument("--load-probe-ok-message", default="LOAD OK - PRESS KEY", help="message displayed if the BASIC file-loader probe returns success")
    parser.add_argument("--load-probe-fail-message", default="LOAD FAILED - PRESS KEY", help="message displayed if the BASIC file-loader probe returns 0xffff")
    parser.add_argument("--load-probe-segment", type=lambda s: int(s, 0), default=0xF200, help="mapped segment for the in-F200 BASIC file-loader probe")
    parser.add_argument("--load-probe-offset", type=lambda s: int(s, 0), default=0xDE3A, help="mapped offset for the in-F200 BASIC file-loader probe")
    parser.add_argument("--file-probe-before-message", default="BEFORE FILE - PRESS KEY", help="message displayed before opening BASIC.BAS in --stub basic-file-probe")
    parser.add_argument("--file-probe-open-ok-message", default="OPEN OK - PRESS KEY", help="message displayed after opening BASIC.BAS in --stub basic-file-probe")
    parser.add_argument("--file-probe-open-fail-message", default="OPEN FAILED - PRESS KEY", help="message displayed if opening BASIC.BAS fails in --stub basic-file-probe")
    parser.add_argument("--file-probe-read-ok-message", default="READ OK - PRESS KEY", help="message displayed after reading BASIC.BAS in --stub basic-file-probe")
    parser.add_argument("--file-probe-read-fail-message", default="READ FAILED - PRESS KEY", help="message displayed if reading BASIC.BAS fails in --stub basic-file-probe")
    parser.add_argument("--ram-load-probe-before-message", default="BEFORE RAM LOAD - PRESS KEY", help="message displayed before calling the RAM-copied BASIC file-loader probe")
    parser.add_argument("--ram-load-probe-ok-message", default="RAM LOAD OK - PRESS KEY", help="message displayed if the RAM-copied BASIC file-loader probe returns success")
    parser.add_argument("--ram-load-probe-fail-message", default="RAM LOAD FAILED - PRESS KEY", help="message displayed if the RAM-copied BASIC file-loader probe returns 0xffff")
    parser.add_argument("--ram-load-probe-segment", type=lambda s: int(s, 0), default=0x1200, help="RAM segment where the 325 F200 loader/parser slice is copied")
    parser.add_argument("--ram-load-probe-size", type=lambda s: int(s, 0), default=0x5000, help="number of bytes copied from 325 F200:0000 for --stub basic-ram-load-probe")
    parser.add_argument("--init-steps-probe-size", type=lambda s: int(s, 0), default=0x5000, help="number of bytes copied from 325 F200:0000 for --stub basic-init-steps-probe")
    parser.add_argument("--init-wrapper-segment", type=lambda s: int(s, 0), default=0xF200, help="mapped segment holding post-load initializer/runtime wrappers")
    parser.add_argument("--init-wrapper-offset", type=lambda s: int(s, 0), default=0xDE3A, help="mapped offset for post-load initializer/runtime wrappers")
    parser.add_argument("--smoke-message", default="EROMCARD OK - PRESS KEY", help="message for --stub smoke")
    parser.add_argument("--smoke-x", type=lambda s: int(s, 0), default=0x00C0, help="x position for --stub smoke")
    parser.add_argument("--smoke-y", type=lambda s: int(s, 0), default=0x001C, help="y position for --stub smoke")
    parser.add_argument("--map-message", default="MAPPED PAGE OK - PRESS KEY", help="message patched into the mapped card page for --stub smoke-map")
    parser.add_argument("--map-segment", type=lambda s: int(s, 0), default=0xFF00, help="mapped top-window segment holding --map-message")
    parser.add_argument("--map-offset", type=lambda s: int(s, 0), default=0x0000, help="mapped top-window offset holding --map-message")
    parser.add_argument("--exec-message", default="MAPPED CODE OK - PRESS KEY", help="message displayed by mapped code for --stub smoke-exec")
    parser.add_argument("--exec-segment", type=lambda s: int(s, 0), default=0xFF00, help="mapped top-window code segment for --stub smoke-exec")
    parser.add_argument("--exec-offset", type=lambda s: int(s, 0), default=0x0000, help="mapped top-window code offset for --stub smoke-exec")
    parser.add_argument("--f200-message", default="F200 TRAMPOLINE OK - PRESS KEY", help="message displayed by mapped code for --stub f200-smoke")
    parser.add_argument("--f200-segment", type=lambda s: int(s, 0), default=0xFF00, help="mapped top-window code segment for --stub f200-smoke")
    parser.add_argument("--f200-offset", type=lambda s: int(s, 0), default=0x0000, help="mapped top-window code offset for --stub f200-smoke")
    parser.add_argument("--basic-exec-segment", type=lambda s: int(s, 0), default=0xFF00, help="mapped BASIC wrapper segment for --stub basic-exec")
    parser.add_argument("--basic-exec-offset", type=lambda s: int(s, 0), default=0x0000, help="mapped BASIC wrapper offset for --stub basic-exec")
    parser.add_argument("--card-page", type=lambda s: int(s, 0), default=4, help="128 KiB SRAM page for 325 high ROM")
    parser.add_argument("--bank", type=lambda s: int(s, 0), default=0x1B, help="bank value written to port 0x17")
    parser.add_argument("--x-out", default="/tmp/EROMCARD.X", help="also write the generated EROMCARD.X here")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    rom = Path(args.rom325).read_bytes()
    card = bytearray(Path(args.card_in).read_bytes())

    if read_word(card, 0) != 0x1997 or read_word(card, 2) != 0x0126:
        raise ValueError("input card image does not have a DreamWriter storage header")

    geometry = read_word(card, 4)
    high_page = bytearray(rom[0x60000:0x80000])
    if len(high_page) != CARD_PAGE_SIZE:
        raise ValueError("325 high ROM slice is not 128 KiB")
    work_base = (args.work_segment << 4) & 0xFFFF
    if args.work_limit < 0x0C84:
        raise ValueError("work limit is below the 325 BASIC minimum of 0x0C84 bytes")
    if work_base <= 0xA4F0 < work_base + args.work_limit:
        raise ValueError("selected BASIC work area overlaps the EROMCARD.X load address")
    lcd_value = (args.work_segment >> 5) if args.lcd_value is None else args.lcd_value
    if not 0 <= lcd_value <= 0xFF:
        raise ValueError("LCD scanout value must fit in one byte")
    if not 0 <= args.restore_lcd_value <= 0xFF:
        raise ValueError("restored LCD scanout value must fit in one byte")

    mapped_address = ((args.map_segment << 4) + args.map_offset) & 0xFFFFF
    mapped_page_offset = mapped_address - 0xE0000
    if args.stub == "smoke-map":
        if mapped_address < 0xE0000:
            raise ValueError("mapped smoke-test message must be in the 0xE0000..0xFFFFF window")
        map_payload = args.map_message.encode("ascii") + b"\x00"
        if mapped_page_offset + len(map_payload) > len(high_page):
            raise ValueError("mapped smoke-test message does not fit in the selected card page")
        high_page[mapped_page_offset : mapped_page_offset + len(map_payload)] = map_payload
    exec_address = ((args.exec_segment << 4) + args.exec_offset) & 0xFFFFF
    exec_page_offset = exec_address - 0xE0000
    if args.stub == "smoke-exec":
        if exec_address < 0xE0000:
            raise ValueError("mapped smoke-test routine must be in the 0xE0000..0xFFFFF window")
        mapped_routine = build_mapped_routine(
            args.exec_message,
            args.exec_segment,
            args.exec_offset,
            args.smoke_x,
            args.smoke_y,
        )
        if exec_page_offset + len(mapped_routine) > len(high_page):
            raise ValueError("mapped smoke-test routine does not fit in the selected card page")
        high_page[exec_page_offset : exec_page_offset + len(mapped_routine)] = mapped_routine
    f200_address = ((args.f200_segment << 4) + args.f200_offset) & 0xFFFFF
    f200_page_offset = f200_address - 0xE0000
    if args.stub == "f200-smoke":
        if f200_address < 0xE0000:
            raise ValueError("mapped F200 smoke-test routine must be in the 0xE0000..0xFFFFF window")
        f200_routine = build_f200_smoke_routine(
            args.f200_message,
            args.f200_segment,
            args.f200_offset,
            args.smoke_x,
            args.smoke_y,
        )
        if f200_page_offset + len(f200_routine) > len(high_page):
            raise ValueError("mapped F200 smoke-test routine does not fit in the selected card page")
        high_page[f200_page_offset : f200_page_offset + len(f200_routine)] = f200_routine
    basic_exec_address = ((args.basic_exec_segment << 4) + args.basic_exec_offset) & 0xFFFFF
    basic_exec_page_offset = basic_exec_address - 0xE0000
    if args.stub in ("basic-exec", "basic-probe", "basic-steps"):
        if basic_exec_address < 0xE0000:
            raise ValueError("mapped BASIC wrapper must be in the 0xE0000..0xFFFFF window")
        if args.stub == "basic-exec":
            basic_wrapper = build_basic_mapped_wrapper(
                args.program_path,
                args.basic_exec_segment,
                args.basic_exec_offset,
                args.work_segment,
                args.work_limit,
                lcd_value,
                args.restore_lcd_value,
            )
        elif args.stub == "basic-probe":
            basic_wrapper = build_basic_probe_mapped_wrapper(
                args.program_path,
                args.basic_exec_segment,
                args.basic_exec_offset,
                args.work_segment,
                args.work_limit,
                args.probe_before_message,
                args.probe_after_message,
                args.smoke_x,
                args.smoke_y,
                lcd_value,
                args.restore_lcd_value,
            )
        else:
            basic_wrapper = build_basic_steps_mapped_wrapper(
                args.program_path,
                args.basic_exec_segment,
                args.basic_exec_offset,
                args.work_segment,
                args.work_limit,
                lcd_value,
                args.restore_lcd_value,
                args.smoke_x,
                args.smoke_y,
            )
        if basic_exec_page_offset + len(basic_wrapper) > len(high_page):
            raise ValueError("mapped BASIC wrapper does not fit in the selected card page")
        high_page[basic_exec_page_offset : basic_exec_page_offset + len(basic_wrapper)] = basic_wrapper
    load_probe_address = ((args.load_probe_segment << 4) + args.load_probe_offset) & 0xFFFFF
    load_probe_page_offset = load_probe_address - 0xE0000
    if args.stub == "basic-load-probe":
        if load_probe_address < 0xE0000:
            raise ValueError("BASIC load probe routine must be in the 0xE0000..0xFFFFF window")
        load_probe_routine = build_basic_load_probe_routine(args.load_probe_offset)
        if load_probe_page_offset + len(load_probe_routine) > len(high_page):
            raise ValueError("BASIC load probe routine does not fit in the selected card page")
        high_page[load_probe_page_offset : load_probe_page_offset + len(load_probe_routine)] = load_probe_routine
    init_wrapper_address = ((args.init_wrapper_segment << 4) + args.init_wrapper_offset) & 0xFFFFF
    init_wrapper_page_offset = init_wrapper_address - 0xE0000
    if args.stub in (
        "basic-init-steps-probe",
        "basic-runtime-branch-probe",
        "basic-runtime-letter-probe",
        "basic-runtime-probe",
        "basic-runtime-steps-probe",
    ):
        if init_wrapper_address < 0xE0000:
            raise ValueError("BASIC init-step wrappers must be in the 0xE0000..0xFFFFF window")
        init_wrappers = (
            near_to_far_wrapper(0x83EB, args.init_wrapper_offset)
            + near_to_far_wrapper(0x7C82, args.init_wrapper_offset + 8)
            + near_to_far_wrapper(0x7C1E, args.init_wrapper_offset + 16)
        )
        if args.stub == "basic-runtime-probe":
            init_wrappers += near_to_far_wrapper(0x7D00, args.init_wrapper_offset + 24)
        if args.stub in ("basic-runtime-branch-probe", "basic-runtime-steps-probe"):
            init_wrappers += near_to_far_wrapper(0x6800, args.init_wrapper_offset + 24)
            init_wrappers += near_to_far_wrapper(0xC3FD, args.init_wrapper_offset + 32)
        if args.stub == "basic-runtime-letter-probe":
            init_wrappers += near_to_far_wrapper(0x84D5, args.init_wrapper_offset + 24)
        if init_wrapper_page_offset + len(init_wrappers) > len(high_page):
            raise ValueError("BASIC init-step wrappers do not fit in the selected card page")
        high_page[init_wrapper_page_offset : init_wrapper_page_offset + len(init_wrappers)] = init_wrappers

    card_page_offset = args.card_page * CARD_PAGE_SIZE
    if card_page_offset + CARD_PAGE_SIZE > len(card):
        raise ValueError("selected card page does not fit in output image")
    card[card_page_offset : card_page_offset + CARD_PAGE_SIZE] = high_page

    if args.stub == "basic":
        stub = build_basic_stub(
            args.program_path,
            args.bank,
            args.work_segment,
            args.work_limit,
            lcd_value,
            args.restore_lcd_value,
        )
    elif args.stub == "basic-load-probe":
        stub = build_basic_load_probe_stub(
            args.program_path,
            args.bank,
            args.load_probe_segment,
            args.load_probe_offset,
            args.work_segment,
            args.work_limit,
            args.load_probe_before_message,
            args.load_probe_ok_message,
            args.load_probe_fail_message,
            args.smoke_x,
            args.smoke_y,
        )
    elif args.stub == "basic-file-probe":
        stub = build_basic_file_probe_stub(
            args.program_path,
            args.file_probe_before_message,
            args.file_probe_open_ok_message,
            args.file_probe_open_fail_message,
            args.file_probe_read_ok_message,
            args.file_probe_read_fail_message,
            args.smoke_x,
            args.smoke_y,
        )
    elif args.stub == "basic-ram-load-probe":
        stub = build_basic_ram_load_probe_stub(
            rom,
            args.program_path,
            args.ram_load_probe_segment,
            args.ram_load_probe_size,
            args.work_segment,
            args.work_limit,
            args.ram_load_probe_before_message,
            args.ram_load_probe_ok_message,
            args.ram_load_probe_fail_message,
            args.smoke_x,
            args.smoke_y,
        )
    elif args.stub == "basic-init-steps-probe":
        stub = build_basic_init_steps_probe_stub(
            rom,
            args.program_path,
            args.bank,
            args.ram_load_probe_segment,
            args.init_steps_probe_size,
            args.init_wrapper_segment,
            args.init_wrapper_offset,
            args.init_wrapper_offset + 8,
            args.init_wrapper_offset + 16,
            args.work_segment,
            args.work_limit,
            args.ram_load_probe_before_message,
            args.ram_load_probe_ok_message,
            args.ram_load_probe_fail_message,
            args.smoke_x,
            args.smoke_y,
        )
    elif args.stub == "basic-runtime-probe":
        stub = build_basic_runtime_probe_stub(
            rom,
            args.program_path,
            args.bank,
            args.ram_load_probe_segment,
            args.init_steps_probe_size,
            args.init_wrapper_segment,
            args.init_wrapper_offset,
            args.init_wrapper_offset + 8,
            args.init_wrapper_offset + 16,
            args.init_wrapper_offset + 24,
            args.work_segment,
            args.work_limit,
            lcd_value,
            args.restore_lcd_value,
            args.ram_load_probe_before_message,
            args.ram_load_probe_ok_message,
            args.ram_load_probe_fail_message,
            args.smoke_x,
            args.smoke_y,
        )
    elif args.stub == "basic-runtime-branch-probe":
        stub = build_basic_runtime_branch_probe_stub(
            rom,
            args.program_path,
            args.bank,
            args.ram_load_probe_segment,
            args.init_steps_probe_size,
            args.init_wrapper_segment,
            args.init_wrapper_offset,
            args.init_wrapper_offset + 8,
            args.init_wrapper_offset + 16,
            args.init_wrapper_offset + 24,
            args.init_wrapper_offset + 32,
            args.work_segment,
            args.work_limit,
            args.ram_load_probe_before_message,
            args.ram_load_probe_ok_message,
            args.ram_load_probe_fail_message,
            args.smoke_x,
            args.smoke_y,
        )
    elif args.stub == "basic-runtime-steps-probe":
        stub = build_basic_runtime_steps_probe_stub(
            rom,
            args.program_path,
            args.bank,
            args.ram_load_probe_segment,
            args.init_steps_probe_size,
            args.init_wrapper_segment,
            args.init_wrapper_offset,
            args.init_wrapper_offset + 8,
            args.init_wrapper_offset + 16,
            args.init_wrapper_offset + 24,
            args.init_wrapper_offset + 32,
            args.work_segment,
            args.work_limit,
            args.ram_load_probe_before_message,
            args.ram_load_probe_ok_message,
            args.ram_load_probe_fail_message,
            args.smoke_x,
            args.smoke_y,
        )
    elif args.stub == "basic-runtime-letter-probe":
        stub = build_basic_runtime_letter_probe_stub(
            rom,
            args.program_path,
            args.bank,
            args.ram_load_probe_segment,
            args.init_steps_probe_size,
            args.init_wrapper_segment,
            args.init_wrapper_offset,
            args.init_wrapper_offset + 8,
            args.init_wrapper_offset + 16,
            args.init_wrapper_offset + 24,
            args.work_segment,
            args.work_limit,
            args.ram_load_probe_before_message,
            args.ram_load_probe_ok_message,
            args.ram_load_probe_fail_message,
            args.smoke_x,
            args.smoke_y,
        )
    elif args.stub in ("basic-exec", "basic-probe", "basic-steps"):
        stub = build_basic_exec_stub(args.bank, args.basic_exec_segment, args.basic_exec_offset)
    elif args.stub == "smoke":
        stub = build_smoke_stub(args.smoke_message, args.smoke_x, args.smoke_y)
    elif args.stub == "smoke-map":
        stub = build_smoke_map_stub(args.bank, args.map_segment, args.map_offset, args.smoke_x, args.smoke_y)
    elif args.stub == "smoke-exec":
        stub = build_smoke_exec_stub(args.bank, args.exec_segment, args.exec_offset)
    else:
        stub = build_smoke_exec_stub(args.bank, args.f200_segment, args.f200_offset)
    basic_lines = args.basic_line or DEFAULT_BASIC_LINES
    basic_file = build_basic_file(basic_lines)
    Path(args.x_out).write_bytes(stub)
    Path(args.basic_out).write_bytes(basic_file)
    write_file(card, geometry, "EROMCARD.X", stub)
    write_file(card, geometry, args.basic_name, basic_file)
    Path(args.card_out).write_bytes(card)

    print(f"wrote {args.x_out} ({len(stub)} bytes)")
    print(f"built {args.stub} EROMCARD.X stub")
    print(f"wrote {args.basic_out} ({len(basic_file)} bytes)")
    print(f"using BASIC work area 0x{work_base:04x}..0x{work_base + args.work_limit - 1:04x}")
    print(f"using BASIC LCD scanout value 0x{lcd_value:02x} (base 0x{lcd_value << 9:04x})")
    if args.stub == "smoke-map":
        print(f"patched mapped smoke message at CPU 0x{mapped_address:05x} / card page offset 0x{mapped_page_offset:05x}")
    if args.stub == "smoke-exec":
        print(f"patched mapped smoke routine at CPU 0x{exec_address:05x} / card page offset 0x{exec_page_offset:05x}")
    if args.stub == "f200-smoke":
        print(f"patched mapped F200 smoke routine at CPU 0x{f200_address:05x} / card page offset 0x{f200_page_offset:05x}")
    if args.stub in ("basic-exec", "basic-probe", "basic-steps"):
        print(f"patched mapped BASIC wrapper at CPU 0x{basic_exec_address:05x} / card page offset 0x{basic_exec_page_offset:05x}")
    if args.stub == "basic-load-probe":
        print(f"patched BASIC load probe at CPU 0x{load_probe_address:05x} / card page offset 0x{load_probe_page_offset:05x}")
    print(f"copied 325 0x60000..0x7ffff to card page {args.card_page} at 0x{card_page_offset:05x}")
    print(f"inserted EROMCARD.X and {args.basic_name} into {args.card_out}")


if __name__ == "__main__":
    main()
