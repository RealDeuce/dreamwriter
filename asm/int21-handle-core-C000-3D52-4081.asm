; Generated from disasm: C000:3D52-4081
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x3D52


resolve_endpoint_C000_4064:
; file 0x44064
    mov  [0x6f19],bx
    cmp  bx,0x0a
    jc   lookup_handle_endpoint_C000_4073
    mov  byte [0x6fa5],0x08
    ret

lookup_handle_endpoint_C000_4073:
    mov  di,0x703f
    add  di,bx
    mov  al,[di]
    and  al,0x0f
    mov  [0x6fa5],al
    ret
resolve_open_file_C000_3DB3:
; file 0x43DB3
    sub  bx,0x05
    cmp  bx,0x04
    jc   slot_index_ok_C000_3DC2
    mov  byte [0x6ec1],0x06
    stc
    ret

slot_index_ok_C000_3DC2:
    mov  al,[bx+0x6fb2]
    cmp  al,0xff
    jz   invalid_handle_C000_3DBB
    mov  [0x6faf],al
    mov  ah,0x20
    mul  ah             ; AL * 0x20
    add  bx,ax
    mov  [0x6fb0],bx
hydrate_handle_state_C000_3DDE:
; file 0x43DDE
    mov  ax,[bx+0x0c]   ; file size low
    mov  dx,[bx+0x0e]   ; file size high
    mov  cx,[bx+0x10]   ; current position low
    mov  bp,[bx+0x12]   ; current position high
...
    mov  al,[bx]
    mov  [0x6fa5],al
...
    mov  es,[0x6fa3]
    mov  di,[bx+0x1e]   ; directory entry offset
    add  di,0x16
    mov  ax,[es:di]
    cmp  ax,[bx+0x16]
close_handle_C000_3D52:
; file 0x43D52
    cmp  byte [0x6fa5],0x0a
    jnz  local_close_C000_3D5D
    call dreamlink_close_C000_4707
    ret
...
    mov  byte [bx+0x6fb2],0xff
    mov  di,[bx+0x1e]
    add  di,0x16
    mov  ax,[bx+0x16]
    mov  [es:di],ax
