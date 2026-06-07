; Generated from disasm: C000:123C-1251
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x123C

app_loop_forced_diagnostic_event_C688_ED1A:
forced_diagnostic_wrapper_C688_01B0:
forced_diagnostic_entry_C000_123C:
    call diagnostic_banner_and_loop_C000_1247
    db 0xcb    ; retf
diagnostic_chord_gate_C000_1240:
    call diagnostic_chord_compare_C000_1252
    jz diagnostic_banner_and_loop_C000_1247
    db 0xf8    ; clc
    db 0xc3    ; ret
diagnostic_banner_and_loop_C000_1247:
    call diagnostic_draw_short_banner_C000_1272  ; draw short banner
    call diagnostic_command_loop_C000_128F  ; diagnostic command parser
    jc loc_1251
    jmp diagnostic_banner_and_loop_C000_1247
loc_1251:
    db 0xc3    ; ret

; helper call targets covered by other slices
diagnostic_chord_compare_C000_1252 equ 0x1252
diagnostic_command_loop_C000_128F equ 0x128F
diagnostic_draw_short_banner_C000_1272 equ 0x1272
