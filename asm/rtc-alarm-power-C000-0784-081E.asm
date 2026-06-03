; Generated from disasm: C000:0784-081E
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x0784


alarm_wake_discriminator_C000_0784:
; file 0x40784
    cmp  byte [0x6d4e],0
    ...            jnz  fallback_alarm_active
    call alarm_full_compare_C000_0B90
...
    call DC98:DB5E
...
    call DC98:D3BB
    call save_framebuffer_C000_07E9
...
    call C000:0A3F
    mov  byte [0x6d4e],1
    call C000:039D
    jmp  C000:0370
save_framebuffer_C000_07E9:
; file 0x407E9
    call battery_warning_clear_C000_4C39
    mov  si,0x1000
    mov  di,0x94f0
    jmp  framebuffer_copy_C000_07FA

restore_framebuffer_C000_07F4:
    mov  si,0x94f0
    mov  di,0x1000
framebuffer_copy_C000_07FA:
    push es
    mov  ax,ds
    mov  es,ax
    cld
    mov  cx,0x0800
    rep  movsw
    pop  es
    ret
alarm_wake_wrapper_C000_0807:
; file 0x40807
    call alarm_wake_discriminator_C000_0784
    ...            jc   no_alarm_wake
...
    call alarm_buzzer_C000_0883
    call alarm_buzzer_C000_0883
    call restore_framebuffer_C000_07F4
    ret
