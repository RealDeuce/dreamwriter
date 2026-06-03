; Generated from disasm: DC98:22A1-2B56
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x22A1


rs232_setup_DC98_22A1:
; file 0x5EC21
    push bp
    mov  bp,sp
    sub  sp,0x0a
...
    call DC98:0E70
    mov  ax,0x000c
    mov  bx,0xefc4
    call DC98:0E81        ; title
...
    mov  al,[0x6d2a]
    sub  ax,3            ; baud UI index 0..4
...
    cmp  di,0x00da
    jnz  not_accept
    mov  ax,[bp-0x0a]
    add  al,3
    mov  [0x6d2a],al
    mov  ax,[bp-0x08]
    mov  [0x6d2b],al
    mov  ax,[bp-0x06]
    mov  [0x6d2c],al
    mov  ax,[bp-0x04]
    mov  [0x6d2d],al
    mov  ax,[bp-0x02]
    mov  [0x6d2e],al
printer_setup_DC98_24DB:
; file 0x5EE5B
    push cx
    push dx
    push si
    push di
    call DC98:0E70
...
    mov  al,[0x6d59]
    mov  [0x6d62],al
    mov  al,[0x6d59]
    mov  [0x6d5c],ax
...
    mov  ax,0x2499
    mov  bx,0xdc98
    call DC98:1859        ; install redraw callback
...
    mov  ax,[0x6d5c]
    mov  [0x6d59],al
    mov  ax,[0x6d5e]
    mov  [0x6d5a],al
    mov  ax,[0x6d60]
    mov  [0x6d5b],al
system_settings_DC98_288A:
; file 0x5F20A
    push bp
    mov  bp,sp
    sub  sp,0x06
...
    call DC98:0E70
    mov  ax,0x000c
    mov  bx,0xef81
    mov  cx,0x0014
    call C000:67AD        ; title stream
...
    cmp  di,0x20
    cmp  word [bp-0x04],3
    mov  ax,[bp-0x04]
    call C000:077C        ; preview buzzer type
...
    mov  ax,[bp-0x06]
    mov  [0x6d2f],al
    mov  ax,[bp-0x04]
    mov  [0x6d30],al
    mov  ax,0xef79
    mov  bx,[bp-0x06]
    mov  ax,[es:bx+0x0002]
    mov  [0x6d31],ax
preferences_DC98_2A83:
; file 0x5F403
    push bp
    mov  bp,sp
    sub  sp,0x04
...
    call DC98:0E70
    mov  ax,0x000e
    mov  bx,0xef8e
    mov  cx,0x0019
    call C000:67AD        ; title stream
    mov  ax,[0x6d55]
    mov  [bp-0x02],ax
    mov  al,[0x6d24]
    mov  [bp-0x04],ax
...
    mov  ax,[bp-0x02]
    mov  [0x6d55],ax
    mov  ax,[bp-0x04]
    mov  [0x6d24],al
