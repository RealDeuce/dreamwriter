; Generated from disasm: C000:3868-3BCC
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x3868


directory_scan_init_C000_3868:
; file 0x43868
    mov  byte [0x6ec1],0x02
    mov  word [0x6f5d],0x0020
    call root_position_C000_3B01
    mov  word [0x6f5b],0x0004
    call map_current_sector_C000_2D44

directory_scan_next_C000_388B:
    cmp  word [0x6f5d],0
    mov  [0x6f6e],si
    mov  es,[0x6fa3]
    mov  al,[es:si]
    or   al,al
    jz   directory_end_C000_3922
    cmp  al,0xe5
    jnz  compare_entry_name_C000_38C7
    add  si,0x20
    dec  word [0x6f5b]
    dec  word [0x6f5d]
    jmp  C000:3886
finish_status_plain_C000_393D:
; file 0x4393D
    mov  ax,[0x6ec1]
    jz   success_C000_3949
    mov  [bp+0],ax
    stc
    ret

success_C000_3949:
    mov  al,[0x6faf]
    mov  [bp+0],ax
    clc
    ret
cluster_to_sector_C000_3994:
; file 0x43994
    mov  ax,[0x6f57]
    dec  ax
    dec  ax
...
    mov  bx,0x0020
    div  bx
    call map_current_sector_C000_2D44

fat12_offset_C000_39BA:
    mov  ax,[0x6f57]
    mov  dx,0x0003
    mul  dx
    shr  ax,1
    add  ax,[0x6f84]
    ret

fat12_read_next_C000_39C9:
    call fat12_offset_C000_39BA
...
    jnc  even_cluster_C000_39E8
    shr  ax,1
    shr  ax,1
    shr  ax,1
    shr  ax,1
    and  ax,0x0fff
    mov  [0x6f57],ax
parse_filename_C000_39F7:
; file 0x439F7
    mov  al,[0x6d35]
    mov  [0x6fa5],al
...
    cmp  al,':'         ; drive prefix
    jz   set_drive_from_prefix_C000_3AA0
    cmp  al,'*'
    jnz  normal_char_C000_3A39
...
    cmp  al,'.'
    jz   extension_separator_C000_3AAA
write_volume_header_C000_3B2B:
; file 0x43B2B
    push ax
    mov  ax,[0x6fa3]
    mov  word [0],0x1997
    mov  word [2],0x0126
    mov  [4],ax
...
    mov  word [4],0x0005 ; built-in case

mount_check_C000_3B69:
    push ax
...
    mov  ax,[0x0004]
    mov  [0x6fad],al
    shl  ax,1
    mov  [0x6fa8],ax
