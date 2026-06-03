; Generated from disasm: DC98:9AC8-B970
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x9AC8


; file 0x67FFC
    push bp
    call DC98:0E70
DC98:B68B  ...               ; build an inline FF40/FF42 script at 72E5
    mov  ax,[0x86ea]    ; home city index
    mov  cx,0x18
    call C000:67AD       ; home city name
...
    mov  ax,[0x86ee]    ; second city index
    mov  cx,0x18
    call C000:67AD       ; second city name
    call DC98:A0CC       ; redraw map and markers
DC98:B87A  ...               ; draw F104:000C line script
DC98:B888  ...               ; draw F10D:000E title/menu script
; file 0x66A4C
DC98:A0CC  ...               ; draw F103:0006
    mov  word [bx],0x0040  ; FF42 height
    mov  word [bx],0x0060  ; FF42 width
    mov  cx,0x000a
    mov  ax,0xf13c         ; F13C:000A map
...
    mov  cx,0x0014         ; second city marker
    mov  cx,0x000e         ; home city marker
; file 0x66448
    push bp
    mov  di,ax
    mov  ax,cx
    mov  word [si],0x000b  ; date icon height
    mov  word [si],0x000b  ; date icon width
    mov  cx,0x0016
    mov  cx,0xf178         ; date/month icon table
...
    mov  word [si],0x000c  ; digit height
    mov  word [si],0x0007  ; digit width
    mov  dx,0x0099         ; blank if hour < 10
    mov  cx,0xf16c
...
    mov  cx,0x008c         ; time separator
    mov  ax,0xf16c
; file 0x669EC
    push cx
    push si
    call DC98:0D2A       ; INT 21h AH=2A wrapper
    call DC98:0D4E       ; INT 21h AH=2C wrapper
    mov  ax,0x72d7
    mov  bx,0x72df
    mov  si,[0x86ea]
    mov  cl,[si-0x7710] ; home daylight flag
    call DC98:9AC8
    mov  ax,0x72d7
    mov  bx,0x72df
    mov  cx,0
    mov  es,cx
    mov  cx,[es:0x86ec]
    call DC98:9FD4       ; apply city delta
    call DC98:9AC8
; file 0x68258
    inc  di
    cmp  di,0x0003
    xor  di,di
    mov  ax,0x0001
    sub  ax,si
    mov  si,ax
...
    mov  ax,si
    mul  bx
    mov  dx,0x000e
    mov  cx,0xf138
    call DC98:A06C
    call DC98:0D19
