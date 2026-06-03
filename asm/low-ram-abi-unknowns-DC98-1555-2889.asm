; Generated from disasm: DC98:1555-2889
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x1555


wrapped_text_DC98_1555:
; file 0x5DED5
    push bp
    mov  bp,sp
...
    mul  cx              ; total capacity = BX * CX
...
    mov  byte [di],0xff
    mov  byte [di],0x40  ; display text record
...
    mov  al,[si]
    inc  si
...
    mov  byte [si],0xff
    mov  byte [si],0x0e  ; spacing/pad control
...
    call C000:67AD
    retf
set_input_idle_callback_DC98_1859:
; file 0x5E1D9
    push bp
    mov  bp,sp
...
    mov  [0x74e5],bx     ; callback offset
    mov  [0x74e7],ax     ; callback segment
    retf
prompt_selector_DC98_214E:
; file 0x5EACE
    push bp
    mov  bp,sp
...
    push word [bp+0x0a]
    push word [bp+0x06]
    mov  ax,[bp-0x04]
    mov  bx,[bp-0x02]
    mov  cx,[si]
    call DC98:20AA
...
    call DC98:0CF9
...
    pop  bp
    retf
    xor  ax,ax
    retf
