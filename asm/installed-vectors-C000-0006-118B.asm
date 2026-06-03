; Generated from disasm: C000:0006-118B
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x0006


install_vectors_C000_0ED6:
    cld
    push es
    mov  bp,0
    mov  es,bp
    mov  bx,0xc000
    mov  dx,0x118b
    mov  di,0x0000
...
    mov  cx,0x00e7       ; fill vectors 11h..F7h
    mov  ax,dx
    stosw
    mov  ax,bx
    stosw
    loop C000:0F27
default_interrupt_target_C000_118B:
; file 0x4118B
    iret
; IRQ vectors F8h..FFh
    mov  bx,0xc000
    mov  cx,0x0004
    mov  di,0x03e0
    mov  dx,0x0009
    mov  ax,dx
    stosw
    mov  ax,bx
    stosw
    add  dx,byte +0x03
    loop C000:0F3B       ; F8h..FBh
    mov  ax,dx           ; FCh -> C000:0015
    stosw
    mov  ax,bx
    stosw
    add  dx,byte +0x03
    mov  ax,dx           ; FDh -> C000:0018
    stosw
    mov  ax,bx
    stosw
    add  dx,byte +0x03
    mov  cx,0x0002
    mov  ax,dx           ; FEh, FFh
    stosw
    mov  ax,bx
    stosw
    add  dx,byte +0x03
    loop C000:0F5B

; INT 21h
    mov  ax,0x0006
    mov  di,0x0084
    stosw
    mov  ax,bx
    stosw

; INT 1
    mov  ax,0x157d
    mov  di,0x0004
    stosw
    mov  ax,0xc000
    stosw
seed_int21_vector_target:
    jmp  int21_dispatch_C000_5098

seed_irq_f8_stub:
    jmp  irq_f8_save_suspend_C000_03AE
seed_irq_f9_stub:
    jmp  irq_f9_timer_ack_C000_049A
seed_irq_fa_stub:
    jmp  irq_fa_keyboard_scan_cycle_C000_04AE
seed_irq_fb_stub:
    jmp  irq_fb_keyboard_row_C000_04D1
seed_irq_fc_stub:
    jmp  irq_fc_serial_rx_C000_0550
seed_irq_fd_stub:
    jmp  irq_fd_serial_tx_ack_C000_0724
seed_irq_fe_stub:
    jmp  irq_fe_centronics_ack_C000_0738
seed_irq_ff_stub:
    jmp  irq_ff_warm_power_C000_02EE
    push ds
    mov  di,0x0200
    mov  ax,ds
    mov  es,ax
    mov  si,0x0f94
    mov  ax,0xc000
    mov  ds,ax
    mov  cx,0x0052       ; 0xA4 bytes, 41 far ptrs
    rep  movsw
    pop  ds
    pop  es
    ret
