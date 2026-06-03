; Generated from disasm: C000:0376-0BAE
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x0376


prepare_rtc_alarm_C000_0376:
; file 0x40376
    in   al,0xdd
    and  al,0xf7
    out  0xdd,al
    push es
    call DC98:D3BB
    pop  es
    call full_alarm_compare_C000_0B90
    jc   restore_timer_and_program_fallback_test
    call short_alarm_compare_C000_0B7C
    pushf
    in   al,0xdd
    or   al,0x08
    out  0xdd,al
    popf
    jc   fallback_alarm_C000_03A4
    call program_selected_alarm_C000_0A11
    mov  byte [0x6d4e],0

enable_alarm_output_C000_039D:
    in   al,0xdd
    or   al,0x04
    out  0xdd,al
    ret

fallback_alarm_C000_03A4:
    call program_minute_plus_one_C000_0A3F
    mov  byte [0x6d4e],1
    jmp  enable_alarm_output_C000_039D
program_selected_alarm_C000_0A11:
; file 0x40A11
    push ax
    push bx
    push dx
    mov  al,0xf9
    out  0xdd,al
    mov  al,0xfd
    out  0xdf,al
    mov  dx,0x00d8
    mov  bx,0x6d45
program_selected_loop_C000_0A22:
    mov  al,[bx]
    and  al,0x0f
    cmp  dx,0x00d6
    jz   skip_this_port_C000_0A2D
    out  dx,al
    cmp  dx,0x00d2
    jz   selected_done_C000_0A37
    inc  bx
    dec  dx
    jmp  program_selected_loop_C000_0A22
selected_done_C000_0A37:
    mov  al,0xf8
    out  0xdd,al
    pop  dx
    pop  bx
    pop  ax
    ret
program_minute_plus_one_C000_0A3F:
; file 0x40A3F
    mov  al,0xf9
    out  0xdd,al
    mov  al,0xfd
    out  0xdf,al
    mov  al,[0x6d98]
    mov  ah,[0x6d99]
    inc  al
    cmp  al,0x0a
    jnz  write_fallback_minute_C000_0A5F
    mov  al,0
    inc  ah
    cmp  ah,0x06
    jnz  write_fallback_minute_C000_0A5F
    mov  ah,0
    out  0xd2,al
    mov  al,ah
    out  0xd3,al
    mov  al,0xf8
    out  0xdd,al
    ret
rtc_snapshot_C000_0B60:
; file 0x40B60
    push ax
    push bx
    push dx
    mov  dx,0x00dc
    mov  bx,0x6da2
snapshot_loop_C000_0B69:
    in   al,dx
    and  al,0x0f
    mov  [bx],al
    cmp  dx,0x00d0
    dec  bx
    dec  dx
    jmp  snapshot_loop_C000_0B69
short_alarm_compare_C000_0B7C:
; file 0x40B7C
    call rtc_snapshot_C000_0B60
    mov  di,0x6d9e
    mov  si,0x6d45
    mov  cx,0x0007
    jmp  compare_loop_C000_0BA2

full_alarm_compare_C000_0B90:
    call rtc_snapshot_C000_0B60
    mov  di,0x6da2
    mov  si,0x6d41
    mov  cx,0x000b

compare_loop_C000_0BA2:
    lodsb
    cmp  al,[di]
    jnz  alarm_compare_mismatch_C000_0BAD
    dec  di
    loop compare_loop_C000_0BA2
    stc
    ret
    clc
    ret
