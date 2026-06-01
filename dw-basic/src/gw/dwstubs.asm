; DreamWriter GW-BASIC first-pass compatibility shims.
;
; A routine belongs here only when this file deliberately satisfies the
; caller's contract for the current port. Unsupported BASIC statements jump to
; GW-BASIC's normal error paths; optional OEM hooks return explicit minimal
; values. Do not add a generic "ret" just to satisfy the linker.

%include "dwoem.inc"

extern FCERR
extern DERDNA
extern _RET

global LPTDSP

LPTDSP:
    dw DERDNA        ; EOF
    dw DERDNA        ; LOC
    dw DERDNA        ; LOF
    dw _RET          ; CLS
    dw _RET          ; SWD
    dw DERDNA        ; RND
    dw DERDNA        ; OPN
    dw DERDNA        ; SIN
    dw _RET          ; SOT
    dw .gps          ; GPS
    dw .gwd          ; GWD
    dw _RET          ; SCW
    dw _RET          ; GCW
    dw DERDNA        ; BIN
    dw _RET          ; BOT

.gps:
    xor ah, ah
    ret

.gwd:
    mov ah, 255
    ret

%if GW_ENABLE_GRAPHICS
global NREAD
global NWRITE
global PGINIT
global PNTINI
global SCANL
global SCANR
global TDOWNC
global TUPC
%endif
%if !GW_ENABLE_GRAPHICS
global GPUTG
global GLINE
global GRPINI
global GRPRST
global POINT
%endif
global LCPY
global PEKFLT
global POKFLT

%if GW_ENABLE_GRAPHICS
NREAD:
NWRITE:
PGINIT:
PNTINI:
SCANL:
SCANR:
TDOWNC:
TUPC:
    jmp FCERR
%endif

%if !GW_ENABLE_GRAPHICS
GPUTG:
GLINE:
POINT:
    jmp FCERR

GRPINI:
GRPRST:
    ret
%endif

PEKFLT:
POKFLT:
    ; No DreamWriter-specific PEEK/POKE addresses are intercepted yet. Return
    ; NZ so GW-BASIC performs the ordinary ES:[BX] read or ES:[DX] write.
    or sp, sp
    ret

LCPY:
    ; LCOPYS saves the text pointer before calling the OEM hardcopy hook and
    ; raises FCERR itself when carry returns set. Return an error instead of
    ; jumping past that cleanup.
    stc
    ret

global CMPFBC
global CSRATR
global DONOTE
global DWSND_ACTIVE
global FKYADV
global FKYFMT
global GETFBC
global GETHED
global GWINI
global INFMAP
global INKMAP
global MAPSUP
global POLCOM
global POLLEV
global PRTMAP
%if GW_ENABLE_POINTING_DEVICES
global RDPEN
global RDSTIK
global RDTRIG
%endif
global SEGINI
global SETCBF
global SETFBC
global SWIDTH
global EDTMAP
global SYSTEM
global SYSTME

CMPFBC:
CSRATR:
INFMAP:
INKMAP:
MAPSUP:
POLCOM:
%if GW_ENABLE_POINTING_DEVICES
RDSTIK:
RDTRIG:
%endif
SEGINI:
SETCBF:
SETFBC:
SWIDTH:
    clc
    ret

DW_F9_VECTOR_OFF equ 0x03e4
DW_F9_VECTOR_SEG equ 0x03e6
DW_FF_VECTOR_OFF equ 0x03fc
DW_FF_VECTOR_SEG equ 0x03fe
DW_SND_QUEUE_LEN equ 32
DW_SND_QUEUE_MASK equ DW_SND_QUEUE_LEN - 1
DW_SND_ENTRY_SIZE equ 4
DW_SND_MAX_SLICE equ 40

DONOTE:
    pusha
    cmp al, 255
    je .reset
    cmp al, 1
    je .background

    call dw_music_reset
    or dx, dx
    jz .foreground_done
    or cx, cx
    jz .foreground_rest

    call dw_speaker_start
    call dw_music_wait
    call dw_speaker_stop
    call dw_music_restore
    jmp .foreground_done

.foreground_rest:
    call dw_speaker_stop
    call dw_music_wait
    call dw_music_restore
.foreground_done:
    popa
    clc
    ret

.background:
    or dx, dx
    jz .background_done
    call dw_music_install
    call dw_music_enqueue
    jc .background_full
.background_done:
    popa
    clc
    ret

.background_full:
    popa
    stc
    ret

.reset:
    call dw_music_reset
    popa
    clc
    ret

dw_speaker_start:
    push dx
    mov ax, 0xb000
    mov dx, 0x0004
    div cx
    out 0x50, al
    mov al, ah
    out 0x51, al
    mov al, 0x7f
    out 0x52, al
    pop dx
    ret

