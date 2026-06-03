# Printer Device Services

This slice follows the Centronics output helpers reached from
[`device-irq.md`](device-irq.md) and `INT 21h AH=05`.

No image assets are reached in this slice.

## ACK-Fed Stream Starter

`C000:08EC` starts a NUL-terminated byte stream whose current pointer lives in
`[6D92]`. If the first byte is zero, the helper returns without arming the ACK
path. Otherwise it clears port `0x60` mirror bit `0x40`, marks `[6DA4]=1`, and
falls into the direct-byte writer for the first byte.

```asm
centronics_start_stream_C000_08EC:
; file 0x408EC
C000:08EC  8B 1E 92 6D       mov  bx,[0x6d92]
C000:08F0  8A 17             mov  dl,[bx]
C000:08F2  43                inc  bx
C000:08F3  89 1E 92 6D       mov  [0x6d92],bx
C000:08F7  80 FA 00          cmp  dl,0
C000:08FA  74 23             jz   printer_return_C000_091F
C000:08FC  C6 06 A4 6D 00    mov  byte [0x6da4],0
C000:0901  80 26 4F 6D BF    and  byte [0x6d4f],0xbf
C000:0906  A0 4F 6D          mov  al,[0x6d4f]
C000:0909  E6 60             out  0x60,al
C000:090B  C6 06 A4 6D 01    mov  byte [0x6da4],1
C000:0910  E8 0D 00          call centronics_write_dl_C000_0920
C000:0913  C3                ret
```

Subsequent bytes are fed by IRQ `FEh`, documented in
[`device-irq.md`](device-irq.md).

## Direct Byte Writer

`C000:0920` writes `DL` to the parallel data port `0x40`, waits for status port
`0xA0 bit 0x02` to clear, then pulses port `0x30 bit 0x20` using mirror
`[6D94]`. While waiting it calls `C000:49F8`, so foreground input can cancel a
blocked printer write; cancellation returns `AL=FF`.

```asm
centronics_write_dl_C000_0920:
; file 0x40920
C000:0920  8A C2             mov  al,dl
C000:0922  E6 40             out  0x40,al
printer_wait_ready_C000_0924:
C000:0924  E4 A0             in   al,0xa0
C000:0926  A8 02             test al,0x02        ; BUSY
C000:0928  74 0A             jz   printer_strobe_C000_0934
C000:092A  E8 CB 40          call idle_until_event_C000_49F8
C000:092D  73 F5             jnc  printer_wait_ready_C000_0924
C000:092F  B0 FF             mov  al,0xff
C000:0931  C3                ret

printer_strobe_C000_0934:
C000:0934  A0 94 6D          mov  al,[0x6d94]
C000:0937  0C 20             or   al,0x20
C000:0939  E6 30             out  0x30,al
C000:093B  90                nop
C000:093C  90                nop
C000:093D  90                nop
C000:093E  90                nop
C000:093F  24 DF             and  al,0xdf
C000:0941  E6 30             out  0x30,al
C000:0943  32 C0             xor  al,al
C000:0945  C3                ret
```

## State Boundary

| RAM/Port | Meaning |
| ---: | --- |
| `6D92` | NUL-terminated ACK-fed stream pointer. |
| `6D94` | Port `0x30` mirror; bit `0x20` is the Centronics strobe. |
| `6DA4` | ACK-fed stream active flag used by IRQ `FEh`. |
| `0x40` | Parallel data output port. |
| `0xA0 bit 0x02` | Busy/status input tested before strobe. |

## Next Splits

| Root | Split | Reason |
| --- | --- | --- |
| Application printer formatters | `printer-output.md` | User-facing print formatting before `INT 21h AH=05`. |
| `C000:49F8` | [`idle-power.md`](idle-power.md) | Shared cancel/idle path used by blocked printer output. |
