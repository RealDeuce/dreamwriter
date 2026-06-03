; Generated from disasm: C000:0239-2DDB
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x0239


card_bank_helper_C000_0239:
; file 0x40239
    cmp  dx,0x6000
    jc   bank_range_0000_5FFF_C000_0261
    cmp  dx,0x8000
    jc   bank_range_6000_7FFF_C000_0267
    cmp  dx,0xa000
    jc   bank_range_8000_9FFF_C000_0271
    cmp  dx,0xc000
    jc   bank_range_A000_BFFF_C000_027B
    cmp  dx,0xe000
    jc   bank_range_C000_DFFF_C000_0285
    mov  ah,0x18
    mov  al,0x18
    sub  dx,0xa000
commit_bank_pair_C000_028D:
    push bx
    mov  bx,[0x6d8f]
    mov  bl,ah
    mov  [0x6d8f],bx
    pop  bx
    mov  [0x6d91],al
    out  0x15,al
    mov  al,ah
    out  0x14,al
    ret
map_current_sector_C000_2D44:
; file 0x42D44
    mov  ax,[0x6f54]
    mov  bx,0x0020
    mul  bx
    mov  bl,[0x6f56]
    mov  bh,0
    dec  bx
    add  ax,bx
    mov  bx,0x0080
    mul  bx
    mov  di,ax
    and  di,0x7fff
    shl  ax,1
    rcl  dx,1
    mov  cl,0x0b
    shl  dx,cl
select_storage_segment_C000_2D68:
    cmp  byte [0x6fa5],0x0a
    jz   dreamlink_window_C000_2D88
    test byte [0x6fa5],0x01
    jz   built_in_window_C000_2D7F
    call card_bank_helper_C000_0239
    add  dx,0x4000
    jmp  store_window_segment_C000_2D83
    add  dx,0x1800
    mov  [0x6fa6],dx
    ret
    add  dx,0x0580
    jmp  store_window_segment_C000_2D83
format_clear_verify_block_C000_2D02:
; file 0x42D02
    mov  byte [0x6f56],1
    call map_current_sector_C000_2D44
    mov  al,0xe5
    mov  ah,al
    mov  cx,0x0020
    mov  bx,0x5ea6
    mov  es,[0x6fa6]
    mov  cx,0x0040
    mov  [es:di],bx
    cmp  [es:di],bx
    xchg bh,bl
    mov  [es:di],bx
    cmp  [es:di],bx
    stosw
...
    mov  byte [0x6ec1],0x13
init_fat_area_C000_2D8E:
; file 0x42D8E
    push es
    mov  es,[0x6fa3]
    mov  word [0x6f54],0
    mov  byte [0x6f56],2
    call map_current_sector_C000_2D44
    mov  ax,0xfff9
    stosw
    mov  ax,0x00ff
    stosw
    mov  cx,[0x6faa]
    xor  ax,ax
    rep  stosw
    pop  es
    ret
clear_root_entries_C000_2DBE:
; file 0x42DBE
    push es
    mov  es,[0x6fa3]
    call map_current_sector_C000_2D44
    mov  cx,0x0004
    xor  bl,bl
    mov  bh,0xe5
    mov  [es:di],bx
    inc  di
    inc  di
    mov  cx,0x000f
    rep  stosw
