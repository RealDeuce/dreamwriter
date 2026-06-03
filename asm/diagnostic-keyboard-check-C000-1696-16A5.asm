; Generated from disasm: C000:1696-16A5
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x1696


diagnostic_key_input_C000_1696:
; file 0x41696
    push cx
    push dx
    push si
    push di
    push bp
    call C000:08A3
    xor  ah,ah
    pop  bp
    pop  di
    pop  si
    pop  dx
    pop  cx
    retf
diagnostic_keyboard_setup_DC98_0E70:
; file 0x5D7F0
