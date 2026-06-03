; Generated from disasm: C688:5B83-D004
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x5B83


printer_load_setup_state_C688_C0D7:
; file 0x52957
    mov  si,0x6d59
    mov  al,[si]
    and  al,0x7
    cmp  al,0x8
    jc   printer_model_ok_C688_C0E4
    mov  al,0
printer_model_ok_C688_C0E4:
    mov  [0x829e],al
    mov  ah,[si+0x2]
    and  ah,0x1
    shl  ah,1
    mov  [0x82a3],ah
    ret
printer_char_output_stubs_C688_C057:
; file 0x528D7
    jmp  printer_char_tail_C688_CFF1
    mov  al,0xe0
    jmp  printer_char_tail_C688_CFF1
    mov  al,0xe1
    jmp  printer_char_tail_C688_CFF1
    mov  al,0xe2
    jmp  printer_char_tail_C688_CFF1
printer_char_tail_C688_CFF1:
; file 0x53871
    call printer_spacing_flush_C688_CFC3
    cmp  bx,[0x78f9]
    jng  loc_CFFA
printer_char_emit_C688_CFFA:
loc_CFFA:
    mov  dl,al
    call printer_emit_byte_C688_C82A
    call printer_spacing_restore_C688_CFCF
    xor  cl,cl
    ret
printer_emit_byte_C688_C82A:
; file 0x530AA
    test byte [0x82a3],0x8
    jz   printer_emit_not_canceled_C688_C832
    ret
printer_emit_not_canceled_C688_C832:
    test byte [0x82a3],0x1
    jz   printer_emit_allowed_C688_C83A
    ret
printer_emit_allowed_C688_C83A:
    mov  [0x8295],dl
    mov  si,0x6d59
    test byte [si+0x1],0x1
    jnz  printer_emit_serial_C688_C850
    mov  ah,0x5
    int  0x21
    or   al,al
    jnz  printer_emit_error_C688_C859
    ret
printer_emit_serial_C688_C850:
    mov  ah,0x4
    int  0x21
    or   al,al
    jnz  printer_emit_error_C688_C859
    ret
printer_emit_error_C688_C859:
    call printer_poll_control_key_C688_CB64
    cmp  al,0x3
    jnz  printer_maybe_pause_C688_C863
    jmp  printer_cancel_C688_CB58
printer_maybe_pause_C688_C863:
    cmp  al,0x20
    jz   printer_pause_retry_C688_C868
    ret
printer_pause_retry_C688_C868:
    call printer_pause_loop_C688_CBA5
    mov  dl,[0x8295]
    jmp  printer_emit_byte_C688_C82A
printer_cancel_C688_CB58:
; file 0x533D8
    mov  si,0x21
    call printer_show_resource_C688_CBE4
    or   byte [0x82a3],0x8
    ret

printer_poll_control_key_C688_CB64:
    push di
    mov  ah,0xb
    int  0x21
    pop  di
    cmp  al,0
    jnz  printer_key_ready_C688_CB6F
    ret
printer_key_ready_C688_CB6F:
    push di
    mov  ah,0x8
    int  0x21
    pop  di
    xor  bx,bx
    mov  si,0xcb8e
    cmp  al,[cs:bx+si]
    jz   printer_key_accepted_C688_CB88
    inc  bx
    cmp  byte [cs:bx+si],0
    jnz  printer_key_filter_C688_CB7A
    jmp  printer_poll_control_key_C688_CB64
printer_key_accepted_C688_CB88:
    push ax
    call printer_drain_keys_C688_CB92
    pop  ax
    ret
printer_pause_loop_C688_CBA5:
; file 0x53425
    mov  si,0x24
    mov  ch,0x2
    mov  al,[0x8db3]
    and  al,0x3
    jnz  printer_pause_show_C688_CBBB
    mov  si,0x33
    jmp  printer_pause_show_C688_CBBB
printer_between_pages_entry_C688_CBB6:
    mov  si,0x22
    mov  ch,0x2
printer_pause_show_C688_CBBB:
    call printer_show_resource2_C688_CBEB
printer_pause_wait_C688_CBBE:
    call printer_poll_control_key_C688_CB64
    cmp  al,0xda
    jz   printer_pause_continue_C688_CBCF
    cmp  al,0x3
    jnz  printer_pause_wait_C688_CBBE
    or   byte [0x82a3],0x8
    ret
printer_pause_continue_C688_CBCF:
    push ax
    mov  si,0x1a
    mov  al,[0x8db3]
    and  al,0x3
    jnz  printer_restore_progress_C688_CBDD
    mov  si,0x1f
printer_restore_progress_C688_CBDD:
    mov  ch,0x2
    call printer_show_resource2_C688_CBEB
    pop  ax
    ret
printer_emit_cs_counted_C688_CC1F:
; file 0x5349F
    push dx
    mov  dh,[cs:si]
    inc  dh
    inc  si
printer_emit_cs_loop_C688_CC26:
    dec  dh
    jz   printer_emit_cs_done_C688_CC34
    mov  dl,[cs:si]
    push si
    call printer_emit_byte_C688_C82A
    pop  si
    jmp  printer_emit_cs_loop_C688_CC26
printer_emit_cs_done_C688_CC34:
    pop  dx
    xor  cl,cl
    ret

printer_emit_ds_counted_C688_CC38:
    push dx
    xor  dx,dx
    mov  dh,[si]
    inc  dh
    inc  si
printer_emit_ds_loop_C688_CC40:
    dec  dh
    jz   printer_emit_ds_done_C688_CC4D
    mov  dl,[si]
    push si
    call printer_emit_byte_C688_C82A
    pop  si
    jmp  printer_emit_ds_loop_C688_CC40
printer_emit_ds_done_C688_CC4D:
    pop  dx
    xor  cl,cl
    ret

printer_emit_spaces_C688_CC51:
    mov  dl,0x20
    inc  dh
printer_spaces_loop_C688_CC55:
    dec  dh
    jz   printer_spaces_done_C688_CC5E
    call printer_emit_byte_C688_C82A
    jmp  printer_spaces_loop_C688_CC55
printer_spaces_done_C688_CC5E:
    xor  cl,cl
    ret
formatter_emit_byte_C688_5B83:
; file 0x4C403
    mov  cl,0x0a
    jmp  formatter_store_byte_C688_5B89
formatter_emit_byte_alt_C688_5B87:
    mov  cl,0x3a
formatter_store_byte_C688_5B89:
    mov  al,dl
    mov  [0x79c3],al
    jmp  formatter_shared_state_C688_5B9A
formatter_mode_19_C688_5B90:
    mov  cl,0x19
    jmp  formatter_zero_dl_C688_5B96
formatter_mode_29_C688_5B94:
    mov  cl,0x29
formatter_zero_dl_C688_5B96:
    mov  dl,0
    jmp  formatter_shared_state_C688_5B9A
formatter_shared_state_C688_5B9A:
    push word [0x75ef]
    mov  word [0x75ef],0x79c3
    mov  byte [0x7956],0
    mov  al,[0x793d]
    mov  [0x799a],al
    mov  al,[0x793e]
    mov  [0x795f],al
    mov  al,[0x78e5]
    mov  [0x796b],al
    mov  si,[0x78f5]
    mov  [0x7946],si
    mov  si,[0x7928]
    mov  [0x7963],si
    mov  si,[0x78f3]
    mov  [0x7944],si
    mov  al,cl
    and  al,0xf
    mov  ah,0
    mov  si,ax
    add  si,0x5b6d
    mov  ch,[cs:si]
    mov  word [0x75ed],0x793b
