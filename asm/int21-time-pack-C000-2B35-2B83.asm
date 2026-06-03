; Generated from disasm: C000:2B35-2B83
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x2B35

pack_timestamp_pair_C000_2B35:
    call pack_time_C000_2B44
    db 0xa3, 0x9b, 0x6f    ; mov [0x6f9b],ax
    db 0xab    ; stosw
    call pack_date_C000_2B5C
    db 0xa3, 0x99, 0x6f    ; mov [0x6f99],ax
    db 0xab    ; stosw
    db 0xc3    ; ret
pack_time_C000_2B44:
    db 0x06    ; push es
    db 0x57    ; push di
    call current_time_C000_5213
    db 0x5f    ; pop di
    db 0x07    ; pop es
    db 0xd0, 0xe1    ; shl cl,1
    db 0xd0, 0xe1    ; shl cl,1
    db 0xd1, 0xe1    ; shl cx,1
    db 0xd1, 0xe1    ; shl cx,1
    db 0xd1, 0xe1    ; shl cx,1
    db 0xd0, 0xee    ; shr dh,1
    db 0x0a, 0xce    ; or cl,dh
    db 0x8b, 0xc1    ; mov ax,cx
    db 0xc3    ; ret
pack_date_C000_2B5C:
    db 0x06    ; push es
    db 0x57    ; push di
    call current_date_C000_517C
    db 0x5f    ; pop di
    db 0x07    ; pop es
    db 0x81, 0xe9, 0xbc, 0x07    ; sub cx,0x07bc
    db 0x83, 0xf9, 0x64    ; cmp cx,0x0064
    jc year_offset_ok_C000_2B6F
    db 0x83, 0xe9, 0x64    ; sub cx,0x0064
    db 0x8a, 0xe1    ; mov ah,cl
    db 0x32, 0xc0    ; xor al,al
    db 0xd1, 0xe0    ; shl ax,1
    db 0x8a, 0xea    ; mov ch,dl
    db 0xb2, 0x00    ; mov dl,0
    db 0xd1, 0xea    ; shr dx,1
    db 0xd1, 0xea    ; shr dx,1
    db 0xd1, 0xea    ; shr dx,1
    db 0x0a, 0xd5    ; or dl,ch
    db 0x0b, 0xc2    ; or ax,dx
    db 0xc3    ; ret

; helper call targets covered by other slices
current_date_C000_517C equ 0x517C
current_time_C000_5213 equ 0x5213
year_offset_ok_C000_2B6F equ 0x2B6F
