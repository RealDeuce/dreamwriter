# Early App-Loop Helper

This slice expands the remaining shallow app-loop target `C688:01B0`, selected
by event `0xF5` through `C688:ED1A` in
[`app-menu-event-loop.md`](app-menu-event-loop.md).

No image assets or new string resources are reached here. The diagnostic banner
resource is already decoded in [`diagnostics-ui.md`](diagnostics-ui.md), and the
command parser is expanded in [`diagnostic-monitor.md`](diagnostic-monitor.md).

## App-Loop Event Path

The shared app loop dispatches event `0xF5` to `C688:ED1A`. That target calls
`C688:01B0`, then immediately returns to the app loop.

```asm
app_loop_forced_diagnostic_event_C688_ED1A:
; file 0x5559A
C688:ED1A  E8 93 14          call C688:01B0
C688:ED1D  EB 80             jmp  C688:EC9F
```

`C688:01B0` is a tiny far-call wrapper into the `C000` diagnostic monitor.

```asm
forced_diagnostic_wrapper_C688_01B0:
; file 0x46A30
C688:01B0  9A 3C 12 00 C0    call C000:123C
C688:01B5  C3                ret
```

## Forced Diagnostic Entry

`C000:123C` is the forced diagnostic-monitor entry. It differs from the
warm-path diagnostic gate at `C000:1240`: it skips the `SPACE+F+J` chord
compare at `C000:1252` and enters the banner/parser loop directly.

```asm
forced_diagnostic_entry_C000_123C:
; file 0x4123C
C000:123C  E8 08 00          call C000:1247
C000:123F  CB                retf
```

The shared body at `C000:1247` draws the short diagnostic banner and runs the
monitor command parser. If the parser returns carry clear, the banner is drawn
again and the command loop repeats. If the parser returns carry set, the forced
entry returns far to `C688:01B0`, which returns to `C688:ED1D` and then back to
`C688:EC9F`.

```asm
diagnostic_banner_and_loop_C000_1247:
; file 0x41247
C000:1247  E8 28 00          call C000:1272      ; draw short banner
C000:124A  E8 42 00          call C000:128F      ; diagnostic command parser
C000:124D  72 02             jc   C000:1251
C000:124F  EB F6             jmp  C000:1247
C000:1251  C3                ret
```

For comparison, the warm diagnostic gate performs the chord check first:

```asm
diagnostic_chord_gate_C000_1240:
; file 0x41240
C000:1240  E8 0F 00          call C000:1252
C000:1243  74 02             jz   C000:1247
C000:1245  F8                clc
C000:1246  C3                ret
```

## Bottom

This root bottoms out at already documented diagnostic code:

| Target | Existing slice |
| --- | --- |
| `C000:1272` | [`diagnostic-monitor.md`](diagnostic-monitor.md#startup-banner) |
| `C000:128F` | [`diagnostic-monitor.md`](diagnostic-monitor.md#command-line-state) |
| `C688:0086` resource | [`diagnostics-ui.md`](diagnostics-ui.md#diagnostic-string-resource) |

The app-loop event `0xF5` is therefore an in-application forced diagnostic
monitor entry, not a separate application handler.
