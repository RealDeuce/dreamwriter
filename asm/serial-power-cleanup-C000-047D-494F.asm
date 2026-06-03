; Generated from disasm: C000:047D-494F
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x047D


validate_rs232_setup_C000_48D5:
; file 0x448D5
    cld
    mov  si,0x6d2a
    lodsb              ; baud index
    cmp  al,0x03
    jc   rs232_invalid_C000_48F7
    cmp  al,0x08
    jnc  rs232_invalid_C000_48F7
    lodsb              ; bit length
    cmp  al,0x02
    jnc  rs232_invalid_C000_48F7
    lodsb              ; stop bits
    cmp  al,0x02
    jnc  rs232_invalid_C000_48F7
    lodsb              ; parity
    cmp  al,0x03
    jnc  rs232_invalid_C000_48F7
    lodsb              ; XON/XOFF
    cmp  al,0x02
    jnc  rs232_invalid_C000_48F7
    ret

rs232_invalid_C000_48F7:
    or   byte [0x6d53],0x04
    ret
validate_printer_setup_C000_4917:
; file 0x44917
    cld
    mov  si,0x6d59
    lodsb
    cmp  al,0x07
    jnc  printer_invalid_C000_492B
...
printer_invalid_C000_492B:
    or   byte [0x6d53],0x08
validate_power_setup_C000_4941:
; file 0x44941
    cld
    mov  si,0x6d2f
    lodsb
    cmp  al,0x07
    jnc  printer_invalid_C000_492B
    lodsb
    cmp  al,0x04
    jnc  printer_invalid_C000_492B
    ret
retained_cleanup_C000_047D:
; file 0x4047D
    call timer_disarm_C000_0B50
    mov  ax,[0x6d31]
    mov  [0x680b],ax
    mov  al,[0x6d4f]
    mov  [0x6d50],al
    test byte [0x6d4f],0x10
    jnz  retained_cleanup_done_C000_0499
    call serial_power_down_C000_0D2A
    call serial_delay_countdown_C000_0BEC
    ret
