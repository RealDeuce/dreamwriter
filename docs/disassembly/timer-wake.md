# Timer Wake Latch

This slice follows the service-level timer/wake helpers referenced by the
keyboard IRQ and foreground idle paths. It does not enter menu or application
handlers.

No image assets or string resources are reached in this slice.

## F9 IRQ Acknowledge

`C000:049A` is installed as the `F9h` interrupt vector. It acknowledges the
timer/wake event, clears the active latch bit in `[6DA9]`, and returns through
`IRET`.

```asm
irq_f9_timer_wake_C000_049A:
; file 0x4049A
C000:049A  50                push ax
C000:049B  1E                push ds
C000:049C  B8 00 00          mov  ax,0
C000:049F  8E D8             mov  ds,ax
C000:04A1  B0 40             mov  al,0x40
C000:04A3  E6 90             out  0x90,al
C000:04A5  80 26 A9 6D FE    and  byte [0x6da9],0xfe
C000:04AA  1F                pop  ds
C000:04AB  58                pop  ax
C000:04AC  FB                sti
C000:04AD  CF                iret
```

Port `0x90` receives `0x40` as the IRQ acknowledge. The helper uses `DS=0`, so
the latch byte is low RAM at `0000:6DA9`.

## Arm And Disarm

`C000:0B3C` arms the timer. It marks `[6DA9] bit 0`, clears the timer-disable
bit in `[6D4F]`, writes the updated control byte to port `0x60`, then writes
the caller-supplied count from `AH` to port `0x53`.

```asm
arm_timer_C000_0B3C:
; file 0x40B3C
C000:0B3C  80 0E A9 6D 01    or   byte [0x6da9],0x01
C000:0B41  80 26 4F 6D FD    and  byte [0x6d4f],0xfd
C000:0B46  A0 4F 6D          mov  al,[0x6d4f]
C000:0B49  E6 60             out  0x60,al
C000:0B4B  8A C4             mov  al,ah
C000:0B4D  E6 53             out  0x53,al
C000:0B4F  C3                ret
```

`C000:0B50` disarms the timer by clearing `[6DA9] bit 0`, setting
`[6D4F] bit 1`, and writing the control byte back to port `0x60`.

```asm
disarm_timer_C000_0B50:
; file 0x40B50
C000:0B50  80 26 A9 6D FE    and  byte [0x6da9],0xfe
C000:0B55  80 0E 4F 6D 02    or   byte [0x6d4f],0x02
C000:0B5A  A0 4F 6D          mov  al,[0x6d4f]
C000:0B5D  E6 60             out  0x60,al
C000:0B5F  C3                ret
```

Observed callers pass small latch counts such as `0x0A`, `0x56`, and `0x60` in
`AH`. This matches the hardware note that port `0x53` is a timer latch rather
than an interrupt-vector selector.

## State Boundary

| RAM/Port | Meaning |
| ---: | --- |
| `6D4F bit 1` | Timer disable/control bit mirrored to port `0x60`. |
| `6DA9 bit 0` | Timer armed/pending software latch. |
| `0x53` | Timer count latch written from `AH`. |
| `0x90` | IRQ acknowledge port, written with `0x40` by the `F9h` ISR. |

