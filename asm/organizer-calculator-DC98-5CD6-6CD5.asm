; Generated from disasm: DC98:5CD6-6CD5
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x5CD6


; file 0x633B8
    push cx
    push dx
    call DC98:0E70
    mov  ax,0x0002
    push ax
    mov  ax,0x0008
    mov  bx,0x001b
    mov  cx,0x0189
    mov  dx,0x0025
    call DC98:0EE5       ; clear top display area
...
    mov  byte [0x8648],0x0c
    mov  byte [0x8649],0x0d
    mov  ax,0x85ee
    call DC98:54A9       ; clear input/result record
    mov  ax,0x8600
    call DC98:54A9       ; clear accumulator record
    mov  word [0x85e8],0
    xor  ax,ax
    call DC98:583E       ; redraw input display
    call DC98:5C5C       ; redraw memory display
    mov  byte [0x6807],1
    call DC98:640F       ; main calculator loop
    mov  byte [0x6807],0
; file 0x62656
    push cx
    push si
    mov  bx,ax
    cmp  word [0x85e8],0
...
DC98:5CE8  cmp  byte [si],0
DC98:5CEB  jz   DC98:5CFC
DC98:5CED  cmp  byte [bx],0
DC98:5CF2  mov  al,1
DC98:5CF8  mov  [bx],al
; file 0x62A51
    push bp
    mov  bp,sp
    sub  sp,0x20        ; scratch product
...
    mul  byte [bx]      ; digit * digit
    add  bl,[bp+si-0x1f]
    mov  cl,0x0a
    div  cl             ; base-10 carry/remainder
; file 0x62B38
    push bp
    mov  bp,sp
    sub  sp,0x02
    mov  word [0x85e8],2 ; division by zero
...
    mov  ax,di
    mov  bx,si
    call DC98:5E2D       ; subtract divisor
    inc  cx             ; quotient digit
    mov  ax,di
    mov  bx,si
    call DC98:5D9F       ; compare
    cmp  ax,0
    jnl  DC98:6239
; file 0x62C1E
    push cx
    push dx
    mov  dx,ax
    cmp  word [0x85ea],1
    call DC98:5FE0
...
    call DC98:60AB
    call DC98:60D1
    call DC98:61B8
; file 0x63506
    push cx
    mov  si,ax
    cmp  byte [si],1
    mov  word [0x85e8],3
...
    mov  ax,0x86aa
    mov  bx,0x86ca
    call DC98:6B4C
...
    mov  [si+0x11],dl
    call DC98:5F42
    call DC98:5ED4
