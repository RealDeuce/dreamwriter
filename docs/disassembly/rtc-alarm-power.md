# RTC Alarm Power Path

This slice follows the RTC alarm wake discriminator reached from warm startup
and from the retained-power path in [`power-irq.md`](power-irq.md).

No image assets are reached in this slice.

## Wake Discriminator

`C000:0784` decides whether an RTC wake is a scheduled application alarm, a
fallback re-arm, or a return to retained suspend. The path uses two compare
helpers: `C000:0B90` for the normal full alarm compare and `C000:0BAF` when
`[6D4E]` says the fallback alarm is already active.

```asm
alarm_wake_discriminator_C000_0784:
; file 0x40784
C000:0784  80 3E 4E 6D 00    cmp  byte [0x6d4e],0
C000:0789  75 ...            jnz  fallback_alarm_active
C000:078B  E8 02 04          call alarm_full_compare_C000_0B90
...
C000:0796  9A 5E DB 98 DC    call DC98:DB5E
...
C000:07B0  9A BB D3 98 DC    call DC98:D3BB
C000:07B6  E8 30 00          call save_framebuffer_C000_07E9
...
C000:07DB  E8 61 02          call C000:0A3F
C000:07DE  C6 06 4E 6D 01    mov  byte [0x6d4e],1
C000:07E3  E8 B7 FB          call C000:039D
C000:07E6  E9 87 FB          jmp  C000:0370
```

If the application-side check returns nonzero, the path jumps back to the
retained-power terminal branch at `C000:036A`. If the alarm should be shown, it
renders application resources through `C000:5AD6` after saving the framebuffer.
If the compare fails in a way that requires a fallback, it marks `[6D4E]=1`,
programs the fallback alarm, and returns to the suspend path.

## Framebuffer Save And Restore

The alarm-display path saves `0x800` words between the visible framebuffer and
the retained screen buffer. This is the same visible geometry implied by the
startup and icon bitmap work: the active LCD scanout is a 480x64 window backed
by a larger stride.

```asm
save_framebuffer_C000_07E9:
; file 0x407E9
C000:07E9  E8 4D 44          call battery_warning_clear_C000_4C39
C000:07EC  BE 00 10          mov  si,0x1000
C000:07EF  BF F0 94          mov  di,0x94f0
C000:07F2  EB 06             jmp  framebuffer_copy_C000_07FA

restore_framebuffer_C000_07F4:
C000:07F4  BE F0 94          mov  si,0x94f0
C000:07F7  BF 00 10          mov  di,0x1000
framebuffer_copy_C000_07FA:
C000:07FA  06                push es
C000:07FB  8C D8             mov  ax,ds
C000:07FD  8E C0             mov  es,ax
C000:07FF  FC                cld
C000:0800  B9 00 08          mov  cx,0x0800
C000:0803  F3 A5             rep  movsw
C000:0805  07                pop  es
C000:0806  C3                ret
```

## Warm Startup Wrapper

`C000:0807` wraps the discriminator during warm startup. On a handled alarm it
plays the wake buzzer through `C000:0883`, then restores the framebuffer before
returning to the normal boot/menu path. `C000:081F` is a related startup buzzer
variant; `C000:0825` renders an application resource and calls the low-level
tone helper documented in [`sound-lowlevel.md`](sound-lowlevel.md).

```asm
alarm_wake_wrapper_C000_0807:
; file 0x40807
C000:0807  E8 7A FF          call alarm_wake_discriminator_C000_0784
C000:080A  72 ...            jc   no_alarm_wake
...
C000:0815  E8 6B 00          call alarm_buzzer_C000_0883
C000:0818  E8 68 00          call alarm_buzzer_C000_0883
C000:081B  E8 D6 FF          call restore_framebuffer_C000_07F4
C000:081E  C3                ret
```

## State Boundary

| RAM | Meaning |
| ---: | --- |
| `6D4E` | Fallback-alarm active flag. |
| `6D79` | Saved/restored around the application-side alarm check. |
| `0x1000` | Visible framebuffer source/destination. |
| `0x94F0` | Retained framebuffer save area. |

## Next Splits

| Root | Split | Reason |
| --- | --- | --- |
| `C000:0376`, `039D`, `0B90`, `0BAF` | `rtc-programming.md` | RTC alarm register programming and compare details. |

The application-side schedule/alarm decision and display roots
`DC98:D3BB` and `DC98:DB5E` are covered by
[`organizer-alarm.md`](organizer-alarm.md).
