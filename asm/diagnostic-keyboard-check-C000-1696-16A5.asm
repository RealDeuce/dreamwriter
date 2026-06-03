; Generated from disasm: C000:1696-16A5
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x1696

diagnostic_keyboard_check_DC98_0CA2:
clear_next_key_cell:
poll_key:
poll_continue:
diagnostic_key_input_C000_1696:
    db 0x51    ; push cx
    db 0x52    ; push dx
    db 0x56    ; push si
    db 0x57    ; push di
    db 0x55    ; push bp
    call loc_08A3
    db 0x32, 0xe4    ; xor ah,ah
    db 0x5d    ; pop bp
    db 0x5f    ; pop di
    db 0x5e    ; pop si
    db 0x5a    ; pop dx
    db 0x59    ; pop cx
    db 0xcb    ; retf

; helper call targets covered by other slices
loc_08A3 equ 0x08A3