dw_speaker_stop:
    mov al, 0xff
    out 0x52, al
    ret

DWSND_ACTIVE:
    push ax
    mov al, [dw_snd_active]
    or al, [dw_snd_q_count]
    or al, [dw_snd_waiting]
    pop ax
    ret

dw_music_wait:
    push ax
    push bx
    push dx
    call dw_music_install
.next:
    or dx, dx
    jz .done
    mov ax, dx
    cmp ax, DW_SND_MAX_SLICE
    jbe .slice_ready
    mov ax, DW_SND_MAX_SLICE
.slice_ready:
    sub dx, ax
    mov bx, ax
    call dw_music_units_to_timer_count_fixed
    mov byte [dw_snd_waiting], 1
    call dw_timer_arm_count
.wait:
    cmp byte [dw_snd_waiting], 0
    jne .wait
    jmp .next
.done:
    pop dx
    pop bx
    pop ax
    ret

dw_music_enqueue:
    cmp byte [dw_snd_q_count], DW_SND_QUEUE_LEN
    jae .full
    xor bh, bh
    mov bl, [dw_snd_q_tail]
    shl bx, 1
    shl bx, 1
    mov [dw_snd_queue + bx], cx
    mov [dw_snd_queue + bx + 2], dx
    mov al, [dw_snd_q_tail]
    inc al
    and al, DW_SND_QUEUE_MASK
    mov [dw_snd_q_tail], al
    inc byte [dw_snd_q_count]
    cmp byte [dw_snd_active], 0
    jne .ok
    call dw_music_start_next
.ok:
    clc
    ret
.full:
    stc
    ret

dw_music_start_next:
    cmp byte [dw_snd_q_count], 0
    je .empty
    xor bh, bh
    mov bl, [dw_snd_q_head]
    shl bx, 1
    shl bx, 1
    mov cx, [dw_snd_queue + bx]
    mov dx, [dw_snd_queue + bx + 2]
    mov al, [dw_snd_q_head]
    inc al
    and al, DW_SND_QUEUE_MASK
    mov [dw_snd_q_head], al
    dec byte [dw_snd_q_count]
    or dx, dx
    jz dw_music_start_next

    mov [dw_snd_remaining], dx
    mov byte [dw_snd_active], 1
    or cx, cx
    jz .rest
    call dw_speaker_start
    jmp dw_music_arm_next
.rest:
    call dw_speaker_stop
    jmp dw_music_arm_next
.empty:
    mov byte [dw_snd_active], 0
    mov word [dw_snd_remaining], 0
    mov word [dw_snd_slice], 0
    call dw_speaker_stop
    jmp dw_music_restore

dw_music_tick:
    cmp byte [dw_snd_active], 0
    jne .active
    cmp byte [dw_snd_q_count], 0
    je .done
    call dw_music_start_next
    ret
.active:
    mov ax, [dw_snd_slice]
    or ax, ax
    jz .finish_slice
    sub [dw_snd_remaining], ax
    ja .continue_note
.finish_slice:
    call dw_music_start_next
    ret
.continue_note:
    call dw_music_arm_next
.done:
    ret

dw_music_arm_next:
    mov ax, [dw_snd_remaining]
    or ax, ax
    jz .done
    cmp ax, DW_SND_MAX_SLICE
    jbe .slice_ready
    mov ax, DW_SND_MAX_SLICE
.slice_ready:
    mov [dw_snd_slice], ax
    call dw_music_units_to_timer_count
    call dw_timer_arm_count
.done:
    ret

dw_music_units_to_timer_count:
    push bx
    push dx
    mov bx, 12
    mul bx
    xor bh, bh
    mov bl, [dw_snd_count_frac]
    add ax, bx
    xor dx, dx
    mov bx, 5
    div bx
    mov [dw_snd_count_frac], dl
    or al, al
    jnz .arm
    inc al
.arm:
    pop dx
    pop bx
    ret

dw_music_units_to_timer_count_fixed:
    push bx
    push dx
    mov bx, 12
    mul bx
    xor dx, dx
    mov bx, 5
    div bx
    or dl, dl
    jz .rounded
    inc ax
.rounded:
    or al, al
    jnz .done
    inc al
.done:
    pop dx
    pop bx
    ret

dw_timer_arm_count:
    push ds
    push bx
    mov bl, al
    xor ax, ax
    mov ds, ax
    or byte [0x6da9], 0x01
    and byte [0x6d4f], 0xfd
    mov al, [0x6d4f]
    out 0x60, al
    mov al, bl
    out 0x53, al
    pop bx
    pop ds
    ret

