; Generated from disasm: C000:0015-077A
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x0015


seed_irq_fc_stub:
; file 0x40015
    jmp  irq_fc_serial_rx_C000_0550
irq_fc_serial_rx_C000_0550:
; file 0x40550
    push ax
    push bx
    push ds
    push cx
    push dx
    mov  ax,0
    mov  ds,ax
    mov  al,0x08
    out  0x90,al
    cmp  byte [0x6da3],0x01
    jz   serial_status_only_C000_0589

    push dx
    mov  dx,0x00c1
    in   al,dx
    pop  dx
    and  al,0x38
    jz   serial_read_byte_C000_0572
    call serial_record_error_C000_05C9

serial_read_byte_C000_0572:
    push dx
    mov  dx,0x00c0
    in   al,dx
    pop  dx
    cmp  byte [0x8294],0x02
    jnc  serial_flow_control_C000_0591
    call C000:4BED       ; enqueue received byte
serial_rx_return_C000_0582:
    pop  dx
    pop  cx
    pop  ds
    pop  bx
    pop  ax
    sti
    iret

serial_status_only_C000_0589:
    push dx
    mov  dx,0x00c1
    in   al,dx
    pop  dx
    jmp  serial_rx_return_C000_0582
serial_flow_control_C000_0591:
    cmp  byte [0x6d2e],0x01
    jz   xon_xoff_enabled_C000_05A1
    cmp  byte [0x8294],0x02
    jz   serial_drop_byte_C000_05B5
    jmp  C000:057F

xon_xoff_enabled_C000_05A1:
    test byte [0x70a5],0x04
    jnz  wait_for_xon_C000_05BE
    cmp  al,0x13         ; XOFF
    jz   saw_xoff_C000_05B7
    cmp  byte [0x8294],0x02
    jz   serial_drop_byte_C000_05B5
    jmp  C000:057F

serial_drop_byte_C000_05B5:
    jmp  serial_rx_return_C000_0582

saw_xoff_C000_05B7:
    or   byte [0x70a5],0x04
    jmp  serial_drop_byte_C000_05B5

wait_for_xon_C000_05BE:
    cmp  al,0x11         ; XON
    jnz  serial_drop_byte_C000_05B5
    and  byte [0x70a5],0xfb
    jmp  serial_drop_byte_C000_05B5
serial_record_error_C000_05C9:
    test byte [0x6d57],0x01
    jnz  serial_error_display_C000_05F4
    test al,0x08
    jz   C000:05D9
    or   byte [0x6d57],0x08
    test al,0x10
    jz   C000:05E2
    or   byte [0x6d57],0x10
    test al,0x20
    jz   C000:05EB
    or   byte [0x6d57],0x20
    mov  al,0x37
    push dx
    mov  dx,0x00c1
    out  dx,al
    pop  dx
    ret
seed_irq_fd_stub:
; file 0x40018
    jmp  irq_fd_serial_tx_ack_C000_0724
irq_fd_serial_tx_ack_C000_0724:
; file 0x40724
    push ax
    push ds
    mov  ax,0
    mov  ds,ax
    mov  al,0x04
    out  0x90,al
    and  byte [0x70a5],0xf7
    pop  ds
    pop  ax
    sti
    iret
seed_irq_fe_stub:
; file 0x4001B
    jmp  irq_fe_centronics_ack_C000_0738
irq_fe_centronics_ack_C000_0738:
; file 0x40738
    push ax
    push bx
    push ds
    mov  ax,0
    mov  ds,ax
    mov  al,0x02
    out  0x90,al
    cmp  byte [0x6da4],0x01
    jnz  centronics_done_C000_075A
    mov  bx,[0x6d92]
    mov  al,[bx]
    inc  bx
    mov  [0x6d92],bx
    cmp  al,0
    jnz  centronics_emit_C000_0769

centronics_done_C000_075A:
    or   byte [0x6d4f],0x40
    mov  al,[0x6d4f]
    out  0x60,al
    pop  ds
    pop  bx
    pop  ax
    sti
    iret

centronics_emit_C000_0769:
    out  0x40,al
    mov  al,[0x6d94]
    or   al,0x20
    out  0x30,al
    nop
    nop
    nop
    nop
    and  al,0xdf
    out  0x30,al
    jmp  C000:0764
