; Generated from disasm: DC98:0CA2-0E80
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x0CA2


diagnostic_keyboard_check_DC98_0CA2:
; file 0x5D622
    push bp
    mov  bp,sp
    sub  sp,0x40
    push cx
    push si
    call DC98:0E70        ; emit EDFA:0002 setup stream
    xor  si,si

clear_next_key_cell:
    mov  ax,si
    call DC98:0137        ; draw unpressed key cell
    mov  byte [bp+si-0x40],0
    inc  si
    cmp  si,0x40
    jl   clear_next_key_cell

    call DC98:055E        ; static keyboard grid
    call DC98:099F        ; footer/legend block
    xor  cx,cx           ; count of distinct keys seen

poll_key:
    call C000:1696        ; AX = key/event number
    mov  si,ax
    dec  si              ; convert 1..64 to 0..63
    cmp  si,0
    jl   poll_continue
    cmp  si,0x3f
    jg   poll_continue
    cmp  byte [bp+si-0x40],0
    jnz  poll_continue
    mov  byte [bp+si-0x40],1
    mov  ax,si
    call DC98:02AE        ; draw pressed key marker
    inc  cx

poll_continue:
    cmp  cx,0x40
    jnz  poll_key
    pop  si
    pop  cx
    mov  sp,bp
    pop  bp
    retf
diagnostic_key_input_C000_1696:
; file 0x41696
diagnostic_keyboard_setup_DC98_0E70:
; file 0x5D7F0
    push cx
    mov  ax,0x0002
    mov  bx,0xedfa
    mov  cx,0x000f
    call C000:67AD
    pop  cx
    retf
