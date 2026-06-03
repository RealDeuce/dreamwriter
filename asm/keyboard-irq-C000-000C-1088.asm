; Generated from disasm: C000:000C-1088
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x000C


seed_irq_f9_stub:
; file 0x4000C
    jmp  irq_f9_timer_ack_C000_049A
irq_f9_timer_ack_C000_049A:
; file 0x4049A
    push ax
    push ds
    mov  ax,0
    mov  ds,ax
    mov  al,0x40
    out  0x90,al
    and  byte [0x6da9],0xfe
    pop  ds
    pop  ax
    sti
    iret
seed_irq_fa_stub:
; file 0x4000F
    jmp  irq_fa_keyboard_scan_cycle_C000_04AE
irq_fa_keyboard_scan_cycle_C000_04AE:
; file 0x404AE
    push ax
    push bx
    push ds
    mov  ax,0
    mov  ds,ax
    or   byte [0x6d4f],0x04
    mov  al,[0x6d4f]
    out  0x60,al
    mov  al,0x20
    out  0x90,al
    mov  byte [0x6d28],0
    call keyboard_scan_reset_C000_106F
    pop  ds
    pop  bx
    pop  ax
    sti
    iret
keyboard_scan_reset_C000_106F:
; file 0x4106F
    and  byte [0x6d4f],0xf7
    mov  al,[0x6d4f]
    out  0x60,al
    in   al,0xb0
    mov  al,0xfe
    out  0x61,al
    mov  al,0xff
    out  0x61,al
    mov  byte [0x6d29],0
    ret
seed_irq_fb_stub:
; file 0x40012
    jmp  irq_fb_keyboard_row_C000_04D1
irq_fb_keyboard_row_C000_04D1:
; file 0x404D1
    push ax
    push bx
    push ds
    mov  ax,0
    mov  ds,ax
    mov  al,0x10
    out  0x90,al
    mov  bl,[0x6d29]
    xor  bh,bh
    in   al,0xb0
    or   al,al
    jz   C000:04EE
    or   byte [0x6d28],0x80
    mov  [bx+0x6d06],al
    inc  byte [0x6d29]
    cmp  byte [0x6d29],0x0a
    jnz  irq_fa_return_C000_04CC
    test byte [0x6d28],0x80
    jnz  active_scan_C000_0524
    inc  byte [0x6d28]
    cmp  byte [0x6d28],0x0a
    jnz  complete_scan_C000_0529
    mov  al,0xfe
    out  0x61,al
    and  byte [0x6d4f],0xfb
    or   byte [0x6d4f],0x08
    mov  al,[0x6d4f]
    out  0x60,al
    jmp  irq_fa_return_C000_04CC

active_scan_C000_0524:
    mov  byte [0x6d28],0
complete_scan_C000_0529:
    mov  byte [0x6d29],0
    push es
    push cx
    push dx
    push si
    push di
    push bp
    mov  al,[0x6d4f]
    or   al,0x01
    out  0x60,al
    sti
    call keyboard_row_processor_C000_5645
    cli
    mov  al,[0x6d4f]
    out  0x60,al
    pop  bp
    pop  di
    pop  si
    pop  dx
    pop  cx
    pop  es
    pop  ds
    pop  bx
    pop  ax
    sti
    iret