dw_music_reset:
    mov byte [dw_snd_q_head], 0
    mov byte [dw_snd_q_tail], 0
    mov byte [dw_snd_q_count], 0
    mov byte [dw_snd_active], 0
    mov byte [dw_snd_count_frac], 0
    mov byte [dw_snd_waiting], 0
    mov word [dw_snd_remaining], 0
    mov word [dw_snd_slice], 0
    call dw_speaker_stop
    jmp dw_music_restore

dw_music_install:
    pushf
    cli
    pusha
    push ds
    cmp byte [cs:dw_f9_installed], 0
    jne .done
    xor ax, ax
    mov ds, ax
    mov ax, [DW_F9_VECTOR_OFF]
    mov [cs:dw_f9_old_off], ax
    mov ax, [DW_F9_VECTOR_SEG]
    mov [cs:dw_f9_old_seg], ax
    mov word [DW_F9_VECTOR_OFF], dw_music_f9_isr
    push cs
    pop ax
    mov [DW_F9_VECTOR_SEG], ax
    mov byte [cs:dw_f9_installed], 1
.done:
    pop ds
    popa
    popf
    ret

dw_music_restore:
    pushf
    cli
    pusha
    push ds
    cmp byte [cs:dw_f9_installed], 0
    je .done
    xor ax, ax
    mov ds, ax
    mov ax, [cs:dw_f9_old_off]
    mov [DW_F9_VECTOR_OFF], ax
    mov ax, [cs:dw_f9_old_seg]
    mov [DW_F9_VECTOR_SEG], ax
    mov byte [cs:dw_f9_installed], 0
.done:
    pop ds
    popa
    popf
    ret

dw_power_install:
    pushf
    cli
    pusha
    push ds
    xor ax, ax
    mov ds, ax
    cmp byte [cs:dw_ff_installed], 0
    jne .write_vector
    mov ax, [DW_FF_VECTOR_OFF]
    mov [cs:dw_ff_old_off], ax
    mov ax, [DW_FF_VECTOR_SEG]
    mov [cs:dw_ff_old_seg], ax
    mov byte [cs:dw_ff_installed], 1
.write_vector:
    mov word [DW_FF_VECTOR_OFF], dw_power_ff_isr
    push cs
    pop ax
    mov [DW_FF_VECTOR_SEG], ax
    pop ds
    popa
    popf
    ret

dw_power_restore:
    pushf
    cli
    pusha
    push ds
    cmp byte [cs:dw_ff_installed], 0
    je .done
    xor ax, ax
    mov ds, ax
    mov ax, [cs:dw_ff_old_off]
    mov [DW_FF_VECTOR_OFF], ax
    mov ax, [cs:dw_ff_old_seg]
    mov [DW_FF_VECTOR_SEG], ax
    mov byte [cs:dw_ff_installed], 0
.done:
    pop ds
    popa
    popf
    ret

dw_power_resume:
    pushf
    pop word [cs:dw_power_resume_flags]
    cli
    mov [cs:dw_power_resume_ax], ax
    mov ax, cs
    mov ss, ax
    mov sp, [cs:dw_power_resume_sp]
    push ds
    push cs
    pop ds
    call dw_power_install
    pop ds
    push word [cs:dw_power_resume_flags]
    popf
    mov ax, [cs:dw_power_resume_ax]
    jmp far [cs:dw_power_resume_ptr]

dw_power_ff_isr:
    push ds
    push ax
    push bp
    mov bp, ds
    xor ax, ax
    mov ds, ax
    mov al, 0x01
    out 0x90, al

    mov [0x6d73], bp
    mov [0x6d67], bx
    mov [0x6d69], cx
    mov [0x6d6b], dx
    mov [0x6d6d], si
    mov [0x6d6f], di
    mov [0x6d75], es
    mov word [0x6d77], 0

    mov bp, sp
    mov ax, [ss:bp]
    mov [0x6d71], ax
    mov ax, [ss:bp + 2]
    mov [0x6d65], ax
    mov ax, [ss:bp + 6]
    mov [cs:dw_power_resume_off], ax
    mov [0x6d85], ax
    mov word [0x6d79], dw_power_resume
    mov ax, [ss:bp + 8]
    mov [cs:dw_power_resume_seg], ax
    mov [0x6d87], ax
    push cs
    pop ax
    mov [0x6d7b], ax
    lea ax, [bp + 12]
    mov [cs:dw_power_resume_sp], ax
    mov word [0x6d7d], 0x6c06
    mov ax, [ss:bp + 10]
    mov [0x6d7f], ax
    mov word [0x6d81], 0

    mov si, 0x6d65
    mov cx, 0x000f
    xor bx, bx
