; Generated from disasm: C000:2B35-2B83
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x2B35


pack_timestamp_pair_C000_2B35:
; file 0x42B35
    call pack_time_C000_2B44
    mov  [0x6f9b],ax
    stosw
    call pack_date_C000_2B5C
    mov  [0x6f99],ax
    stosw
    ret
pack_time_C000_2B44:
; file 0x42B44
    push es
    push di
    call current_time_C000_5213
    pop  di
    pop  es
    shl  cl,1
    shl  cl,1
    shl  cx,1
    shl  cx,1
    shl  cx,1
    shr  dh,1
    or   cl,dh
    mov  ax,cx
    ret
pack_date_C000_2B5C:
; file 0x42B5C
    push es
    push di
    call current_date_C000_517C
    pop  di
    pop  es
    sub  cx,0x07bc
    cmp  cx,0x0064
    jc   year_offset_ok_C000_2B6F
    sub  cx,0x0064
    mov  ah,cl
    xor  al,al
    shl  ax,1
    mov  ch,dl
    mov  dl,0
    shr  dx,1
    shr  dx,1
    shr  dx,1
    or   dl,ch
    or   ax,dx
    ret
