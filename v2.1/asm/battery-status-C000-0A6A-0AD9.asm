; Generated from disasm: C000:0A6A-0AD9
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x0A6A

combined_battery_status_C000_0A6A:
    db 0xe4, 0xa0    ; in al,0xa0
    db 0xa8, 0x80    ; test al,0x80
    jz card_present_for_warning_C000_0A72
    db 0x0c, 0x10    ; or al,0x10
    db 0x34, 0x10    ; xor al,0x10
    db 0xa8, 0x1c    ; test al,0x1c
    jz no_warning_C000_0A90
    call main_battery_low_C000_0A93
    db 0x74, 0x03
    db 0xb0, 0x01    ; mov al,0x01
    db 0xc3
    call retention_battery_low_C000_0AA4
    db 0x74, 0x03
    db 0xb0, 0x02    ; mov al,0x02
    db 0xc3
    call card_battery_low_C000_0AB2
    db 0x74, 0x03
    db 0xb0, 0x03    ; mov al,0x03
    db 0xc3, 0x32, 0xc0, 0xc3
main_battery_low_C000_0A93:
    db 0xe4, 0xa0    ; in al,0xa0
    db 0xa8, 0x08    ; test al,0x08
    jz no_warning_C000_0A90
    db 0xe4, 0xa0    ; in al,0xa0
    db 0xa8, 0x08    ; test al,0x08
    jz no_warning_C000_0A90
loc_0A9F:
    db 0x32, 0xc0    ; xor al,al
    db 0xfe, 0xc0    ; inc al
    db 0xc3    ; ret
retention_battery_low_C000_0AA4:
    db 0xe4, 0xa0    ; in al,0xa0
    db 0xa8, 0x04    ; test al,0x04
    jz no_warning_C000_0A90
    db 0xe4, 0xa0    ; in al,0xa0
    db 0xa8, 0x04    ; test al,0x04
    jz no_warning_C000_0A90
    jmp loc_0A9F
card_battery_low_C000_0AB2:
    db 0xe4, 0xa0    ; in al,0xa0
    db 0xa8, 0x80    ; test al,0x80
    jnz no_warning_C000_0A90
    db 0xa8, 0x10    ; test al,0x10
    jnz no_warning_C000_0A90
    db 0xe4, 0xa0    ; in al,0xa0
    db 0xa8, 0x10    ; test al,0x10
    jnz no_warning_C000_0A90
    jmp loc_0A9F
card_access_check_C000_0AC4:
    db 0x50    ; push ax
    db 0xe4, 0xa0    ; in al,0xa0
    db 0xa8, 0x80    ; test al,0x80
    db 0x58    ; pop ax
    db 0xf8    ; clc
    jnz card_status_carry_C000_0AD8
    db 0xc3    ; ret
card_write_protect_C000_0ACE:
    db 0x50    ; push ax
    db 0xe4, 0xa0    ; in al,0xa0
    db 0xa8, 0x40    ; test al,0x40
    db 0x58    ; pop ax
    db 0xf8    ; clc
    jnz card_status_carry_C000_0AD8
    db 0xc3    ; ret
card_status_carry_C000_0AD8:
    db 0xf9    ; stc
    db 0xc3    ; ret

; helper call targets covered by other slices
card_present_for_warning_C000_0A72 equ 0x0A72
no_warning_C000_0A90 equ 0x0A90
