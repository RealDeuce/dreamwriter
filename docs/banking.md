# Banking Notes

MAME models the V20 address space as eight 128 KiB windows selected by I/O
ports `0x10..0x17`. See `map.md` for the general formula.

Use `tools/rom2.py bank` to check a specific port/value:

```sh
tools/rom2.py bank 0x16 0x01 --cpu 0xC0000
tools/rom2.py bank 0x17 0x00 --cpu 0xFFFF0
tools/rom2.py bank 0x11 0x02 --cpu 0x30000
```

## Reset Mapping

On V20 reset, execution starts at physical `0xFFFF0` (`FFFF:0000` in the current
notes). MAME reset selects the ROM view for all eight 128 KiB windows and sets
all ROM banks to entry `0x0F`. For the 512 KiB T400 ROM, MAME mirrors oversized
bank entries, so entry `0x0F` maps the final physical ROM bank
`0x60000..0x7FFFF`.

That means the reset vector at CPU physical `0xFFFF0` reads file `0x7FFF0`:

```asm
FFFF:0000  cli
FFFF:0001  jmp far F8DC:0000
```

The reset trampoline at `F8DC:0000` then writes:

```asm
F8DC:0000  mov al,01
F8DC:0002  out 16,al      ; CPU C0000..DFFFF -> ROM file 40000..5FFFF
F8DC:0004  mov al,00
F8DC:0006  out 17,al      ; CPU E0000..FFFFF -> ROM file 60000..7FFFF
F8DC:0008  jmp far C000:0000
```

This makes the normal `C000` firmware window map to file `0x40000..0x5FFFF`.
If the real hardware instead treats the top `0xC0000..0xFFFFF` ROM area as
fixed/unbanked during reset, the post-trampoline result is still functionally
the same for the code we execute: `C0000..DFFFF` sees file `0x40000..0x5FFFF`
and `E0000..FFFFF` sees file `0x60000..0x7FFFF`.

## Startup Mapping

Early startup at `C000:0029` writes the bank registers explicitly:

| Port | Value | Effect in MAME |
| ---: | ---: | --- |
| `0x10` | `0x17` | CPU `00000..1FFFF` -> RAM offset `00000..1FFFF` |
| `0x11` | `0x0E` | CPU `20000..3FFFF` -> ROM file `20000..3FFFF` |
| `0x12` | `0x1F` | CPU `40000..5FFFF` -> RAM offset `00000..1FFFF` |
| `0x13` | `0x1E` | CPU `60000..7FFFF` -> RAM offset `20000..3FFFF` |
| `0x14` | `0x1D` | CPU `80000..9FFFF` -> RAM offset `00000..1FFFF` |
| `0x15` | `0x1C` | CPU `A0000..BFFFF` -> RAM offset `20000..3FFFF` |
| `0x16` | `0x01` | CPU `C0000..DFFFF` -> ROM file `40000..5FFFF` |
| `0x17` | `0x00` | CPU `E0000..FFFFF` -> ROM file `60000..7FFFF` |

Routine `C000:0225` stores the default values for ports `0x11..0x15` in low
RAM:

```asm
[6D8D] = 0E1F  ; restore port 12 from AL=1F, then port 11 from AH=0E
[6D8F] = 1E1D  ; restore port 14 from AL=1D, then port 13 from AH=1E
[6D91] = 1C    ; restore port 15
```

Routine `C000:01E0` restores those saved bank values before returning to a warm
saved context.

## Banked Spell/Linguistic Call At C000:18A1

The far pointer at `C000:189A` contains `3000:0000`:

```text
file 0x4189A: 00 00 00 30
```

Routine `C000:18A1` temporarily remaps several windows, calls that pointer, and
then restores the default mapping:

```asm
C000:18A7  mov al,02
C000:18A9  out 11,al      ; CPU 30000 maps to ROM file 30000
C000:18AD  mov al,17
C000:18AF  out 12,al
C000:18B4  mov al,03
C000:18B6  out 13,al
C000:18BA  mov al,02
C000:18BC  out 14,al
C000:18C1  call far [cs:189A]  ; calls 3000:0000
...
C000:18C9  out 11,al      ; restore 0E
C000:18CF  out 12,al      ; restore 1F
C000:18D6  out 13,al      ; restore 1E
C000:18DC  out 14,al      ; restore 1D
```

With port `0x11 = 0x02`, CPU physical `0x30000` maps to ROM file `0x30000`.
Those bytes disassemble as code and begin:

```asm
3000:0000  cld
3000:0001  push si
3000:0002  push es
3000:0003  push ds
3000:0004  push bp
```

This target is now tracked as the banked spell/linguistic service thunk. See
`spell-engine.md` for the dispatcher and diagnostic `Q/R` service IDs. It is
reached from routines including `C000:02A8`, `C000:02B0`, `C000:02B8`,
`C000:12FB`, and `C000:15F1`.

## Dynamic Window Mapping At C000:0239

Routine `C000:0239` selects temporary values for ports `0x14` and `0x15` based
on `DX`, then adjusts `DX` into the selected 128 KiB window:

| DX range | Port `0x14` | Port `0x15` | DX adjustment |
| --- | ---: | ---: | --- |
| `< 6000` | `1D` | `1C` | none |
| `6000..7FFF` | `1C` | `1B` | `DX -= 2000` |
| `8000..9FFF` | `1B` | `1A` | `DX -= 4000` |
| `A000..BFFF` | `1A` | `19` | `DX -= 6000` |
| `C000..DFFF` | `19` | `18` | `DX -= 8000` |
| `>= E000` | `18` | `18` | `DX -= A000` |

This looks like an address-window helper for accessing larger RAM/resource
spaces through the `80000..BFFFF` CPU windows. Its callers still need to be
traced.
