; Generated from disasm: C000:53E9-59B7
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x53E9


translate_key_event_C000_5915:
; file 0x45915
    xor  bh,bh
    test byte [0x6d51],0x01
    jnz  direct_table_C000_598B
    test byte [0x6d51],0x08
    jnz  ram_table_mode_C000_5995
    test dh,0x80
    jnz  high_modifier_C000_595A
normal_table_mode_C000_5936:
    mov  cl,4
    shr  dh,cl
    mov  bl,dh
    mov  al,[cs:bx+0x5a57]
    call table_lookup_C000_5A07
    cmp  al,0x0c
    jnz  translated_C000_594D
    xor  byte [0x7673],0x40
    ret
latched_special_C000_594E:
    mov  al,0x0e
    call table_lookup_C000_5A07
    mov  [0x6daa],al
    mov  al,0xec
    ret
high_modifier_C000_595A:
    mov  bl,dl
    test dh,0x40
    jnz  rom_special_C000_5966
    mov  al,[bx+0x7055]
    ret
rom_special_C000_5966:
    mov  bx,0x53d7
    mov  ax,[cs:bx]
    mov  bl,dl
    xor  bh,bh
    add  bx,ax
    mov  al,[cs:bx]
    cmp  al,0x64
    jz   return_f5_C000_5985
    cmp  al,0x76
    jz   return_ctrl_z_C000_5988
    mov  byte [0x70e9],0
    mov  al,0xff
    ret
direct_table_C000_598B:
    mov  bl,dl
    add  bx,0x59b7
    mov  al,[cs:bx]
    ret

ram_table_mode_C000_5995:
    test dh,0x40
    jz   ram_select_C000_599F
    test dh,0x80
    jnz  rom_special_C000_5966
    mov  cl,4
    shr  dh,cl
    mov  bl,dh
    mov  al,[cs:bx+0x5a57]
    mov  bl,al
    mov  ax,[bx+0x6814]
    mov  bl,dl
    add  bx,ax
    mov  al,[bx]
    ret
