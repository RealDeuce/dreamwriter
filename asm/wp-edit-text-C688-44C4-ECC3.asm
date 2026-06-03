; Generated from disasm: C688:44C4-ECC3
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x44C4


wp_top_menu_default_return_C688_EB15:
; file 0x55395
    call C688:77AA
    xor  al,al
    mov  [0x7520],al
    push es
    call DC98:2807
    pop  es
    or   al,al
    jz   C688:EB2B
    jmp  C688:EF45
    jmp  C688:EC9F
root_edit_text_shared_loop_C688_EC9F:
; file 0x5551F
    call C688:77DD
    mov  al,0xff
    mov  [0x75e4],al
    call C688:7795
    call C688:F13A
    call C688:8F40
    call C688:12D6
    mov  [0x794a],al
    call C688:44C4
    mov  al,[0x794a]
    cmp  al,0xff
    jnz  C688:ECC3
    jmp  C688:ED84
    call C688:92DF
editor_boot_update_sequence_C688_7766:
; file 0x4DFE6
    mov  al,0x0a
    call C688:8F43
    mov  si,0x0003
    call C688:9541
    call C688:599C
    call C688:44C4
    mov  al,0x04
    call C688:77A3
    mov  al,0x09
    call C688:77A3
    mov  al,0x02
    call C688:77A3
    mov  al,0x03
    call C688:77A3
    mov  al,0x03
    call C688:77A3
    mov  al,0x03
    call C688:77A3
    mov  al,0x05
    call C688:77A3
    mov  al,0x00
    call C688:77A3
    call C688:96E1
    ret
editor_update_id_helper_C688_77A3:
; file 0x4E023
    call C688:4473
    call C688:0D05
    ret
snapshot_active_editor_state_C688_44C4:
; file 0x4AD44
    mov  di,[0x7965]
    mov  si,0x78d5
    mov  cx,0x006b
    push es
    mov  bp,0
    mov  es,bp
    cld
    rep movsb
    pop  es
    mov  dx,di
    ret
