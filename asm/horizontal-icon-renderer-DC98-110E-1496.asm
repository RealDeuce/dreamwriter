; Generated from disasm: DC98:110E-1496
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x110E


selection_marker_DC98_110E:
; file 0x5DA8E
    push bp
...
    mov  word [bx],0x0033
    mul  cx
    add  si,0x0002
    add  si,ax
    mov  [bx],si
...
    mov  word [bx],0x004c
...
    mov  byte [bx],0x0a
    call C000:67AD
    ret
horizontal_icon_key_loop_DC98_1198:
; file 0x5DB18
    mov  si,ax
    mov  di,bx
    call DC98:110E
    mov  byte [6811],1
    call DC98:0CF9
    mov  byte [6811],0
    cmp  ax,0x00da
    add  di,0x31
...
    cmp  ax,0x0031
    mov  bx,0x0031
    add  bx,si
...
    cmp  ax,0x0011
...
    cmp  ax,0x0010
...
    pop  di
    ret
horizontal_icon_renderer_DC98_124C:
; file 0x5DBCC
    push bp
...
    mov  [bp-4],ax
    mov  [bp-2],bx
    call DC98:0E70
    mov  ax,0x000a
    mov  bx,0xee4f
    mov  cx,0x0004
    call C000:67AD
...
    mov  si,[es:bx+0x02]
    mov  bx,0x0006
    sub  bx,si
    mov  ax,0x001b
    mul  bx
    add  di,0x0007
...
    mov  ax,dx
    dec  bx
    idiv bx
    add  ax,0x004c
    les  bx,[bp-4]
    add  bx,0x0004
    shl  ax,1
    shl  ax,1
    mov  ax,[es:bx]
    mov  dx,[es:bx+0x02]
...
    mov  bx,0x000d
    add  dx,0x001c
    call DC98:10EC
    mov  cx,0x0003
    mul  cx
    mov  dx,0x0034
    call DC98:0E81
    les  bx,[bp-4]
    push word [es:bx+0x6e]
    push word [es:bx+0x6c]
    push word [es:bx+0x6a]
    mov  ax,si
    mov  bx,cx
    mov  cx,di
    mov  dx,[bp-6]
    call DC98:1198
    add  sp,0x0006
    retf
