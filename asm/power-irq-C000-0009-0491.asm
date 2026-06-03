; Generated from disasm: C000:0009-0491
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x0009


seed_irq_ff_stub:
; file 0x4001E
    jmp  irq_ff_warm_power_C000_02EE
irq_ff_warm_power_C000_02EE:
; file 0x402EE
    push ax
    push bx
    push ds
    mov  ax,0
    mov  ds,ax
    mov  al,0x01
    out  0x90,al
    mov  ax,[0x6809]
    cmp  ax,0x1995
    jz   warm_state_C000_0344
    cmp  ax,0x1999
    jz   warm_diag_target_C000_0329
    cmp  word [0x680d],byte +0
    jnz  mark_power_event_C000_031E
    cmp  ax,0x0001
    jz   warm_diag_target_C000_0329
    push si
    push di
    push cx
    call C000:1252       ; diagnostic chord compare
    pop  cx
    pop  di
    pop  si
    jz   warm_diag_target_C000_0329

mark_power_event_C000_031E:
    mov  word [0x6809],0x1992
    pop  ds
    pop  bx
    pop  ax
    sti
    iret
warm_diag_target_C000_0329:
    mov  byte [0x6807],0
    mov  word [0x6d79],0x4a8d
    mov  ax,cs
    mov  [0x6d7b],ax
    mov  word [0x6d81],0x1995
    and  byte [0x6d51],0xf7

warm_state_C000_0344:
    mov  bp,sp
    add  bp,byte +0x06
    mov  ax,[bp+0x00]   ; interrupted IP
    mov  [0x6d85],ax
    add  bp,byte +0x02
    mov  ax,[bp+0x00]   ; interrupted CS
    mov  [0x6d87],ax
    call C000:0B50
    jmp  terminal_power_handoff_C000_0370
retained_power_transition_C000_035D:
; file 0x4035D
    call checksum_saved_context_C000_0438
    cmp  byte [0x7036],0
    jz   C000:036A
    call checksum_builtin_store_C000_044B
    call retained_cleanup_C000_047D
    call prepare_rtc_alarm_C000_0376

terminal_power_handoff_C000_0370:
    mov  al,0x01
    out  0x70,al
    jmp  short C000:0374
prepare_rtc_alarm_C000_0376:
; file 0x40376
    in   al,0xdd
    and  al,0xf7         ; pause RTC timer advance
    out  0xdd,al
    push es
    call DC98:D3BB       ; select next alarm
    pop  es
    call C000:0B90       ; full date/time compare
    jc   C000:038B
    call C000:0B7C       ; shorter day/time compare
    pushf
    in   al,0xdd
    or   al,0x08         ; resume RTC timer advance
    out  0xdd,al
    popf
    jc   fallback_alarm_C000_03A4
    call C000:0A11       ; program selected alarm
    mov  byte [0x6d4e],0
    in   al,0xdd
    or   al,0x04         ; enable alarm output
    out  0xdd,al
    ret

fallback_alarm_C000_03A4:
    call C000:0A3F       ; current minute + 1
    mov  byte [0x6d4e],1
    jmp  C000:039D
seed_irq_f8_stub:
; file 0x40009
    jmp  irq_f8_save_suspend_C000_03AE
irq_f8_save_suspend_C000_03AE:
; file 0x403AE
    push ds
    push ax
    push bp
    mov  bp,ds
    mov  ax,0
    mov  ds,ax
    mov  al,0x80
    out  0x90,al
    cmp  word [0x6809],byte +1
    jz   reuse_saved_target_C000_042A
    cmp  word [0x6809],0x1995
    jz   reuse_saved_target_C000_042A

    mov  [0x6d73],bp    ; DS
    mov  [0x6d67],bx
    mov  [0x6d69],cx
    mov  [0x6d6b],dx
    mov  [0x6d6d],si
    mov  [0x6d6f],di
    mov  [0x6d75],es
    mov  [0x6d77],ss
    mov  bp,sp
    add  bp,byte +0x06
    mov  ax,[bp+0x00]   ; interrupted IP
    mov  [0x6d79],ax
    mov  [0x6d85],ax
    add  bp,byte +0x02
    mov  ax,[bp+0x00]   ; interrupted CS
    mov  [0x6d7b],ax
    mov  [0x6d87],ax
    add  bp,byte +0x02
    mov  ax,[bp+0x00]   ; FLAGS
    mov  [0x6d7f],ax
    add  bp,byte +0x02
    mov  [0x6d7d],bp    ; SP after interrupt frame
    pop  bp
    mov  [0x6d71],bp
    pop  ax
    mov  [0x6d65],ax
    call checksum_saved_context_C000_0438
    call retained_cleanup_C000_047D
    mov  al,0xf8
    out  0xdd,al
    jmp  short C000:0428

reuse_saved_target_C000_042A:
    mov  ax,[0x6d79]
    mov  [0x6d85],ax
    mov  ax,[0x6d7b]
    mov  [0x6d87],ax
    jmp  C000:0428
checksum_saved_context_C000_0438:
; file 0x40438
    mov  si,0x6d65
    mov  cx,0x000f
    cld
    xor  bx,bx
    lodsw
    add  bx,ax
    loop C000:0441
    mov  [0x6d83],bx
    ret

checksum_builtin_store_C000_044B:
; file 0x4044B
    push ds
    mov  ax,0x1800
    mov  ds,ax
    call checksum_store_body_C000_046E
    mov  [0x0006],bx
    pop  ds
    ret

checksum_store_body_C000_046E:
    mov  si,0x0008
    mov  cx,0x7ffc
    cld
    xor  bx,bx
    lodsw
    add  bx,ax
    loop C000:0477
    ret
retained_cleanup_C000_047D:
; file 0x4047D
    call C000:0B50
    mov  ax,[0x6d31]
    mov  [0x680b],ax
    mov  al,[0x6d4f]
    mov  [0x6d50],al
    test byte [0x6d4f],0x10
    ...            jnz  serial_cleanup_tail
