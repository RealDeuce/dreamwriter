; Generated from disasm: C000:0C58-4C1A
; NOTE: branch target labels are local aliases for readability.

BITS 16
org 0x0C58


serial_init_C000_0C58:
; file 0x40C58
C000:0C58  ...               ; program USART/baud and port 0x30 mirror
    mov  [0x6da5],cx
    mov  [0x6eac],ax
...
    mov  byte [0x6da3],1
    mov  al,[0x6d4f]
    out  0x60,al
...
    mov  al,0x37
    push dx
    mov  dx,0x00c1
    out  dx,al
    pop  dx
    ret

serial_reinit_C000_0CBC:
    cli
    call C000:48D5
    call serial_init_C000_0C58
serial_can_send_C000_0D4F:
; file 0x40D4F
    push dx
    mov  dx,0x00c1
    in   al,dx
    pop  dx
    test al,0x01
...
    mov  ax,[0x6d31]
    mov  [0x680b],ax
    push dx
...
    pop  dx
    test byte [0x70a5],0x0c

service_04_serial_output_C000_0D71:
; file 0x40D71
    call serial_can_send_C000_0D4F
    jnc  serial_send_dl_C000_0D83
    push dx
    call idle_until_event_C000_49F8
    pop  dx
...
serial_send_byte_C000_0D96:
    or   byte [0x70a5],0x08
    push dx
    mov  dx,0x00c0
    out  dx,al
    pop  dx
    ret
serial_rx_enqueue_C000_4BED:
; file 0x44BED
C000:4BED  ...               ; store AL at ring[70E5]
C000:4C02  ...               ; advance write pointer and count 70E6
C000:4C0D  ...               ; if free space <= 0x20 / <= 0x0A, throttle peer
    ret
serial_rx_dequeue_C000_4B8D:
; file 0x44B8D
    mov  ax,[0x6d31]    ; refresh auto-off path
...
    or   byte [0x70a5],0x02
    mov  al,0x37
    push dx
    mov  dx,0x00c1
    out  dx,al
    pop  dx
    ret              ; empty queue
...
    pop  dx
    cmp  byte [0x6d2e],0
    mov  al,0x11        ; XON
    call serial_send_byte_C000_0D96
    ret
