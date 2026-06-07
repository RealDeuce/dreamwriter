# Diagnostic UI Roots

This slice records the diagnostic roots that lead into, or configure, the
installed [`diagnostic-int1.md`](diagnostic-int1.md) hook. The full command UI
is broader than the `INT 1` hook itself, but these roots are reachable from the
warm diagnostic gates in [`boot.md`](boot.md) and [`power-irq.md`](power-irq.md).

No image assets are reached in this slice.
String resources use the descriptor notation from
[`display-resource-format.md`](display-resource-format.md).

## Diagnostic Chord Gate

`C000:1240` is reached from the warm/power paths before normal startup resumes.
It checks the diagnostic key chord/state and branches to the command UI when the
condition is met. `C000:1252` is the related compare helper called directly by
the `FFh` power root.

```asm
diagnostic_gate_C000_1240:
; file 0x41240
C000:1240  ...               ; inspect keyboard/diagnostic state
C000:1252  ...               ; diagnostic chord compare helper
...
C000:128F  ...               ; diagnostic command UI root
```

The important connection for the installed `INT 1` vector is the low-RAM watch
state. The UI seeds `[6EBC]`, `[6EBE]`, and `[6EC0]`; the hook at `C000:157D`
then compares those values against the interrupted CS:IP and either clears trap
flag, chains through vector `F8h`, or runs the active tone/delay loop.

## Diagnostic String Resource

The diagnostic UI renders from `C688:0086` / file `0x46906`. The startup banner
path renders only the first `0x42` bytes. The `?` command path renders `0xF9`
bytes from the same resource, exposing the longer command help page.

| Offset | Descriptor | Decoded text |
| ---: | --- | --- |
| `0x46906` | `FF 00`; `FF 04 00 06`; `FF 02 00 00 00 00` | `Diagnostic 21BAB047 (97Apr14)        K: Keyboard check` |
| `0x46948` | `FF 02 04 00 00 00` | `Mxxxx:yyyy     dump Memory` |
| `0x46968` | `FF 02 06 00 00 00` | `Sxxxx:yyyy,zz  Set memory` |
| `0x46987` | `FF 02 08 00 00 00` | `Y,Zxxxx:yyyy   Single step` |
| `0x469A7` | `FF 02 0A 00 00 00` | `Iyyyy  dump I/O,  L=dump I/O(alarm)` |
| `0x469D0` | `FF 02 0C 00 00 00` | `T=Card ATTR, N=COM, Q/R=Clear/Reset spell` |
| `0x469FF` | `FF 06 06 00 00 00 0A 00 E0 01 00 00 FE FF 00` | 15-byte display-script fragment, no printable text. |
| `0x46A0E` | `FF 06 04 00 00 00 0A 00 E0 01 00 00 02 00 00` | 15-byte display-script fragment, no printable text. |

Final short banner text:

```text
Diagnostic 21BAB047 (97Apr14)        K: Keyboard check
```

Final `?` help-page text:

```text
Diagnostic 21BAB047 (97Apr14)        K: Keyboard check
Mxxxx:yyyy     dump Memory
Sxxxx:yyyy,zz  Set memory
Y,Zxxxx:yyyy   Single step
Iyyyy  dump I/O,  L=dump I/O(alarm)
T=Card ATTR, N=COM, Q/R=Clear/Reset spell
```

The visible `T=Card ATTR` text is diagnostic command help, not evidence of a
PCMCIA attribute-space parser. In this path the `T` and `N` commands manipulate
the port `0x30` control-latch mirror, while storage/card status helpers live in
the `INT 21h` storage paths.

## INT 1 State Contract

| RAM | Meaning |
| ---: | --- |
| `6EBC` | Watched IP for the `INT 1` hook. |
| `6EBE` | Watched CS for the `INT 1` hook. |
| `6EC0` | Hook state byte; bit `0x80` forces active single-step behavior. |
| IVT `[03E0]` | Far-chain target used when the hook redirects through `F8h`. |

## Current Boundary

This file deliberately stops after the command UI resource and parser boundary.
The parser itself is expanded in [`diagnostic-monitor.md`](diagnostic-monitor.md).
The installed-vector question is resolved here: `INT 1` is not a generic
BIOS-compatible debugger service. It is a ROM diagnostic/single-step hook whose
state is private low RAM and whose escape path chains through the installed
`F8h` power vector.

## Next Splits

| Root | Split | Reason |
| --- | --- | --- |
| `C000:157D` | [`diagnostic-int1.md`](diagnostic-int1.md) | Installed hook body and trap-flag handling. |
