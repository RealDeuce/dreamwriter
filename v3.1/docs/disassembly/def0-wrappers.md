# DEF0 Wrappers

The `DEF0` segment (file `0xDEF00`, physical `0xDEF00`) is the v3.1 equivalent
of v2.1's `DC98` segment. It contains thin far-call wrapper functions used by
the application runtime. Most wrappers follow the same pattern: save registers,
call an inner routine or issue INT 21h, restore registers, RETF.

The segment is in window 6 (CPU `0xC0000..0xDFFFF`) alongside the `C000` and
`C772` code.

## Wrapper Pattern

Typical DEF0 wrapper:

```asm
DEF0:000B  55                push bp
DEF0:000C  57                push di
DEF0:000D  56                push si
DEF0:000E  52                push dx
DEF0:000F  51                push cx
DEF0:0010  E8 F0CD           call DEF0:CE03      ; inner routine
DEF0:0013  59                pop cx
DEF0:0014  5A                pop dx
DEF0:0015  5E                pop si
DEF0:0016  5F                pop di
DEF0:0017  5D                pop bp
DEF0:0018  CB                retf
```

## Confirmed Wrappers

| Offset | Inner call | Notes |
| --- | --- | --- |
| `DEF0:000B` | `call DEF0:CE03` | |
| `DEF0:0019` | `call DEF0:CE6A` | |
| `DEF0:0027` | `call DEF0:CE36` | |
| `DEF0:0035` | `call DEF0:CE92` | |
| `DEF0:0043` | INT 21h AH=08h | Keyboard char input (no echo). Returns AL; checks for `0xEB` special. |
| `DEF0:0063` | INT 21h AH=0Bh | Check keyboard input status. |
| `DEF0:0074` | INT 21h AH=2Ah | Get date; stores to `[18E3]...[18E9]`. Near RET (not RETF). |
| `DEF0:0098` | INT 21h AH=2Ch | Get time; stores to `[18EB]...[18F1]`. |
| `DEF0:00F9` | INT 21h AH=2Bh | Set date. |

## Data Before First Wrapper

The first 10 bytes at `DEF0:0000..0009` appear to be data, not code:

```text
DEF0:0000  20 20 00 00 20 40 F8 40 20 00
```

Data bytes, not code: `20 20 00 00 20 40 F8 40 20 00`. No `FF`
prefix, so not a display script. Contains spaces (0x20) and two
values with bit 6 set (0x40, 0xF8) — consistent with a glyph
bitmap or pixel mask used by the display rendering chain.

## Far-Call Table References

The low-RAM far-call table installed at boot (`[0200]...[029C]`) contains 38
entries pointing into `DEF0`. These provide the application runtime at `C772`
with indirect far-call access to display, keyboard, file, and date/time
services without needing to know exact offsets.

## Comparison With v2.1

| Element | v2.1 | v3.1 |
| --- | --- | --- |
| Wrapper segment | `DC98` | `DEF0` |
| File base | `0x5C980` | `0xDEF00` |
| Window offset | `0x1C980` into window 6 | `0x1EF00` into window 6 |
| Far-call table entries | 38 (to `DC98`) | 38 (to `DEF0`) |
| INT 21h wrappers | yes | yes (same pattern) |
