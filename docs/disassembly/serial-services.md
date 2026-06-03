# Serial Services

This slice follows the serial service code reached from
[`device-irq.md`](device-irq.md), [`int21-dispatch.md`](int21-dispatch.md), and
[`int21-endpoints.md`](int21-endpoints.md). It covers USART setup, `INT 21h`
serial output, and the receive/transmit queues shared with IRQ `FC` and `FD`.

No image assets are reached in this slice.

## USART Setup

`C000:0C58` programs the serial hardware, clears queue state, mirrors the
serial enable bits into port `0x60`, and writes command `0x37` to USART status
port `0xC1`. `C000:0CBC` wraps the same setup after disabling interrupts and
calling a higher-level serial cleanup/setup helper at `C000:48D5`.

```asm
serial_init_C000_0C58:
; file 0x40C58
C000:0C58  ...               ; program USART/baud and port 0x30 mirror
C000:0C5D  89 0E A5 6D       mov  [0x6da5],cx
C000:0C61  A3 AC 6E          mov  [0x6eac],ax
...
C000:0C9E  C6 06 A3 6D 01    mov  byte [0x6da3],1
C000:0CA3  A0 4F 6D          mov  al,[0x6d4f]
C000:0CA6  E6 60             out  0x60,al
...
C000:0CB3  B0 37             mov  al,0x37
C000:0CB5  52                push dx
C000:0CB6  BA C1 00          mov  dx,0x00c1
C000:0CB9  EE                out  dx,al
C000:0CBA  5A                pop  dx
C000:0CBB  C3                ret

serial_reinit_C000_0CBC:
C000:0CBC  FA                cli
C000:0CBD  E8 15 3C          call C000:48D5
C000:0CC0  E8 95 FF          call serial_init_C000_0C58
```

## Transmit Status And Output

`C000:0D4F` reads USART status port `0xC1`, tests transmit readiness, refreshes
the auto-off counter, and rejects output while shared flow-control flags in
`[70A5]` are set. `INT 21h AH=04` reaches `C000:0D71`, which waits through
`C000:49F8` when output is blocked and returns `AL=FF` if that idle wait is
cancelled by foreground input.

```asm
serial_can_send_C000_0D4F:
; file 0x40D4F
C000:0D4F  52                push dx
C000:0D50  BA C1 00          mov  dx,0x00c1
C000:0D53  EC                in   al,dx
C000:0D54  5A                pop  dx
C000:0D55  A8 01             test al,0x01
...
C000:0D59  A1 31 6D          mov  ax,[0x6d31]
C000:0D5C  A3 0B 68          mov  [0x680b],ax
C000:0D5F  52                push dx
...
C000:0D63  5A                pop  dx
C000:0D66  F6 06 A5 70 0C    test byte [0x70a5],0x0c

service_04_serial_output_C000_0D71:
; file 0x40D71
C000:0D71  E8 DB FF          call serial_can_send_C000_0D4F
C000:0D74  73 0D             jnc  serial_send_dl_C000_0D83
C000:0D76  52                push dx
C000:0D77  E8 7E 3C          call idle_until_event_C000_49F8
C000:0D7A  5A                pop  dx
...
serial_send_byte_C000_0D96:
C000:0D96  80 0E A5 70 08    or   byte [0x70a5],0x08
C000:0D9B  52                push dx
C000:0D9C  BA C0 00          mov  dx,0x00c0
C000:0D9F  EE                out  dx,al
C000:0DA0  5A                pop  dx
C000:0DA1  C3                ret
```

`C000:0DA2` and `C000:0DC4` are higher-level byte senders used by the DreamLink
finish path. They share the same `C000:0D96` low-level transmitter and include
cancel/escape handling around tab and control bytes.

## Receive Queue Insert

IRQ `FC` calls `C000:4BED` after reading a byte from port `0xC0`. The insert
routine writes into a ring buffer, advances `[70E5]`, increments `[70E6]`, and
uses XON/XOFF or command `0x15` when the free-space threshold is crossed.

```asm
serial_rx_enqueue_C000_4BED:
; file 0x44BED
C000:4BED  ...               ; store AL at ring[70E5]
C000:4C02  ...               ; advance write pointer and count 70E6
C000:4C0D  ...               ; if free space <= 0x20 / <= 0x0A, throttle peer
C000:4C1A  C3                ret
```

When `[6D2E] != 0`, the queue uses XOFF `0x13` and XON `0x11`; otherwise it
uses USART command writes. The IRQ-level byte filter that interprets peer XON
and XOFF is documented in [`device-irq.md`](device-irq.md).

## Receive Queue Drain

`C000:4B8D` drains one queued receive byte for foreground consumers. If the
queue becomes empty, it sets `[70A5] bit 2` and writes command `0x37` to
`0xC1`. When enough free space returns and XON/XOFF mode is active, it sends
XON `0x11` through `C000:0D96`.

```asm
serial_rx_dequeue_C000_4B8D:
; file 0x44B8D
C000:4B8D  A1 31 6D          mov  ax,[0x6d31]    ; refresh auto-off path
...
C000:4B9C  80 0E A5 70 02    or   byte [0x70a5],0x02
C000:4BA2  B0 37             mov  al,0x37
C000:4BA4  52                push dx
C000:4BA5  BA C1 00          mov  dx,0x00c1
C000:4BA8  EE                out  dx,al
C000:4BA9  5A                pop  dx
C000:4BAA  C3                ret              ; empty queue
...
C000:4BDD  5A                pop  dx
C000:4BDE  80 3E 2E 6D 00    cmp  byte [0x6d2e],0
C000:4BE5  B0 11             mov  al,0x11        ; XON
C000:4BE7  E8 AC C1          call serial_send_byte_C000_0D96
C000:4BEC  C3                ret
```

## State Boundary

| RAM/Port | Meaning |
| ---: | --- |
| `6D2E` | XON/XOFF enable byte. |
| `6D4F` | Port `0x60` mirror updated during serial setup. |
| `6D57` | USART error flags from IRQ `FC`. |
| `6DA3` | Serial setup/in-progress guard. |
| `70A5` | Shared serial/event flags; bits `0x04` and `0x08` gate serial flow. |
| `70E4`, `70E5`, `70E6` | Receive queue read pointer, write pointer, and count. |
| `0xC0`, `0xC1` | USART data and status/command ports. |

## Next Splits

| Root | Split | Reason |
| --- | --- | --- |
| `C000:48D5` | `serial-power-cleanup.md` | Cleanup/reinit helper shared with suspend. |

DreamLink command-frame callers of `C000:0DC4` are already expanded in
[`dreamlink-file-core.md`](dreamlink-file-core.md), and the endpoint finish
handoff is covered in [`int21-endpoints.md`](int21-endpoints.md).
