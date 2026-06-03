; Generated from disasm: C000:087F-09AD
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x087F


tone_duration_far_C000_087F:
; file 0x4087F
    call C000:096A
    retf
tone_duration_C000_096A:
; file 0x4096A
    push ax
    push bx
    push cx
    or   bx,bx
    jz   tone_off_for_rest_C000_0976
    call tone_on_C000_099C
    jmp  C000:0979
    call tone_off_C000_09A9
...
    call main_battery_low_C000_0A93
    stc
    jnz  C000:0995
...
    call tone_off_C000_09A9
    pop  cx
    pop  bx
    pop  ax
    ret
tone_on_C000_099C:
; file 0x4099C
    mov  al,bl
    out  0x50,al
    mov  al,bh
    out  0x51,al
    mov  al,0x7f
    out  0x52,al
    ret

tone_off_C000_09A9:
; file 0x409A9
    mov  al,0xff
    out  0x52,al
    ret
