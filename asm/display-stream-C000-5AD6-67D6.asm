; Generated from disasm: C000:5AD6-67D6
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x5AD6


display_stream_far_C000_67AD:
; file 0x467AD
    push bp
    push di
    push si
    push dx
    push cx
    mov  dx,bx
    mov  si,ax
    call display_resource_C000_5AD6
    pop  cx
    pop  dx
    pop  si
    pop  di
    pop  bp
    retf
poll_idle_far_C000_67BF:
; file 0x467BF
    push bp
    push di
    push si
    push dx
    push cx
    push bx
    push es
    mov  ax,ds
    mov  es,ax
    call foreground_poll_C000_49FD
    mov  ah,0
    pop  es
    pop  bx
    pop  cx
    pop  dx
    pop  si
    pop  di
    pop  bp
    retf
display_resource_C000_5AD6:
; file 0x45AD6
    push es
    mov  bp,0
    mov  es,bp
    mov  ax,[0x7119]
    mov  [0x7117],ah
    mov  [0x7118],al
    xor  ax,ax
    mov  al,[0x70f4]
    call select_display_font_C000_5FE3
    jcxz parser_done_C000_5AD4
    mov  [0x70f0],cx
    mov  di,0x7185
    mov  [0x728e],di
    mov  bp,ds
    mov  ds,dx
    cld
    rep  movsb
    mov  ds,bp
display_resource_loop_C000_5B04:
    cmp  word [0x70f0],0
    jz   parser_done_C000_5AD4
    and  byte [0x7118],0xdf
    dec  word [0x70f0]
    mov  si,[0x728e]
    mov  al,[si]
    inc  word [0x728e]
    sub  al,0x20
    jc   display_resource_loop_C000_5B04
    cmp  al,0xc0
    jc   draw_glyph_C000_5B29
    jmp  control_opcode_C000_5DC8
draw_glyph_C000_5B29:
    mov  dl,al
    mov  si,[0x70f2]
    add  ax,ax
    add  ax,ax
    add  ax,ax
    add  si,ax
    mov  word [0x7290],0xd7ef
    mov  ch,[0x70f5]
...
    mov  cl,ch
    mov  cl,[cs:si+0x5a67]
