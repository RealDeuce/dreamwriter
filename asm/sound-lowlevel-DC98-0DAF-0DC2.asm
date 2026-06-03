; Generated from disasm: DC98:0DAF-0DC2
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x0DAF


tone_duration_wrapper_DC98_0DAF:
; file 0x5D72F
    push bp
    push di
    push si
    push dx
    push cx
    mov  cx,bx
    mov  bx,ax
    call C000:087F
    pop  cx
    pop  dx
    pop  si
    pop  di
    pop  bp
    retf
tone_duration_far_C000_087F:
; file 0x4087F
