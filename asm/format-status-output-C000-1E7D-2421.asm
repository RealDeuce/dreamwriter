; Generated from disasm: C000:1E7D-2421
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x1E7D


status_upper_C000_23CD:
; file 0x423CD
    mov  byte [0x6f23],0x0c
    mov  byte [0x6f24],0x1c
    jmp  status_common_C000_23E3

status_lower_default_x_C000_23D9:
    mov  byte [0x6f23],0x0c

status_lower_C000_23DE:
    mov  byte [0x6f24],0x25
status_common_C000_23E3:
    mov  di,0x6ec3
    call build_status_descriptor_C000_23FF
    mov  ax,[0x6f21]
    xor  dx,dx
    push bp
    call format_u16_field_C000_1E7D
    mov  cx,0x000b
    mov  si,0x6ec3
    mov  dx,ds
    call display_resource_C000_5AD6
    pop  bp
    ret
format_u16_field_C000_1E7D:
; file 0x41E7D
    mov  bp,di
    push di
    call format_decimal_5_C000_21D2
    pop  di
    mov  cx,4
blank_leading_zero_C000_1E87:
    cmp  byte [di],'0'
    jnz  done_decimal_field_C000_1E92
    mov  byte [di],' '
    inc  di
    loop blank_leading_zero_C000_1E87
    or   al,al
    ret
format_decimal_5_C000_21D2:
; file 0x421D2
    push ax
    push dx
    mov  cx,10000
    div  cx
    call emit_digit_C000_2273
...
    mov  cx,1000
...
    mov  cx,100
...
    mov  cx,10
...
    mov  al,[cs:bx+0x2288]
    mov  [ds:bp+0],al
    or   al,al
    ret

emit_digit_C000_2273:
    mov  bl,al
    xor  bh,bh
    cmp  al,0x0f
    mov  al,'X'
    jnc  emit_digit_store_C000_2282
    mov  al,[cs:bx+0x2288]
    mov  [ds:bp+0],al
    inc  bp
    ret

digit_table_C000_2288:
; 30 31 32 33 34 35 36 37 38 39 41 42 43 44 45 46
; "0123456789ABCDEF"
build_status_descriptor_C000_23FF:
    mov  ax,0x02ff
    mov  [di],ax
    add  di,2
    mov  al,[0x6f23]
    mov  ah,0
    mov  [di],ax
    add  di,2
    mov  al,[0x6f24]
    mov  dx,ax
    add  ax,ax
    add  ax,dx
    shl  ax,1
    mov  [di],ax
    add  di,2
    ret
