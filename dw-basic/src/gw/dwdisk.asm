; DreamWriter handle-based file backend for GW-BASIC sequential/program files.
;
; The original GW-BASIC disk driver is FCB-oriented. The T400 firmware exposes
; the storage layer through DOS-like handle services on INT 21h, so this module
; implements only the GIO device surface needed by LOAD/SAVE and sequential
; OPEN/INPUT#/PRINT# paths.

%include "dwoem.inc"
%include "gio86u.inc"
%include "msdosu.inc"

extern DERBFM
extern DERFNF
extern DERIOE
extern FCERR
extern BINPSV
extern CHRGTR
extern CURLIN
extern DOL_EXPCN
extern DOL_LOGP
extern FILDEV
extern FILMOD
extern FILNM
extern GTMPRT
extern INIFDB
extern SCCPTR
extern TEMP
extern TXTTAB
extern VARTAB
extern PROFLG

DW_FH equ FD_DAT
DW_FDB_EXTRA_SIZE equ 2

global DSKDSP
DSKDSP:
    dw dw_disk_eof
    dw dw_disk_loc
    dw FCERR
    dw dw_disk_close
    dw dw_disk_ret
    dw FCERR
    dw dw_disk_open
    dw dw_disk_sin
    dw dw_disk_sot
    dw dw_disk_gps
    dw dw_disk_gwd
    dw dw_disk_ret
    dw dw_disk_ret
    dw dw_disk_bin
    dw dw_disk_bot

dw_disk_ret:
    ret

dw_disk_eof:
    xor bx, bx
    cmp byte [F_ORCT+si], 0
    jne .done
    dec bx
.done:
    ret

dw_disk_loc:
    xor bx, bx
    ret

dw_disk_gps:
    mov ah, byte [F_POS+si]
    ret

dw_disk_gwd:
    mov ah, 255
    ret

dw_disk_open:
    cmp byte [FILMOD], MD_RND
    je .bad_mode

    push ax
    push bx
    push cx
    push dx
    mov cx, DW_FDB_EXTRA_SIZE
    mov ah, MD_SQI | MD_SQO | MD_APP
    mov dx, 255
    call INIFDB
    call dw_build_path
    mov al, byte [FILMOD]
    cmp al, MD_SQO
    je .create
    cmp al, MD_APP
    je .append
    mov ax, 0x3d00
    mov dx, dw_file_path
    int 0x21
    jc .open_failed
    jmp .store_handle
.append:
    mov ax, 0x3d02
    mov dx, dw_file_path
    int 0x21
    jnc .store_append_handle
    jmp .create_append
.create:
    mov ah, 0x3c
    xor cx, cx
    mov dx, dw_file_path
    int 0x21
    jc .io_failed
.store_handle:
    mov word [DW_FH+si], ax
    jmp .finish_open
.create_append:
    mov ah, 0x3c
    xor cx, cx
    mov dx, dw_file_path
    int 0x21
    jc .io_failed
.store_append_handle:
    mov word [DW_FH+si], ax
    call dw_append_seek
    mov byte [F_MODE+si], MD_SQO
.finish_open:
    mov byte [F_ORCT+si], 1
    mov byte [F_BREM+si], 0
    pop dx
    pop cx
    pop bx
    pop ax
    ret
.bad_mode:
    jmp DERBFM
.open_failed:
    jmp DERFNF
.io_failed:
    jmp DERIOE

dw_append_seek:
    push ax
    push bx
    push cx
    push dx
    mov bx, word [DW_FH+si]
    xor cx, cx
    xor dx, dx
    mov ax, 0x4202
    int 0x21
    jc .io_failed
    or ax, dx
    jz .done
    mov cx, 0xffff
    mov dx, 0xffff
    mov ax, 0x4201
    int 0x21
    jc .io_failed
    mov cx, 1
    mov dx, dw_file_byte
    mov ah, 0x3f
    int 0x21
    jc .io_failed
    cmp ax, 1
    jne .seek_end
    cmp byte [dw_file_byte], ASCCTZ
    jne .seek_end
    mov cx, 0xffff
    mov dx, 0xffff
    mov ax, 0x4201
    int 0x21
    jc .io_failed
    jmp .done
.seek_end:
    xor cx, cx
    xor dx, dx
    mov ax, 0x4202
    int 0x21
    jc .io_failed
.done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
.io_failed:
    jmp DERIOE

dw_disk_close:
    push ax
    push bx
    cmp byte [F_MODE+si], MD_SQO
    jne .close
    cmp byte [F_CODE+si], FC_BIN
    je .close
    mov al, ASCCTZ
    call dw_disk_sot
.close:
    mov bx, word [DW_FH+si]
    mov ah, 0x3e
    int 0x21
    jc .io_failed
    pop bx
    pop ax
    ret
.io_failed:
    jmp DERIOE

dw_disk_sin:
    push bx
    push cx
    push dx
    mov bx, word [DW_FH+si]
    mov cx, 1
    mov dx, dw_file_byte
    mov ah, 0x3f
    int 0x21
    jc .io_failed
    or ax, ax
    jz .eof
    mov al, byte [dw_file_byte]
    call dw_update_input_pos
    clc
    pop dx
    pop cx
    pop bx
    ret
.eof:
    stc
    pop dx
    pop cx
    pop bx
    ret
.io_failed:
    jmp DERIOE

