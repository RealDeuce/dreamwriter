; Generated from disasm: C000:4961-4CF0
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x4961


retained_request_C000_4961:
; file 0x44961
    cmp  word [0x680d],0
    ...            jnz  no_retained_request
    cmp  word [0x6809],0x1992
...
    stc
    ret
idle_until_event_C000_49F8:
; file 0x449F8
    call main_battery_low_C000_0A93
    jnz  power_event_C000_4A1B
    call retained_request_C000_4961
...
C000:4A25  ...               ; save resume target C000:49FD
C000:4A34  ...               ; save resume target C000:4977
C000:4A43  ...               ; save resume target C000:4A8D
...
    mov  al,[0x6d4f]
    out  0x60,al
    sti
    hlt
battery_warning_clear_C000_4C39:
; file 0x44C39
C000:4C39  ...               ; restore saved 48x40 screen area if active
    mov  byte [0x6d52],0
    ret

battery_warning_poll_C000_4C91:
; file 0x44C91
C000:4C91  ...               ; rotate slots 2, 3, 4 in [6D52]
    mov  byte [0x6d52],2
    call save_warning_area_C000_4C6E
    call draw_warning_icon_C000_4D07
