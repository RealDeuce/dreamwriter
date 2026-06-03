; Generated from disasm: C000:2C4A-3B4E
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x2C4A


private_format_C000_2C4A:
; file 0x42C4A
    mov  byte [0x7036],1
    mov  [0x6fa5],dl
    cmp  bl,0xa5
    jnz  format_return_C000_2C90
    cmp  dl,0x08
    jz   format_builtin_C000_2C93
    cmp  dl,0x09
    jz   format_card_C000_2C74
    cmp  dl,0x0a
    jnz  bad_format_drive_C000_2C6D
    call dreamlink_format_C000_47AC
    jmp  finish_format_C000_2CFF
format_card_C000_2C74:
    mov  word [0x6fa3],0x4000
    call card_write_check_C000_3CA7
    jc   format_return_C000_2C90
    call card_capacity_probe_C000_3C08
    jc   format_return_C000_2C90
    cmp  byte [0x6fad],0
    jnz  write_format_structures_C000_2CA4
    mov  byte [0x6ec1],0x13
format_builtin_C000_2C93:
    mov  byte [0x6d36],0
    mov  word [0x6fa3],0x1800
    mov  bx,0x0005
    call set_geometry_count_C000_3C76
write_format_structures_C000_2CA4:
    call write_volume_header_C000_3B2B
    call clear_header_word0_C000_3B59
    xor  ax,ax
    mov  [0x6f54],ax
    call clear_verify_data_block_C000_2D02
    jc   finish_format_C000_2CFF
    inc  word [0x6f54]
    call C000:3C90
...
    call init_fat_C000_2D8E
    call select_root_dir_C000_3B01
    mov  word [0x6f5d],0x20
...
    call clear_root_dir_sector_C000_2DBE
    call write_volume_header_C000_3B2B
    jmp  finish_int21_status_C000_393D
write_volume_header_C000_3B2B:
; file 0x43B2B
    mov  al,[0x6fad]
    push ds
    mov  ax,[0x6fa3]
    mov  ds,ax
    mov  word [0x0000],0x1997
    mov  word [0x0002],0x0126
    mov  [0x0004],ax
    jnz  C000:3B54
    mov  word [0x0004],0x0005
map_format_block_C000_2D44:
    mov  ax,[0x6f54]
    mov  bx,0x20
    mul  bx
    mov  bl,[0x6f56]
...
    mov  di,ax
    and  di,0x7fff
...
    test byte [0x6fa5],0x01
    jz   C000:2D7F
    call card_bank_helper_C000_0239
    add  dx,0x4000
    add  dx,0x1800
    mov  [0x6fa6],dx
