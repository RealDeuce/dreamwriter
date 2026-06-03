; Generated from disasm: C000:1240-170D
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x1240


diagnostic_gate_C000_1240:
; file 0x41240
    call C000:1252
    jz   C000:1247
    clc
    ret
    call C000:1272
    call C000:128F
    jc   C000:1251
    jmp  C000:1247
    ret
diagnostic_chord_compare_C000_1252:
; file 0x41252
    push es
    mov  di,0xc000
    mov  es,di
    mov  di,0x1268
    mov  si,0x6d06
    mov  cx,0x000a
    cld
    repe cmpsb
    pop  es
    or   cx,cx
    ret
diagnostic_draw_short_banner_C000_1272:
; file 0x41272
    call DC98:000E
    mov  si,0x0086
    mov  dx,0xc688
    mov  cx,0x0042
    call C000:5AD6
    mov  ax,0
    mov  bx,2
    call DC98:002A
    ret
diagnostic_reset_command_state_C000_15FE:
; file 0x415FE
    mov  word [0x6eb7],0
    mov  word [0x6eb5],0x6c06
    mov  bx,[0x6eb5]
    mov  byte [bx],0
    mov  byte [0x6ebb],'M'
    ret
diagnostic_command_loop_C000_128F:
; file 0x4128F
    and  byte [0x6d51],0xf7
    call C000:15FE
    mov  ax,1
    call DC98:001C
    call C000:08A3
    call C000:1617
    cmp  al,1
    jz   diagnostic_reset_C000_12DD
    or   al,al
    jz   C000:1297
    cmp  al,0x0b
    jz   diagnostic_exit_C000_12CE
    cmp  al,0x02
    jz   diagnostic_exit_C000_12CE
    cmp  al,0x03
    jz   diagnostic_exit_C000_12CE
    cmp  al,'?'
    jz   diagnostic_help_C000_12D0
    cmp  al,'K'
    jz   diagnostic_keyboard_C000_12D5
    cmp  al,'k'
    jz   diagnostic_keyboard_C000_12D5
    cmp  al,0xda
    jz   diagnostic_parse_enter_C000_132F
    call C000:1674
    jmp  C000:1297
diagnostic_exit_C000_12CE:
    stc
    ret

diagnostic_help_C000_12D0:
    call C000:16EB
    jmp  C000:1297

diagnostic_keyboard_C000_12D5:
    call C000:16A6
    call C000:1272
    jmp  C000:128F

diagnostic_reset_C000_12DD:
    call C000:044B
    mov  byte [0x6d59],0x55
    jmp  C000:0029
diagnostic_parse_enter_C000_132F:
; file 0x4132F
    call C000:16B8        ; CR/LF
    mov  ax,0
    call DC98:001C
    mov  bx,0x6c06
    mov  al,[bx]
    cmp  al,0xda
    jz   C000:12E8
    mov  dx,0
    mov  cl,4
    and  al,0xdf
...
    inc  bx
    and  ax,0x005f
    cmp  al,'A'
    jc   C000:1382
    sub  al,0x37
    and  al,0x0f
    shl  dx,cl
    or   dx,ax
diagnostic_dump_engine_C000_1409:
; file 0x41409
    mov  dx,7           ; default seven rows
    push dx
    cmp  byte [0x6ebb],'I'
    jz   C000:1427
    cmp  byte [0x6ebb],'L'
    jz   C000:1427
    mov  bx,[0x6eb7]
    call C000:1645       ; print segment
    mov  al,':'
    call C000:1674
    mov  bx,[0x6eb9]
    call C000:1645       ; print offset/port
...
    mov  cx,0x0010
    call C000:14B4       ; read one byte
    inc  si
    mov  [0x6eb9],si
    call C000:1650       ; print byte as hex
...
    call C000:14DA       ; print ASCII sidecar
    call C000:16B8       ; CR/LF
    dec  dx
    jnz  C000:140C
diagnostic_read_dump_byte_C000_14B4:
; file 0x414B4
    mov  cx,ds
    mov  si,[0x6eb9]
    cmp  byte [0x6ebb],'I'
    jz   C000:14D4
    cmp  byte [0x6ebb],'L'
    jz   C000:14D4
    mov  dx,[0x6eb7]
    mov  ds,dx
    mov  bl,[si]
    mov  ds,cx
    jmp  C000:14D9
    mov  dx,si
    in   al,dx
    mov  bl,al
    ret
    cmp  byte [0x6ebb],'L'
    jnz  C000:147B
    mov  al,0xf8
    out  0xdd,al
diagnostic_set_memory_C000_13E6:
; file 0x413E6
    mov  di,[0x6eb9]
    mov  si,[0x6eb7]
    push ds
    mov  ds,si
    mov  [di],dl
    pop  ds
    mov  byte [0x6ebb],'M'
    mov  dx,1
    jmp  C000:140C
diagnostic_single_step_C000_14FA:
; file 0x414FA
    mov  [0x6eb9],dx
    mov  bx,[0x6eb9]
    mov  [0x6ebc],bx
    mov  bx,[0x6eb7]
    mov  [0x6ebe],bx
    mov  ax,0
    call DC98:001C
    pushf
    mov  bp,sp
    xor  word [bp+0],0x0100
    test word [bp+0],0x0100
    jz   trap_removed_C000_154A
diagnostic_keyboard_check_C000_16A6:
; file 0x416A6
    or   byte [0x6d51],0x01
    push es
    call DC98:0CA2
    pop  es
    and  byte [0x6d51],0xfe
    ret
diagnostic_help_page_C000_16EB:
; file 0x416EB
    mov  ax,0
    call DC98:001C
    mov  si,0x0086
    mov  dx,0xc688
    mov  cx,0x00f9
    call C000:5AD6
    call C000:15FE
    mov  ax,0
    mov  bx,7
    call DC98:002A
    ret
diagnostic_putc_C000_1674:
; file 0x41674
    cmp  al,0x08
    jz   diagnostic_backspace_C000_1688
    cmp  al,0x20
    jc   C000:1687
    cmp  al,0xd0
    jnc  C000:1687
    mov  ah,0
    call DC98:0038
    ret
