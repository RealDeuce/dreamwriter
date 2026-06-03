; Generated from disasm: C000:0A6A-0AD9
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x0A6A


combined_battery_status_C000_0A6A:
; file 0x40A6A
    in   al,0xa0
    test al,0x80
    jz   card_present_for_warning_C000_0A72
    or   al,0x10
    xor  al,0x10
    test al,0x1c
    jz   no_warning_C000_0A90
    call main_battery_low_C000_0A93
    mov  al,0x01
...
    call retention_battery_low_C000_0AA4
    mov  al,0x02
...
    call card_battery_low_C000_0AB2
    mov  al,0x03
main_battery_low_C000_0A93:
; file 0x40A93
    in   al,0xa0
    test al,0x08
    jz   no_warning_C000_0A90
    in   al,0xa0
    test al,0x08
    jz   no_warning_C000_0A90
    xor  al,al
    inc  al
    ret

retention_battery_low_C000_0AA4:
    in   al,0xa0
    test al,0x04
    jz   no_warning_C000_0A90
    in   al,0xa0
    test al,0x04
    jz   no_warning_C000_0A90
    jmp  C000:0A9F
card_battery_low_C000_0AB2:
    in   al,0xa0
    test al,0x80
    jnz  no_warning_C000_0A90
    test al,0x10
    jnz  no_warning_C000_0A90
    in   al,0xa0
    test al,0x10
    jnz  no_warning_C000_0A90
    jmp  C000:0A9F
card_access_check_C000_0AC4:
; file 0x40AC4
    push ax
    in   al,0xa0
    test al,0x80
    pop  ax
    clc
    jnz  card_status_carry_C000_0AD8
    ret

card_write_protect_C000_0ACE:
    push ax
    in   al,0xa0
    test al,0x40
    pop  ax
    clc
    jnz  card_status_carry_C000_0AD8
    ret

card_status_carry_C000_0AD8:
    stc
    ret
