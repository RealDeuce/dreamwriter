; Generated from disasm: DC98:E8D5-EE7B
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0xE8D5


file_open_default_DC98_E8D5:
; file 0x6B255
    push bx
    mov  bx,0x0061
    push bx
    push ax
    call DC98:E946
    add  sp,6
    retf
file_read_DC98_EE08:
; file 0x6B788
    push dx
    mov  dx,bx
    mov  bx,ax
    mov  ah,0x3f
    int  0x21
    jnc  read_ok_DC98_EE19
    call map_file_error_DC98_EDCB
    mov  ax,0xffff
    pop  dx
    retf

file_seek_DC98_EE72:
    push cx
    push dx
    xchg dx,cx
    xchg ax,bx
    mov  ah,0x42
    int  0x21
    mov  bx,dx
map_file_error_DC98_EDCB:
; file 0x6B74B
    push cx
    mov  cx,ax
    cmp  cx,0x50
    mov  word [0x680f],0x0011
...
    mov  ax,0xf50c
    mov  es,ax
    mov  al,[es:bx+0x000e]
    cbw
    mov  [0x680f],ax
    mov  ax,cx
    pop  cx
    ret
