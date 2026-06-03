; Generated from disasm: C000:3194-3585
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x3194


service_3F_read_C000_3194:
; file 0x43194
    call resolve_handle_C000_4064
    cmp  byte [0x6fa5],0x0a
    jnz  local_read_C000_31BD
    test ah,0x80
    jnz  dreamlink_read_continue_C000_31B6
    or   ah,0x80
    mov  [di],ah
    call dreamlink_read_start_C000_44C0
    call dreamlink_read_data_C000_4511
    mov  [bp+0x00],ax
    ret
local_read_C000_31BD:
    mov  [0x6f62],dx
    mov  dx,[bp+0x08]
    mov  [0x6f64],dx
    mov  [0x6f66],cx
...
    mov  cx,[0x6f66]
    mov  bx,[0x6f93]
    mov  ax,0x80
    sub  ax,bx
...
    mov  es,[0x6f64]
    mov  ds,[0x6fa6]
    rep  movsb
...
    call next_fat_cluster_C000_39C9
    cmp  ax,0x0fff
service_40_write_C000_32B1:
; file 0x432B1
    call resolve_handle_C000_4064
    cmp  byte [0x6fa5],0x0a
    jnz  local_write_C000_32D7
    test ah,0x80
    jnz  dreamlink_write_continue_C000_32D0
    or   ah,0x80
    mov  [di],ah
    call dreamlink_write_start_C000_4622
    call dreamlink_write_data_C000_4647
    mov  [bp+0x00],ax
    ret
local_write_C000_32D7:
    mov  byte [0x7036],1
    mov  [0x6f62],dx
    mov  dx,[bp+0x08]
    mov  [0x6f64],dx
    mov  [0x6f66],cx
...
    call map_current_data_block_C000_3994
    mov  es,[0x6fa6]
    mov  ds,[0x6f64]
    mov  al,[si]
    mov  [es:di],al
    rep  movsb
find_or_extend_cluster_C000_34A3:
    call next_fat_cluster_C000_39C9
    cmp  ax,0x0fff
    jz   allocate_new_cluster_C000_34B0
    mov  [0x6f59],ax
    clc
    ret
...
    inc  word [0x6f57]
    mov  ax,[0x6faa]
    cmp  [0x6f57],ax
    jc   C000:34BB
    mov  byte [0x6ec1],0x0a
    stc
    ret
service_42_seek_C000_356F:
; file 0x4356F
    call resolve_handle_C000_4064
    xor  ax,ax
    mov  [0x6f95],ax
    mov  [0x6f97],ax
    mov  [0x6f66],dx
    mov  [0x6f68],cx
    mov  ax,[bp+0x00]
    mov  [0x6fae],al
