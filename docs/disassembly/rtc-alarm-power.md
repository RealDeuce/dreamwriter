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
C000:0798  9A 5E DB 98 DC    call DC98:DB5E
...
C000:07B7  9A BB D3 98 DC    call DC98:D3BB
C000:07BC  E8 2A 00          call save_framebuffer_C000_07E9
...
C000:07DB  E8 61 02          call C000:0A3F
C000:07E0  C6 06 4E 6D 01    mov  byte [0x6d4e],1
C000:07E5  E8 B5 FB          call C000:039D
C000:07E8  EB 86             jmp  C000:0370
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
C000:07E9  B9 00 08          mov  cx,0x0800
C000:07EC  BE 00 10          mov  si,0x1000
C000:07EF  BF F0 94          mov  di,0x94f0
C000:07F2  F3 A5             rep  movsw
C000:07F4  C3                ret

restore_framebuffer_C000_07F4:
C000:07F4  B9 00 08          mov  cx,0x0800
C000:07F7  BE F0 94          mov  si,0x94f0
C000:07FA  BF 00 10          mov  di,0x1000
C000:07FD  F3 A5             rep  movsw
C000:07FF  C3                ret
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
C000:0814  E8 6C 00          call alarm_buzzer_C000_0883
C000:0817  E8 DA FF          call restore_framebuffer_C000_07F4
C000:081A  C3                ret
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
| `DC98:DB5E`, `DC98:D3BB` | `organizer-alarm.md` | Application-side schedule/alarm decision and display resources. |
