# RTC Programming And Alarm Compare

This slice follows the RP5C01-style RTC programming and compare helpers reached
from [`power-irq.md`](power-irq.md) and
[`rtc-alarm-power.md`](rtc-alarm-power.md).

No image assets or string resources are reached in this slice.

## Alarm Preparation

`C000:0376` is the retained power-transition alarm preparer. It pauses timer
advance by clearing bit `0x08` at port `0xDD`, asks the application side to
select the next scheduler/world-clock alarm, compares that selected alarm
against the current RTC shadow, then either programs the selected alarm or a
minute-plus-one fallback.

```asm
prepare_rtc_alarm_C000_0376:
; file 0x40376
C000:0376  E4 DD             in   al,0xdd
C000:0378  24 F7             and  al,0xf7
C000:037A  E6 DD             out  0xdd,al
C000:037C  06                push es
C000:037D  9A BB D3 98 DC    call DC98:D3BB
C000:0382  07                pop  es
C000:0383  E8 0A 08          call full_alarm_compare_C000_0B90
C000:0386  72 03             jc   restore_timer_and_program_fallback_test
C000:0388  E8 F1 07          call short_alarm_compare_C000_0B7C
C000:038B  9C                pushf
C000:038C  E4 DD             in   al,0xdd
C000:038E  0C 08             or   al,0x08
C000:0390  E6 DD             out  0xdd,al
C000:0392  9D                popf
C000:0393  72 0F             jc   fallback_alarm_C000_03A4
C000:0395  E8 79 06          call program_selected_alarm_C000_0A11
C000:0398  C6 06 4E 6D 00    mov  byte [0x6d4e],0

enable_alarm_output_C000_039D:
C000:039D  E4 DD             in   al,0xdd
C000:039F  0C 04             or   al,0x04
C000:03A1  E6 DD             out  0xdd,al
C000:03A3  C3                ret

fallback_alarm_C000_03A4:
C000:03A4  E8 98 06          call program_minute_plus_one_C000_0A3F
C000:03A7  C6 06 4E 6D 01    mov  byte [0x6d4e],1
C000:03AC  EB EF             jmp  enable_alarm_output_C000_039D
```

`DC98:D3BB` writes the selected application alarm into `6D41..6D4C`. The
hardware-facing code here only consumes that prepared buffer.

## Selected Alarm Programmer

`C000:0A11` writes low nibbles from `6D45..6D4A` into RTC ports `0xD8..0xD2`,
skipping ports `0xD6` and `0xD2` in the loop conditions shown below. The port
selection matches the current RP5C01 model's mode-1 alarm registers for day,
hour, and minute fields.

```asm
program_selected_alarm_C000_0A11:
; file 0x40A11
C000:0A11  50                push ax
C000:0A12  53                push bx
C000:0A13  52                push dx
C000:0A14  B0 F9             mov  al,0xf9
C000:0A16  E6 DD             out  0xdd,al
C000:0A18  B0 FD             mov  al,0xfd
C000:0A1A  E6 DF             out  0xdf,al
C000:0A1C  BA D8 00          mov  dx,0x00d8
C000:0A1F  BB 45 6D          mov  bx,0x6d45
program_selected_loop_C000_0A22:
C000:0A22  8A 07             mov  al,[bx]
C000:0A24  24 0F             and  al,0x0f
C000:0A26  81 FA D6 00       cmp  dx,0x00d6
C000:0A2A  74 01             jz   skip_this_port_C000_0A2D
C000:0A2C  EE                out  dx,al
C000:0A2D  81 FA D2 00       cmp  dx,0x00d2
C000:0A31  74 04             jz   selected_done_C000_0A37
C000:0A33  43                inc  bx
C000:0A34  4A                dec  dx
C000:0A35  EB EB             jmp  program_selected_loop_C000_0A22
selected_done_C000_0A37:
C000:0A37  B0 F8             mov  al,0xf8
C000:0A39  E6 DD             out  0xdd,al
C000:0A3B  5A                pop  dx
C000:0A3C  5B                pop  bx
C000:0A3D  58                pop  ax
C000:0A3E  C3                ret
```

## Minute-Plus-One Fallback

`C000:0A3F` writes only the current minute plus one into ports `0xD2` and
`0xD3`. It increments the low minute digit, rolls `9 -> 0`, increments the high
minute digit, and rolls high digit `6 -> 0`.

