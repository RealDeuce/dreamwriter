; Generated from disasm: DC98:0E70-106B
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x0E70


display_fixed_resource_DC98_0E70:
; file 0x5D7F0
    push cx
    mov  ax,0x0002
    mov  bx,0xedfa
    mov  cx,0x000f
    call C000:67AD
    pop  cx
    retf
display_text_DC98_0E81:
; file 0x5D801
    push bp
    mov  bp,sp
    sub  sp,6
    mov  [bp-4],ax
    mov  [bp-2],bx
    mov  word [bp-6],0x72e5
    mov  byte [bx],0xff
    mov  byte [bx],0x40
    mov  [bx],dx
    mov  [bx],cx
...
    les  bx,[bp-4]
    mov  al,[es:bx]
    test al,al
    jnz  copy_text_byte_DC98_0EB9
    mov  ax,0x72e5
    mov  bx,ds
    call C000:67AD
display_rects_DC98_0EE5:
; file 0x5D865
    push bp
    mov  bp,sp
    mov  word [bp-2],0x72e5
    mov  byte [si],0xff
    mov  byte [si],0x44
    mov  [si],bx
    mov  [si],ax
    mov  di,[bp+6]
    mov  [si],di
    mov  [si],cx
...
    call C000:67AD
