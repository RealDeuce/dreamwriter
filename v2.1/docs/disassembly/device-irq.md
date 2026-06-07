# Device IRQ Roots

This slice follows the installed `FCh`, `FDh`, and `FEh` IRQ roots from
[`installed-vectors.md`](installed-vectors.md): RS-232 receive, serial
transmit-ready acknowledge, and Centronics ACK-driven output.

No image assets are reached in this slice.

## IRQ FC Serial Receive

```asm
seed_irq_fc_stub:
; file 0x40015
C000:0015  E9 38 05          jmp  irq_fc_serial_rx_C000_0550
```

The receive ISR clears IRQ source bit `0x08`, checks the USART status port
`0xC1`, records error bits in `[6D57]`, reads the byte from port `0xC0`, and
queues it through `C000:4BED` unless the current serial state suppresses it.

```asm
irq_fc_serial_rx_C000_0550:
; file 0x40550
C000:0550  50                push ax
C000:0551  53                push bx
C000:0552  1E                push ds
C000:0553  51                push cx
C000:0554  52                push dx
C000:0555  B8 00 00          mov  ax,0
C000:0558  8E D8             mov  ds,ax
C000:055A  B0 08             mov  al,0x08
C000:055C  E6 90             out  0x90,al
C000:055E  80 3E A3 6D 01    cmp  byte [0x6da3],0x01
C000:0563  74 24             jz   serial_status_only_C000_0589

C000:0565  52                push dx
C000:0566  BA C1 00          mov  dx,0x00c1
C000:0569  EC                in   al,dx
C000:056A  5A                pop  dx
C000:056B  24 38             and  al,0x38
C000:056D  74 03             jz   serial_read_byte_C000_0572
C000:056F  E8 57 00          call serial_record_error_C000_05C9

serial_read_byte_C000_0572:
C000:0572  52                push dx
C000:0573  BA C0 00          mov  dx,0x00c0
C000:0576  EC                in   al,dx
C000:0577  5A                pop  dx
C000:0578  80 3E 94 82 02    cmp  byte [0x8294],0x02
C000:057D  73 12             jnc  serial_flow_control_C000_0591
C000:057F  E8 6B 46          call C000:4BED      ; enqueue received byte
serial_rx_return_C000_0582:
C000:0582  5A                pop  dx
C000:0583  59                pop  cx
C000:0584  1F                pop  ds
C000:0585  5B                pop  bx
C000:0586  58                pop  ax
C000:0587  FB                sti
C000:0588  CF                iret

serial_status_only_C000_0589:
C000:0589  52                push dx
C000:058A  BA C1 00          mov  dx,0x00c1
C000:058D  EC                in   al,dx
C000:058E  5A                pop  dx
C000:058F  EB F1             jmp  serial_rx_return_C000_0582
```

When software flow control is enabled through setup byte `[6D2E] == 1`, received
`0x13` sets `[70A5] bit 0x04` and received `0x11` clears it. Other bytes are
queued only when the flow-control state allows it.

```asm
serial_flow_control_C000_0591:
C000:0591  80 3E 2E 6D 01    cmp  byte [0x6d2e],0x01
C000:0596  74 09             jz   xon_xoff_enabled_C000_05A1
C000:0598  80 3E 94 82 02    cmp  byte [0x8294],0x02
C000:059D  74 16             jz   serial_drop_byte_C000_05B5
C000:059F  EB DE             jmp  C000:057F

xon_xoff_enabled_C000_05A1:
C000:05A1  F6 06 A5 70 04    test byte [0x70a5],0x04
C000:05A6  75 16             jnz  wait_for_xon_C000_05BE
C000:05A8  3C 13             cmp  al,0x13         ; XOFF
C000:05AA  74 0B             jz   saw_xoff_C000_05B7
C000:05AC  80 3E 94 82 02    cmp  byte [0x8294],0x02
C000:05B1  74 02             jz   serial_drop_byte_C000_05B5
C000:05B3  EB CA             jmp  C000:057F

serial_drop_byte_C000_05B5:
C000:05B5  EB CB             jmp  serial_rx_return_C000_0582

saw_xoff_C000_05B7:
C000:05B7  80 0E A5 70 04    or   byte [0x70a5],0x04
C000:05BC  EB F7             jmp  serial_drop_byte_C000_05B5

wait_for_xon_C000_05BE:
C000:05BE  3C 11             cmp  al,0x11         ; XON
C000:05C0  75 F3             jnz  serial_drop_byte_C000_05B5
C000:05C2  80 26 A5 70 FB    and  byte [0x70a5],0xfb
C000:05C7  EB EC             jmp  serial_drop_byte_C000_05B5
```

The normal error path records USART status bits `0x08`, `0x10`, and `0x20` in
`[6D57]`, then writes command `0x37` back to `0xC1`.

