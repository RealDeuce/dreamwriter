; Generated from disasm: DC98:2821-2828
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x2821

wp_top_menu_edit_text_return_DC98_2821:
    db 0x3d, 0x31, 0x00    ; cmp ax,0x31
    jnz loc_282A
    db 0x33, 0xc0    ; xor ax,ax
    jmp loc_2885

; helper call targets covered by other slices
loc_282A equ 0x282A
loc_2885 equ 0x2885
