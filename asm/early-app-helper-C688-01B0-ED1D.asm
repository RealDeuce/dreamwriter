; Generated from disasm: C688:01B0-ED1D
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x01B0


app_loop_forced_diagnostic_event_C688_ED1A:
; file 0x5559A
    call C688:01B0
    jmp  C688:EC9F
forced_diagnostic_wrapper_C688_01B0:
; file 0x46A30
    call C000:123C
    ret
forced_diagnostic_entry_C000_123C:
; file 0x4123C