```asm
serial_record_error_C000_05C9:
C000:05C9  F6 06 57 6D 01    test byte [0x6d57],0x01
C000:05CE  75 24             jnz  serial_error_display_C000_05F4
C000:05D0  A8 08             test al,0x08
C000:05D2  74 05             jz   C000:05D9
C000:05D4  80 0E 57 6D 08    or   byte [0x6d57],0x08
C000:05D9  A8 10             test al,0x10
C000:05DB  74 05             jz   C000:05E2
C000:05DD  80 0E 57 6D 10    or   byte [0x6d57],0x10
C000:05E2  A8 20             test al,0x20
C000:05E4  74 05             jz   C000:05EB
C000:05E6  80 0E 57 6D 20    or   byte [0x6d57],0x20
C000:05EB  B0 37             mov  al,0x37
C000:05ED  52                push dx
C000:05EE  BA C1 00          mov  dx,0x00c1
C000:05F1  EE                out  dx,al
C000:05F2  5A                pop  dx
C000:05F3  C3                ret
```

`C000:05F4` enters a serial-error display/resource path and embedded resource
data follows at `C000:063D`, `C000:068A`, and `C000:06D7`. That display path is
not decoded here because it is not part of the interrupt-level receive queue.

## IRQ FD Serial Transmit Acknowledge

```asm
seed_irq_fd_stub:
; file 0x40018
C000:0018  E9 09 07          jmp  irq_fd_serial_tx_ack_C000_0724
```

`FDh` is a short acknowledge handler. It clears IRQ source bit `0x04` and clears
`[70A5] bit 0x08`, matching the current working model that this is a
transmit-ready related wake/ack source.

```asm
irq_fd_serial_tx_ack_C000_0724:
; file 0x40724
C000:0724  50                push ax
C000:0725  1E                push ds
C000:0726  B8 00 00          mov  ax,0
C000:0729  8E D8             mov  ds,ax
C000:072B  B0 04             mov  al,0x04
C000:072D  E6 90             out  0x90,al
C000:072F  80 26 A5 70 F7    and  byte [0x70a5],0xf7
C000:0734  1F                pop  ds
C000:0735  58                pop  ax
C000:0736  FB                sti
C000:0737  CF                iret
```

## IRQ FE Centronics ACK

```asm
seed_irq_fe_stub:
; file 0x4001B
C000:001B  E9 1A 07          jmp  irq_fe_centronics_ack_C000_0738
```

The Centronics ACK handler clears IRQ source bit `0x02`. If the ACK-fed stream
is active (`[6DA4] == 1`), it reads the next byte through pointer `[6D92]`.
Zero terminates the stream; nonzero bytes are written to port `0x40` and strobed
through port `0x30` bit `0x20`.

```asm
irq_fe_centronics_ack_C000_0738:
; file 0x40738
C000:0738  50                push ax
C000:0739  53                push bx
C000:073A  1E                push ds
C000:073B  B8 00 00          mov  ax,0
C000:073E  8E D8             mov  ds,ax
C000:0740  B0 02             mov  al,0x02
C000:0742  E6 90             out  0x90,al
C000:0744  80 3E A4 6D 01    cmp  byte [0x6da4],0x01
C000:0749  75 0F             jnz  centronics_done_C000_075A
C000:074B  8B 1E 92 6D       mov  bx,[0x6d92]
C000:074F  8A 07             mov  al,[bx]
C000:0751  43                inc  bx
C000:0752  89 1E 92 6D       mov  [0x6d92],bx
C000:0756  3C 00             cmp  al,0
C000:0758  75 0F             jnz  centronics_emit_C000_0769

centronics_done_C000_075A:
C000:075A  80 0E 4F 6D 40    or   byte [0x6d4f],0x40
C000:075F  A0 4F 6D          mov  al,[0x6d4f]
C000:0762  E6 60             out  0x60,al
C000:0764  1F                pop  ds
C000:0765  5B                pop  bx
C000:0766  58                pop  ax
C000:0767  FB                sti
C000:0768  CF                iret

centronics_emit_C000_0769:
C000:0769  E6 40             out  0x40,al
C000:076B  A0 94 6D          mov  al,[0x6d94]
C000:076E  0C 20             or   al,0x20
C000:0770  E6 30             out  0x30,al
C000:0772  90                nop
C000:0773  90                nop
C000:0774  90                nop
C000:0775  90                nop
C000:0776  24 DF             and  al,0xdf
C000:0778  E6 30             out  0x30,al
C000:077A  EB E8             jmp  C000:0764
```

## State Boundary

| RAM | Meaning |
| ---: | --- |
| `6D57` | Serial receive/error flags; IRQ `FC` ORs in status bits `0x08`, `0x10`, `0x20`. |
| `6D2E` | Serial XON/XOFF setup byte. |
| `70A5` | Shared event/serial flow-control flags; bit `0x04` is XOFF state, bit `0x08` is cleared by IRQ `FD`. |
| `6D92` | Centronics byte pointer for ACK-fed output. |
| `6D94` | Port `0x30` mirror; bit `0x20` is pulsed for Centronics strobe. |
| `6DA4` | Centronics ACK-feed active flag. |

## Next Splits

| Root | Split | Reason |
| --- | --- | --- |
| `C000:4BED`, `C000:4B8D` | `serial-services.md` | Serial receive queue insert/drain and software flow-control recovery. |
| `C000:0D71`, `C000:0C58`, `C000:0CBC` | `serial-services.md` | Serial transmit and USART setup paths. |
| `C000:08EC`, `C000:0920` | `printer-device.md` | Centronics starter and direct byte writer. |
| `C688:C82A` and printer formatter roots | [`printer-output.md`](printer-output.md) | Application-side formatted printer stream that chooses `INT 21h AH=05` or `AH=04`. |