dw_disk_sot:
    push ax
    push bx
    push cx
    push dx
    mov byte [dw_file_byte], al
    mov bx, word [DW_FH+si]
    mov cx, 1
    mov dx, dw_file_byte
    mov ah, 0x40
    int 0x21
    jc .io_failed
    cmp ax, 1
    jne .io_failed
    mov al, byte [dw_file_byte]
    call dw_update_output_pos
    pop dx
    pop cx
    pop bx
    pop ax
    ret
.io_failed:
    jmp DERIOE

dw_disk_bin:
    push ds
    push si
    push di
    push cx
    mov di, bx
    mov bx, word [DW_FH+si]
    push dx
    pop ds
    mov dx, di
    mov ah, 0x3f
    int 0x21
    pop cx
    pushf
    mov bx, di
    add bx, ax
    popf
    pop di
    pop si
    pop ds
    jc .io_failed
    cmp ax, cx
    jb .short_read
    clc
    ret
.short_read:
    stc
    ret
.io_failed:
    jmp DERIOE

dw_disk_bot:
    push ds
    push si
    push di
    push cx
    mov di, bx
    mov bx, word [DW_FH+si]
    push dx
    pop ds
    mov dx, di
    mov ah, 0x40
    int 0x21
    pop cx
    pushf
    mov bx, di
    add bx, ax
    popf
    pop di
    pop si
    pop ds
    jc .io_failed
    cmp ax, cx
    jne .io_failed
    ret
.io_failed:
    jmp DERIOE

dw_update_input_pos:
    cmp al, ASCCTZ
    je dw_update_pos_done
    ; fall through to the same column tracking as output
dw_update_output_pos:
    cmp al, ASCCR
    jne .not_cr
    mov byte [F_POS+si], 0
    ret
.not_cr:
    cmp al, " "
    jb dw_update_pos_done
    inc byte [F_POS+si]
dw_update_pos_done:
    ret

dw_build_path:
    push ax
    push cx
    push si
    push di
    mov di, dw_file_path
    mov al, byte [FILDEV]
    or al, al
    jnz .explicit_drive
    mov al, DW_DEFAULT_FILE_DRIVE
    jmp .store_drive
.explicit_drive:
    add al, "A"-1
.store_drive:
    stosb
    mov al, ":"
    stosb
    mov si, FILNM
    mov cx, 8
.name_loop:
    lodsb
    cmp al, " "
    je .name_done
    stosb
    loop .name_loop
.name_done:
    cmp byte [FILNM+8], " "
    je .terminate
    mov al, "."
    stosb
    mov si, FILNM+8
    mov cx, 3
.ext_loop:
    lodsb
    cmp al, " "
    je .terminate
    stosb
    loop .ext_loop
.terminate:
    xor al, al
    stosb
    pop di
    pop si
    pop cx
    pop ax
    ret

global PROLOD
global PROCHK
global PRODIR
global PROSAV
PROSAV:
    call CHRGTR
    mov word [TEMP], bx
    call SCCPTR
    call dw_pro_encode
    mov al, 254
    call BINPSV
    call dw_pro_decode
    jmp GTMPRT

dw_pro_ret:
    ret

DW_PRO_N1 equ 11
DW_PRO_N2 equ 13

dw_pro_encode:
    mov cx, DW_PRO_N1 + (DW_PRO_N2 * 256)
    mov bx, word [TXTTAB]
    mov dx, bx
.loop:
    mov bx, word [VARTAB]
    cmp bx, dx
    je dw_pro_ret
    mov bx, DOL_EXPCN
    mov al, cl
    cbw
    add bx, ax
    mov si, dx
    mov al, byte [si]
    sub al, ch
    xor al, byte [cs:bx]
    push ax
    mov bx, DOL_LOGP
    mov al, ch
    cbw
    add bx, ax
    pop ax
    xor al, byte [cs:bx]
    add al, cl
    mov di, dx
    mov byte [di], al
    inc dx
    dec cl
    jnz .count2
    mov cl, DW_PRO_N1
.count2:
    dec ch
    jnz .loop
    mov ch, DW_PRO_N2
    jmp .loop

PROLOD:
dw_pro_decode:
    mov cx, DW_PRO_N1 + (DW_PRO_N2 * 256)
    mov bx, word [TXTTAB]
    mov dx, bx
.loop:
    mov bx, word [VARTAB]
    cmp bx, dx
    je dw_pro_ret
    mov bx, DOL_LOGP
    mov al, ch
    cbw
    add bx, ax
    mov si, dx
    mov al, byte [si]
    sub al, cl
    xor al, byte [cs:bx]
    push ax
    mov bx, DOL_EXPCN
    mov al, cl
    cbw
    add bx, ax
    pop ax
    xor al, byte [cs:bx]
    add al, ch
    mov di, dx
    mov byte [di], al
    inc dx
    dec cl
    jnz .count2
    mov cl, DW_PRO_N1
.count2:
    dec ch
    jnz .loop
    mov ch, DW_PRO_N2
    jmp .loop

PRODIR:
    push bx
    mov bx, word [CURLIN]
    inc bx
    pop bx
    jz PROCHK
    ret

PROCHK:
    pushf
    cmp byte [PROFLG], 0
    jne .protected
    popf
    ret
.protected:
    jmp FCERR

dw_file_byte:
    db 0
dw_file_path:
    times 16 db 0
