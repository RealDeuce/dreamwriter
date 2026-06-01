; DreamWriter handle-based file backend for GW-BASIC sequential/program files.
;
; The original GW-BASIC disk driver is FCB-oriented. The T400 firmware exposes
; the storage layer through DOS-like handle services on INT 21h, so this module
; implements only the GIO device surface needed by LOAD/SAVE and sequential
; OPEN/INPUT#/PRINT# paths.

%include "dwoem.inc"
%include "gio86u.inc"
%include "msdosu.inc"

extern DERBRN
extern DERFNF
extern DERIOE
extern FCERR
extern BINPSV
extern CHRGTR
extern CURLIN
extern DFACLO
extern DOL_NORMD
extern DOL_EXPCN
extern DOL_LOGP
extern FAC
extern FILDEV
extern FILMOD
extern FILNM
extern GTMPRT
extern INIFDB
extern MOVE1
extern SCCPTR
extern TEMP
extern TXTTAB
extern VALTYP
extern VARTAB
extern PROFLG

DW_HANDLE_SIZE equ 2
DW_SEQ_HANDLE equ FDBSIZ
DW_RND_EXTRA_SIZE equ FD_DAT - FDBSIZ + DW_HANDLE_SIZE

global DSKDSP
DSKDSP:
    dw dw_disk_eof
    dw dw_disk_loc
    dw dw_disk_lof
    dw dw_disk_close
    dw dw_disk_ret
    dw dw_disk_random
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
    cmp byte [F_MODE+si], MD_RND
    jne .done
    mov bx, word [FD_LOG+si]
.done:
    ret

dw_disk_lof:
    push ax
    push bx
    push cx
    push dx
    call dw_load_handle
    xor cx, cx
    xor dx, dx
    mov ax, 0x4201
    int 0x21
    jc .io_failed
    push dx
    push ax
    call dw_load_handle
    xor cx, cx
    xor dx, dx
    mov ax, 0x4202
    int 0x21
    jc .io_failed
    mov word [dw_file_size], ax
    mov word [dw_file_size+2], dx
    pop dx
    pop cx
    call dw_load_handle
    mov ax, 0x4200
    int 0x21
    jc .io_failed
    mov dx, dw_file_size
    mov bx, DFACLO-1
    mov byte [bx], 0
    inc bx
    mov ch, 4
    call MOVE1
    mov byte [FAC+1], ch
    mov word [bx], cx
    mov word [bx+2], (128+56)*256
    mov byte [VALTYP], 8
    pop dx
    pop cx
    pop bx
    pop ax
    jmp DOL_NORMD
.io_failed:
    jmp DERIOE

dw_disk_gps:
    mov ah, byte [F_POS+si]
    ret

dw_disk_gwd:
    mov ah, 255
    ret

dw_disk_open:
    push ax
    push bx
    push cx
    push dx
    cmp byte [FILMOD], MD_RND
    je .random
    mov cx, DW_HANDLE_SIZE
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
    call dw_store_handle
    jmp .finish_open
.create_append:
    mov ah, 0x3c
    xor cx, cx
    mov dx, dw_file_path
    int 0x21
    jc .io_failed
.store_append_handle:
    call dw_store_handle
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
.open_failed:
    jmp DERFNF
.io_failed:
    jmp DERIOE
.random:
    or cx, cx
    jnz .random_size
    mov cx, DATPSC
.random_size:
    push cx
    add cx, DW_RND_EXTRA_SIZE
    mov ah, MD_SQI | MD_SQO | MD_APP | MD_RND
    mov dx, 255
    call INIFDB
    pop cx
    mov word [FD_SIZ+si], cx
    mov word [FD_PHY+si], 0
    mov word [FD_LOG+si], 0
    mov byte [F_NUL5+si], 0
    mov word [FD_OPS+si], 0
    call dw_build_path
    mov ax, 0x3d02
    mov dx, dw_file_path
    int 0x21
    jnc .store_handle
    mov ah, 0x3c
    xor cx, cx
    mov dx, dw_file_path
    int 0x21
    jc .io_failed
    jmp .store_handle

