; Generated from disasm: C000:123C-1251
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x123C


forced_diagnostic_entry_C000_123C:
; file 0x4123C
    call C000:1247
    retf
diagnostic_banner_and_loop_C000_1247:
; file 0x41247
    call C000:1272       ; draw short banner
    call C000:128F       ; diagnostic command parser
    jc   C000:1251
    jmp  C000:1247
    ret
diagnostic_chord_gate_C000_1240:
; file 0x41240
    call C000:1252
    jz   C000:1247
    clc
    ret