.checksum:
    lodsw
    add bx, ax
    loop .checksum
    mov [0x6d83], bx

    and byte [0x6da9], 0xfe
    or byte [0x6d4f], 0x02
    mov ax, [0x6d31]
    mov [0x680b], ax
    mov al, [0x6d4f]
    mov [0x6d50], al
    out 0x60, al
    mov al, 0xff
    out 0x52, al
    mov al, 0x01
    out 0x70, al
.halt:
    hlt
    jmp .halt

dw_music_f9_isr:
    push ax
    push ds
    xor ax, ax
    mov ds, ax
    mov al, 0x40
    out 0x90, al
    and byte [0x6da9], 0xfe
    pop ds
    pop ax

    pusha
    push ds
    push es
    push cs
    pop ds
    cmp byte [dw_snd_waiting], 0
    je .queue
    mov byte [dw_snd_waiting], 0
    jmp .done
.queue:
    call dw_music_tick
.done:
    pop es
    pop ds
    popa
    sti
    iret

%if GW_ENABLE_POINTING_DEVICES
RDPEN:
    xor bx, bx
    clc
    ret
%endif

POLLEV:
    ; No firmware interrupt flag is wired into GW-BASIC yet. Ask CHKINT to run
    ; POLKEY on each poll; KEYINP still performs the nonblocking keyboard test.
    push ax
    mov al, 1
    or al, al
    pop ax
    ret

EDTMAP:
PRTMAP:
    ; The generic screen driver expects OEM mapping hooks to turn output
    ; controls into AH=0xff function codes before CTLDSP dispatches FUNTAB.
    ; Leaving CR/LF as plain bytes makes the display path try to wrap/draw
    ; them as printable cells instead of running LCARET/LFEED.
    or al, al
    jz .done
    cmp al, 32
    jb .control
    cmp al, 127
    jne .done
.control:
    mov ah, 0xff
    cmp al, 0
.done:
    ret

GETFBC:
    ; Foreground/background color pair for GRPRST. With PIXSIZ=0 this is only
    ; used to seed gengrp state.
    mov al, 1
    xor bx, bx
    clc
    ret

softkey_format:
    dw (10 << 8) | 6
    db 1

FKYADV:
    ; Single fixed soft-key page. Return NZ so callers know there is a page to
    ; display and LABEL does not interpret the advance as "past the last page".
    push ax
    mov al, 1
    or al, al
    pop ax
    ret

FKYFMT:
    ; BX -> CH=key count, CL=chars/key, byte first key number.
    mov bx, softkey_format
    ret

extern CLRSCN
extern SCNSWI
extern SCNBRK
extern SCNCLR
extern KEYSW
extern CSRTYP
extern CSRFLG
extern dw_cursor_init
extern dw_console_get_rows

GWINI:
    pushf
    pusha
    push ds
    push es
    call dw_power_install
    call dw_cursor_init
    call CLRSCN
    mov al, 80
    call dw_console_get_rows
    call SCNSWI
    mov byte [KEYSW], 0
    call SCNBRK
    call SCNCLR
    pop es
    pop ds
    popa
    popf
    ret

GETHED:
    mov bx, .heading
    cmp byte [bx], 0
    ret
.heading:
    db "DW-BASIC for DreamWriters", 0

extern CLSALL
extern GIOTRM
extern INITFG

SYSTEM:
    jnz .not_eos
    push cs
    pop ds
    call dw_music_reset
    call CLSALL
    jmp SYSTME
.not_eos:
    ret

SYSTME:
    push cs
    pop ds
    call dw_music_reset
    call dw_power_restore
    cmp byte [INITFG], 0
    je .restore
    call GIOTRM
.restore:
    jmp DW_LOADER_SEGMENT:DW_LOADER_EXIT_THUNK_OFFSET
.halt:
    sti
    hlt
    jmp .halt

%include "dwapi.asm"

dw_f9_installed:
    db 0
dw_f9_old_off:
    dw 0
dw_f9_old_seg:
    dw 0
dw_ff_installed:
    db 0
dw_ff_old_off:
    dw 0
dw_ff_old_seg:
    dw 0
dw_power_resume_ptr:
dw_power_resume_off:
    dw 0
dw_power_resume_seg:
    dw 0
dw_power_resume_sp:
    dw 0
dw_power_resume_ax:
    dw 0
dw_power_resume_flags:
    dw 0
dw_snd_q_head:
    db 0
dw_snd_q_tail:
    db 0
dw_snd_q_count:
    db 0
dw_snd_active:
    db 0
dw_snd_count_frac:
    db 0
dw_snd_waiting:
    db 0
dw_snd_remaining:
    dw 0
dw_snd_slice:
    dw 0
dw_snd_queue:
    times DW_SND_QUEUE_LEN * DW_SND_ENTRY_SIZE db 0

global LSTVAR
LSTVAR:
    dw 0