```asm
program_minute_plus_one_C000_0A3F:
; file 0x40A3F
C000:0A3F  B0 F9             mov  al,0xf9
C000:0A41  E6 DD             out  0xdd,al
C000:0A43  B0 FD             mov  al,0xfd
C000:0A45  E6 DF             out  0xdf,al
C000:0A47  A0 98 6D          mov  al,[0x6d98]
C000:0A4A  8A 26 99 6D       mov  ah,[0x6d99]
C000:0A4E  FE C0             inc  al
C000:0A50  3C 0A             cmp  al,0x0a
C000:0A52  75 0B             jnz  write_fallback_minute_C000_0A5F
C000:0A54  B0 00             mov  al,0
C000:0A56  FE C4             inc  ah
C000:0A58  80 FC 06          cmp  ah,0x06
C000:0A5B  75 02             jnz  write_fallback_minute_C000_0A5F
C000:0A5D  B4 00             mov  ah,0
C000:0A5F  E6 D2             out  0xd2,al
C000:0A61  8A C4             mov  al,ah
C000:0A63  E6 D3             out  0xd3,al
C000:0A65  B0 F8             mov  al,0xf8
C000:0A67  E6 DD             out  0xdd,al
C000:0A69  C3                ret
```

The fallback is used when the selected alarm already compares as current, which
prevents immediate retriggering during retained power handoff.

## RTC Snapshot

`C000:0B60` snapshots low nibbles from RTC ports `0xDC..0xD0` into
`6DA2..6D96`, decrementing both the port and destination pointer.

```asm
rtc_snapshot_C000_0B60:
; file 0x40B60
C000:0B60  50                push ax
C000:0B61  53                push bx
C000:0B62  52                push dx
C000:0B63  BA DC 00          mov  dx,0x00dc
C000:0B66  BB A2 6D          mov  bx,0x6da2
snapshot_loop_C000_0B69:
C000:0B69  EC                in   al,dx
C000:0B6A  24 0F             and  al,0x0f
C000:0B6C  88 07             mov  [bx],al
C000:0B6E  81 FA D0 00       cmp  dx,0x00d0
C000:0B74  4B                dec  bx
C000:0B75  4A                dec  dx
C000:0B76  EB F1             jmp  snapshot_loop_C000_0B69
```

## Compare Helpers

`C000:0B90` compares the full selected alarm buffer `6D41..6D4B` against the
fresh RTC snapshot. `C000:0B7C` compares the shorter day/hour/minute portion
starting at `6D45`. Both helpers return carry set on equality and carry clear
on mismatch.

```asm
short_alarm_compare_C000_0B7C:
; file 0x40B7C
C000:0B7C  E8 E1 FF          call rtc_snapshot_C000_0B60
C000:0B85  BF 9E 6D          mov  di,0x6d9e
C000:0B88  BE 45 6D          mov  si,0x6d45
C000:0B8B  B9 07 00          mov  cx,0x0007
C000:0B8E  EB 12             jmp  compare_loop_C000_0BA2

full_alarm_compare_C000_0B90:
C000:0B90  E8 CD FF          call rtc_snapshot_C000_0B60
C000:0B99  BF A2 6D          mov  di,0x6da2
C000:0B9C  BE 41 6D          mov  si,0x6d41
C000:0B9F  B9 0B 00          mov  cx,0x000b

compare_loop_C000_0BA2:
C000:0BA3  AC                lodsb
C000:0BA4  3A 05             cmp  al,[di]
C000:0BA6  75 05             jnz  alarm_compare_mismatch_C000_0BAD
C000:0BA8  4F                dec  di
C000:0BA9  E2 F8             loop compare_loop_C000_0BA2
C000:0BAB  F9                stc
C000:0BAC  C3                ret
C000:0BAD  F8                clc
C000:0BAE  C3                ret
```

`C000:0BAF` is the fallback compare. It snapshots the RTC and returns carry set
only when `[6D96]` and `[6D97]` are both zero, which reads as a seconds-at-zero
gate for the minute-plus-one fallback.

## State Boundary

| RAM/Port | Meaning |
| ---: | --- |
| `6D41..6D4C` | Selected scheduler/world-clock alarm buffer from `DC98:D3BB`. |
| `6D4E` | Fallback alarm active flag. |
| `6D96..6DA2` | Current RTC snapshot nibbles. |
| `0xD0..0xDF` | RTC register/mode ports. |
| `0xDD bit 0x08` | Timer advance gate used around selection/compare. |
| `0xDD bit 0x04` | Alarm output enable bit set before retained power handoff. |

## Next Splits

| Root | Split | Reason |
| --- | --- | --- |
| `DC98:D3BB`, `DC98:DB5E` | `organizer-alarm.md` | Application-side scheduler/world-clock alarm selection and wake decision. |