dw_append_seek:
    push ax
    push bx
    push cx
    push dx
    call dw_load_handle
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
    call dw_load_handle
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
    call dw_load_handle
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
    call dw_load_handle
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
    call dw_load_handle
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
    call dw_load_handle
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

dw_disk_random:
    mov byte [dw_random_op], al
    test al, 2
    jnz .absolute
    mov dx, word [FD_LOG+si]
    inc dx
    jz .bad_record
    jmp .record_ready
.absolute:
    or dx, dx
    jz .bad_record
.record_ready:
    mov word [FD_LOG+si], dx
    mov word [FD_OPS+si], 0
    dec dx
    mov ax, dx
    mul word [FD_SIZ+si]
    mov word [dw_random_offset], ax
    mov word [dw_random_offset+2], dx
    test byte [dw_random_op], 1
    jz .seek_record
    call dw_extend_to_random_offset
.seek_record:
    mov cx, word [dw_random_offset+2]
    mov dx, word [dw_random_offset]
    call dw_load_handle
    mov ax, 0x4200
    int 0x21
    jc .io_failed
    test byte [dw_random_op], 1
    jnz .put_record
    call dw_load_handle
    mov cx, word [FD_SIZ+si]
    mov dx, FD_DAT
    add dx, si
    mov ah, 0x3f
    int 0x21
    jc .io_failed
    cmp ax, cx
    je .done
    ja .io_failed
    push es
    push ds
    pop es
    mov di, FD_DAT
    add di, si
    add di, ax
    sub cx, ax
    xor al, al
    cld
    rep stosb
    pop es
.done:
    ret
.put_record:
    call dw_load_handle
    mov cx, word [FD_SIZ+si]
    mov dx, FD_DAT
    add dx, si
    mov ah, 0x40
    int 0x21
    jc .io_failed
    cmp ax, cx
    jne .io_failed
    ret
.bad_record:
    jmp DERBRN
.io_failed:
    jmp DERIOE

dw_extend_to_random_offset:
    call dw_load_handle
    xor cx, cx
    xor dx, dx
    mov ax, 0x4202
    int 0x21
    jc .io_failed
    cmp dx, word [dw_random_offset+2]
    jb .fill_gap
    ja .done
    cmp ax, word [dw_random_offset]
    jae .done
.fill_gap:
    mov cx, word [dw_random_offset]
    sub cx, ax
    mov word [dw_gap_remaining], cx
    mov cx, word [dw_random_offset+2]
    sbb cx, dx
    mov word [dw_gap_remaining+2], cx
    mov byte [dw_file_byte], 0
    call dw_load_handle
.fill_loop:
    mov cx, 1
    mov dx, dw_file_byte
    mov ah, 0x40
    int 0x21
    jc .io_failed
    cmp ax, 1
    jne .io_failed
    sub word [dw_gap_remaining], 1
    sbb word [dw_gap_remaining+2], 0
    mov ax, word [dw_gap_remaining]
    or ax, word [dw_gap_remaining+2]
    jnz .fill_loop
.done:
    ret
.io_failed:
    jmp DERIOE

dw_handle_ptr:
    push ax
    mov bx, DW_SEQ_HANDLE
    cmp byte [F_MODE+si], MD_RND
    jne .done
    mov bx, FD_DAT
    mov ax, word [FD_SIZ+si]
    add bx, ax
.done:
    add bx, si
    pop ax
    ret

dw_store_handle:
    push bx
    call dw_handle_ptr
    mov word [bx], ax
    pop bx
    ret

dw_load_handle:
    call dw_handle_ptr
    mov bx, word [bx]
    ret

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
dw_random_op:
    db 0
dw_random_offset:
    dd 0
dw_gap_remaining:
    dd 0
dw_file_size:
    dd 0
dw_file_path:
    times 16 db 0
