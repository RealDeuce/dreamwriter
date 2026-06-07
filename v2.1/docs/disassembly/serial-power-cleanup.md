# Serial Setup Validation And Power Cleanup

This slice follows two serial descendants reached from
[`serial-services.md`](serial-services.md) and [`power-irq.md`](power-irq.md):
the RS-232 setup validators around `C000:48D5` and the retained-power serial
cleanup tail at `C000:047D`.

No image assets or string resources are reached in this slice.

## RS-232 Setup Validator

`C000:48D5` validates the five RS-232 setup bytes edited by the COMMUNICATE
setup screen. It does not repair invalid values directly; it sets
`[6D53] bit 0x04` when a value is out of range. `C000:0CBC` calls this before
programming the USART through `C000:0C58`.

```asm
validate_rs232_setup_C000_48D5:
; file 0x448D5
C000:48D5  FC                cld
C000:48D6  BE 2A 6D          mov  si,0x6d2a
C000:48D9  AC                lodsb              ; baud index
C000:48DA  3C 03             cmp  al,0x03
C000:48DC  72 19             jc   rs232_invalid_C000_48F7
C000:48DE  3C 08             cmp  al,0x08
C000:48E0  73 15             jnc  rs232_invalid_C000_48F7
C000:48E2  AC                lodsb              ; bit length
C000:48E3  3C 02             cmp  al,0x02
C000:48E5  73 10             jnc  rs232_invalid_C000_48F7
C000:48E7  AC                lodsb              ; stop bits
C000:48E8  3C 02             cmp  al,0x02
C000:48EA  73 0B             jnc  rs232_invalid_C000_48F7
C000:48EC  AC                lodsb              ; parity
C000:48ED  3C 03             cmp  al,0x03
C000:48EF  73 06             jnc  rs232_invalid_C000_48F7
C000:48F1  AC                lodsb              ; XON/XOFF
C000:48F2  3C 02             cmp  al,0x02
C000:48F4  73 01             jnc  rs232_invalid_C000_48F7
C000:48F6  C3                ret

rs232_invalid_C000_48F7:
C000:48F7  80 0E 53 6D 04    or   byte [0x6d53],0x04
C000:48FC  C3                ret
```

`C000:48FD` seeds default RS-232 settings: baud index `6`, 8-bit data, one stop
bit, no parity, and XON/XOFF disabled. In the current setup strings, baud index
`6` corresponds to 9600 baud.

## Printer Setup Validator

The adjacent validator `C000:4917` checks printer setup bytes `6D59..6D5B`:
model index below `7`, interface below `2`, and paper-feed mode below `2`.
Invalid values set `[6D53] bit 0x08`.

```asm
validate_printer_setup_C000_4917:
; file 0x44917
C000:4917  FC                cld
C000:4918  BE 59 6D          mov  si,0x6d59
C000:491B  AC                lodsb
C000:491C  3C 07             cmp  al,0x07
C000:491E  73 0B             jnc  printer_invalid_C000_492B
...
printer_invalid_C000_492B:
C000:492B  80 0E 53 6D 08    or   byte [0x6d53],0x08
```

`C000:4931` resets printer setup to model `3`, parallel/interface `0`, and
paper feed `0`.

## Power Setup Validator

`C000:4941` validates the auto power-off and power-on buzzer setup bytes at
`6D2F..6D30`. The auto-off index must be below `7`; buzzer type must be below
`4`. The invalid path shares the same `[6D53] bit 0x08` marker as the printer
validator. `C000:4956` resets both bytes to zero.

```asm
validate_power_setup_C000_4941:
; file 0x44941
C000:4941  FC                cld
C000:4942  BE 2F 6D          mov  si,0x6d2f
C000:4945  AC                lodsb
C000:4946  3C 07             cmp  al,0x07
C000:4948  73 E1             jnc  printer_invalid_C000_492B
C000:494A  AC                lodsb
C000:494B  3C 04             cmp  al,0x04
C000:494D  73 DC             jnc  printer_invalid_C000_492B
C000:494F  C3                ret
```

`C000:4950` is a separate short helper that sets `[6D53]` bit `0x10`.

## Retained-Power Serial Cleanup

`C000:047D` runs during retained power transition before RTC alarm programming.
It disables the F9 timer latch through `C000:0B50`, reloads the foreground
auto-off counter, snapshots the port `0x60` mirror into `[6D50]`, and then
quiesces serial state if serial power/control bit `0x10` is clear in `[6D4F]`.

```asm
retained_cleanup_C000_047D:
; file 0x4047D
C000:047D  E8 D0 06          call timer_disarm_C000_0B50
C000:0480  A1 31 6D          mov  ax,[0x6d31]
C000:0483  A3 0B 68          mov  [0x680b],ax
C000:0486  A0 4F 6D          mov  al,[0x6d4f]
C000:0489  A2 50 6D          mov  [0x6d50],al
C000:048C  F6 06 4F 6D 10    test byte [0x6d4f],0x10
C000:0491  75 06             jnz  retained_cleanup_done_C000_0499
C000:0493  E8 94 08          call serial_power_down_C000_0D2A
C000:0496  E8 53 07          call serial_delay_countdown_C000_0BEC
C000:0499  C3                ret
```

`C000:0D2A` sets `[6D4F] bits 0x30`, writes the mirror to port `0x60`, touches
USART control port `0xC1`, and loads `[6DA5]=0x0258`. `C000:0BEC` later counts
`[6DA5]` down and, when it reaches zero, clears `[6D94] bit 0x10`, sets bit
`0x08`, and writes port `0x30`.

## State Boundary

| RAM/Port | Meaning |
| ---: | --- |
| `6D2A..6D2E` | RS-232 setup bytes. |
| `6D2F..6D30` | Auto-off and buzzer setup bytes. |
| `6D31` | Auto-off countdown reload value. |
| `6D53` | Setup validation error/status flags. |
| `6D59..6D5B` | Printer setup bytes. |
| `6D4F` | Port `0x60` mirror. |
| `6D50` | Saved port `0x60` mirror during retained cleanup. |
| `6D94` | Port `0x30` mirror. |
| `6DA5` | Serial/power-down countdown. |

## Related Splits

| Root | Split | Reason |
| --- | --- | --- |
| `DC98:22A1`, `DC98:24DB`, `DC98:288A` | [`setup-screens.md`](setup-screens.md) | Application-side setup menus that edit the validated bytes. |
