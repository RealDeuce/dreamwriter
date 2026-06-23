# Banking Notes

MAME models the V20 address space as eight 128 KiB windows selected by I/O
ports `0x10..0x17`. See [`map.md`](../v2.1/docs/map.md) for the general formula.

## Quick Mental Model

Keep three concepts separate:

1. **CPU physical windows.** The V20 has a 1 MiB physical address space. The
   banking hardware divides it into eight 128 KiB windows:

   | Port | CPU physical range |
   | ---: | --- |
   | `0x10` | `00000..1FFFF` |
   | `0x11` | `20000..3FFFF` |
   | `0x12` | `40000..5FFFF` |
   | `0x13` | `60000..7FFFF` |
   | `0x14` | `80000..9FFFF` |
   | `0x15` | `A0000..BFFFF` |
   | `0x16` | `C0000..DFFFF` |
   | `0x17` | `E0000..FFFFF` |

2. **Bank-register values.** Writing a value to one of those ports selects
   what backs that 128 KiB CPU window:

   - values `0x00..0x07` select ROM banks.
   - values with bit `0x10` set select internal RAM.
   - some DreamWriter configs also treat bit `0x08` alone as internal RAM; in
     that bit-3-only case, the RAM page follows the CPU window.
   - PCMCIA/card windows are modeled separately in MAME and are selected by
     other bank values in card-access paths.

   More explicitly, the current MAME decode is:

   | Value pattern | Current MAME target | Page selection |
   | --- | --- | --- |
   | `0x00..0x07` | ROM | page `0x0F - low_nibble`, mirrored to installed ROM size |
   | `0x08..0x0F` | bit-3-only RAM mode, or disabled on configs that do not support it | RAM page follows CPU window on current DreamWriter configs |
   | `0x10..0x17` | internal SRAM | page `(0x0F - low_nibble) % internal_ram_pages` |
   | `0x18..0x1F` with no PC Card present | internal SRAM | page `(0x0F - low_nibble) % internal_ram_pages` |
   | `0x18..0x1F` with PC Card present | PC Card common memory | card page `0x0F - low_nibble` |

   For an 8 Mbit / 1 MiB ROM, the ROM pages are eight 128 KiB chunks. MAME
   mirrors the 8 physical pages into the 16 possible ROM-bank entries, so reset
   entry `0x0F` reads the highest physical ROM page:

   | Write value | ROM entry | 1 MiB ROM file range |
   | ---: | ---: | --- |
   | `0x00` | `0x0F` | `0xE0000..0xFFFFF` |
   | `0x01` | `0x0E` | `0xC0000..0xDFFFF` |
   | `0x02` | `0x0D` | `0xA0000..0xBFFFF` |
   | `0x03` | `0x0C` | `0x80000..0x9FFFF` |
   | `0x04` | `0x0B` | `0x60000..0x7FFFF` |
   | `0x05` | `0x0A` | `0x40000..0x5FFFF` |
   | `0x06` | `0x09` | `0x20000..0x3FFFF` |
   | `0x07` | `0x08` | `0x00000..0x1FFFF` |

   With two 1 Mbit SRAMs configured as 256 KiB total, internal SRAM has two
   128 KiB pages. In the current MAME model, `0x10..0x17` select those pages by
   the inverted low-nibble modulo two:

   | Write value | Internal SRAM page |
   | ---: | ---: |
   | `0x10`, `0x12`, `0x14`, `0x16` | page 1 |
   | `0x11`, `0x13`, `0x15`, `0x17` | page 0 |

   Values `0x18..0x1F` use the same internal-SRAM page calculation only when
   no PC Card is present. When a PC Card is present, current MAME routes those
   values to card common-memory pages instead:

   | Write value | PC Card page | Card byte range |
   | ---: | ---: | --- |
   | `0x1F` | 0 | `0x00000..0x1FFFF` |
   | `0x1E` | 1 | `0x20000..0x3FFFF` |
   | `0x1D` | 2 | `0x40000..0x5FFFF` |
   | `0x1C` | 3 | `0x60000..0x7FFFF` |
   | `0x1B` | 4 | `0x80000..0x9FFFF` |
   | `0x1A` | 5 | `0xA0000..0xBFFFF` |
   | `0x19` | 6 | `0xC0000..0xDFFFF` |
   | `0x18` | 7 | `0xE0000..0xFFFFF` |

   The PC Card mapping above is emulator-derived and still needs board-level
   confirmation. It matches the observed formatter/window-helper behavior, but
   the exact glue that distinguishes internal SRAM from PC Card SRAM has not
   been traced on hardware.

   A simpler likely hardware decode, given an 8 Mbit ROM, two 1 Mbit SRAMs,
   and a PC Card slot on the same bus, is:

   | Write value | Likely physical target | Low-nibble role |
   | --- | --- | --- |
   | `0x00..0x07` | ROM | inverted bank select |
   | `0x08..0x0F` | internal SRAM bank 1 | ignored |
   | `0x10..0x17` | internal SRAM bank 0 | ignored |
   | `0x18..0x1F` | PC Card common memory | inverted bank select |

   This model explains the cold-start defaults neatly:

   | Port | Value | Likely target |
   | ---: | ---: | --- |
   | `0x10` | `0x17` | internal SRAM bank 0 at CPU `00000..1FFFF` |
   | `0x11` | `0x0F` | internal SRAM bank 1 at CPU `20000..3FFFF` |
   | `0x12` | `0x1F` | PC Card page 0 at CPU `40000..5FFFF` |
   | `0x13` | `0x1E` | PC Card page 1 at CPU `60000..7FFFF` |
   | `0x14` | `0x1D` | PC Card page 2 at CPU `80000..9FFFF` |
   | `0x15` | `0x1C` | PC Card page 3 at CPU `A0000..BFFFF` |
   | `0x16` | `0x01` | ROM page 6 at CPU `C0000..DFFFF` |
   | `0x17` | `0x00` | ROM page 7 at CPU `E0000..FFFFF` |

   In that model, the current emulator's internal-RAM modulo behavior for
   `0x10..0x17` is an implementation shortcut that matches the values firmware
   normally uses, rather than a literal statement that the low nibble is decoded
   by the SRAM hardware. The same may be true for the no-card fallback of
   `0x18..0x1F` to internal RAM.

3. **Disassembly segment labels.** Labels such as `C000`, `C772`, `DEF0`,
   `DF80`, or `AD00` are not independent memory maps. They are convenient
   segment:offset views into whichever 128 KiB CPU window is currently visible.
   For example, with `port 0x16 = 0x01`, the CPU range `C0000..DFFFF` contains
   the ROM bank used by the low-level firmware, so `C000:0000`, `C772:0006`,
   and nearby aliases are all different segment names for addresses inside that
   same selected window.

For 1 MiB ROMs, the normal reset trampoline sets:

```asm
out 16, 01h   ; CPU C0000..DFFFF -> ROM file C0000..DFFFF
out 17, 00h   ; CPU E0000..FFFFF -> ROM file E0000..FFFFF
```

The startup code then makes the lower six windows RAM-backed. That means boot
usually runs with low RAM, a fixed `C000` firmware ROM window, and a fixed high
ROM window. Temporary routines can still remap other windows for spell data,
PCMCIA/card access, or larger RAM/resource scans.

Version-specific segment names differ. For example, the older v3.1 image uses
`DEF0` for the service layer, while v3.1.260 maps the equivalent service layer
as `DF80`. The role is similar; the exact segment labels and offsets are not
interchangeable.

Use `tools/rom2.py bank` to check a specific port/value:

```sh
tools/rom2.py bank 0x16 0x01 --cpu 0xC0000
tools/rom2.py bank 0x17 0x00 --cpu 0xFFFF0
tools/rom2.py bank 0x11 0x02 --cpu 0x30000
```

Note: `rom2.py bank` is still useful for the older address model, but it is not
the source of truth for v3.1.260 segment aliases. Use `tools/romtool.py
--v31-260` for v3.1.260 segment/file conversions.

## Reset Mapping

On V20 reset, execution starts at physical `0xFFFF0` (`FFFF:0000` in the current
notes). MAME reset selects the ROM view for all eight 128 KiB windows and sets
all ROM banks to entry `0x0F`. For the standalone 512 KiB T400 v2.1 ROM image,
that entry corresponds to the final image bank, file `0x60000..0x7FFFF`. In the
current `mame/nakajies.cpp` BIOS region, those same bytes live at region offset
`0xE0000..0xFFFFF` because v2.1 is loaded at region offset `0x80000`.

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

### T400 v2.1

Early T400 v2.1 startup at `C000:0029` writes the bank registers explicitly:

| Port | Value | Effect in MAME |
| ---: | ---: | --- |
| `0x10` | `0x17` | CPU `00000..1FFFF` -> RAM offset `00000..1FFFF` |
| `0x11` | `0x0E` | CPU `20000..3FFFF` -> RAM offset `20000..3FFFF` |
| `0x12` | `0x1F` | CPU `40000..5FFFF` -> RAM offset `00000..1FFFF` |
| `0x13` | `0x1E` | CPU `60000..7FFFF` -> RAM offset `20000..3FFFF` |
| `0x14` | `0x1D` | CPU `80000..9FFFF` -> RAM offset `00000..1FFFF` |
| `0x15` | `0x1C` | CPU `A0000..BFFFF` -> RAM offset `20000..3FFFF` |
| `0x16` | `0x01` | CPU `C0000..DFFFF` -> ROM file `40000..5FFFF` |
| `0x17` | `0x00` | CPU `E0000..FFFFF` -> ROM file `60000..7FFFF` |

The `0x11 = 0x0E` case was validated against the built-in store formatter:
`C000:2C93` formats five 32 KiB units starting at segment `0x1800`, so after
the first 32 KiB the loop writes through CPU `0x20000..0x3FFFF`. Treating
`0x0E` as a ROM mirror makes FILE -> INITIALIZE fail with a store-memory read
error partway through the 160 KiB format pass.

Routine `C000:0225` stores the default values for ports `0x11..0x15` in low
RAM:

```asm
[6D8D] = 0E1F  ; restore port 12 from AL=1F, then port 11 from AH=0E
[6D8F] = 1E1D  ; restore port 14 from AL=1D, then port 13 from AH=1E
[6D91] = 1C    ; restore port 15
```

Routine `C000:01E0` restores those saved bank values before returning to a warm
saved context.

### 128 KiB RAM-Family 512 KiB ROMs

The smaller MAME systems marked as 128 KiB RAM machines use 512 KiB ROM images,
not 128 KiB ROM images. The local set checked here was:

| Image | Reset target | Bank mirror bytes |
| --- | --- | --- |
| `wales210.ic303` | `F072:0000` | `[7680]`, `[7682]`, `[7684]` |
| `dator3000.ic303` | `F069:0000` | `[95E2]`, `[95E4]`, `[95E6]` |
| `nakajima_es.ic303` | `F097:0000` | `[7680]`, `[7682]`, `[7684]` |
| `t100_2.3.ic303` | `F4E9:0000` | `[6D95]`, `[6D97]`, `[6D99]` |
| `dr3_1_02uk.ic303` | `F107:0000` | `[7680]`, `[7682]`, `[7684]` |
| `dr3_1_03.ic303` | `F650:0000` | `[7680]`, `[7682]`, `[7684]` |
| `nts_325_basic.ic303` | `F12F:0000` | `[7680]`, `[7682]`, `[7684]` |

All of these reset trampolines write the high ROM windows the same way:

```asm
mov al,01
out 16,al
mov al,00
out 17,al
jmp far C000:0000
```

Then early startup at `C000:0029` writes all eight bank ports explicitly:

```asm
out 10,17h
out 11,0Eh
out 12,1Fh
out 13,1Eh
out 14,1Dh
out 15,1Ch
out 16,01h
out 17,00h
```

This is the same low-window map as T400 v2.1. Under the likely hardware decode,
`0x17` selects the first internal SRAM bank, `0x0E` selects the second internal
SRAM bank, `0x1F..0x1C` select the first four PC Card/common-memory pages, and
`0x01/0x00` select the top two visible ROM pages. With a 512 KiB ROM, the
inverted ROM page values mirror into the four physical 128 KiB ROM chunks, so
`0x01` maps CPU `C0000..DFFFF` to ROM file `0x40000..0x5FFFF`, and `0x00`
maps CPU `E0000..FFFFF` to ROM file `0x60000..0x7FFFF`.

The mirror initializer stores the same default values in image-specific
low-RAM locations:

```asm
[mirror0] = 0E1F  ; restore port 12 from AL=1F, then port 11 from AH=0E
[mirror1] = 1E1D  ; restore port 14 from AL=1D, then port 13 from AH=1E
[mirror2] = 1C    ; restore port 15
```

The dynamic two-window helper is also the same pattern as T400 v2.1: it slides
ports `0x14` and `0x15` through `0x1D..0x18` based on `DX`, updates the
mirrors, and writes the two ports immediately.

The common banked service wrapper temporarily maps ROM resources into the low
windows:

```asm
out 11,02h
out 12,17h
out 13,03h
out 14,02h
call far [cs:service_pointer]
out 11,0Eh
out 12,1Fh
out 13,1Eh
out 14,1Dh
```

That again matches the inverted ROM-bank select for the `0x00..0x07` values
and the special internal-SRAM selects for `0x0E`/`0x17`.

### DreamWriter 450 ROM `t4_ir_35ba308.ic303`

The T450 image is a 1 MiB ROM. Its reset vector at file `0xFFFF0` jumps to
`F7A1:0000`, which maps to file `0xF7A10`:

```asm
F7A1:0000  cli
F7A1:0001  mov al,01
F7A1:0003  out 16,al
F7A1:0005  mov al,00
F7A1:0007  out 17,al
F7A1:0009  jmp far C000:0000
```

With a 1 MiB ROM region, port `0x16 = 0x01` maps CPU
`0xC0000..0xDFFFF` to ROM file `0xC0000..0xDFFFF`, so T450 startup executes
from file `0xC0000`.

T450 `C000:0000` starts similarly, but it only writes ports `0x10`, `0x16`,
and `0x17` directly, then restores ports `0x11..0x15` from low-RAM defaults.
Routine `C000:0305` seeds those defaults as:

```asm
[147F] = 0F1F  ; restore port 12 from AL=1F, then port 11 from AH=0F
[1481] = 1E1D  ; restore port 14 from AL=1D, then port 13 from AH=1E
[1483] = 1C    ; restore port 15
```

This is why the current MAME driver treats bit-3-only RAM selects differently
from bit-4 RAM selects: for `0x08..0x0F`, the RAM page follows the CPU window,
so both T400 v2.1 `port 0x11 = 0x0E` and the 1 MiB ROMs'
`port 0x11 = 0x0F` expose the upper 128 KiB RAM page instead of aliasing low
RAM over the framebuffer. With the old `((v ^ 0x0F) << 17)` calculation,
`0x0F` selected RAM page 0 and the 1 MiB DreamWriter ROMs corrupted the LCD
while counting at startup.

Interactive MAME testing confirmed that this mapping lets the working
512 KiB-family machines and the 1 MiB DreamWriter ROMs boot and initialize
their built-in RAM stores correctly:

| Driver / BIOS | Result |
| --- | --- |
| `wales210` all BIOS versions | Boot and format built-in memory. |
| `drwrt100` | Boots and formats built-in memory. |
| `dator3k` | Boots and formats built-in memory. |
| `es210_es` | Boots and formats built-in memory. |
| `drwrt200` | Boots and initializes built-in RAM after the bit-3 window fix. |
| `drwrt400` v3.1 | Boots and initializes built-in RAM after the bit-3 window fix. |
| `drwrt400` v2.1 | Boots and initializes built-in RAM. |
| `drwrt450` | Boots and initializes built-in RAM after the bit-3 window fix. |

The T450 config is currently set to 256 KiB because this mapping needs an upper
RAM page for the `0x0F` startup window. The exact physical RAM population still
needs board-level confirmation.

### DreamWriter v3.1.260 Bank-Write Audit

The v3.1.260 ROM uses the same reset/startup shape as the other 1 MiB images.
The reset trampoline at `F733:0000` writes:

```asm
F733:0001  mov al,01
F733:0003  out 16,al
F733:0005  mov al,00
F733:0007  out 17,al
F733:0009  jmp far C000:0000
```

Early `C000:0000` repeats that setup for the normal runtime ROM windows and
maps the first low window to internal SRAM:

```asm
C000:002A  mov al,17
C000:002C  out 10,al
C000:002E  mov al,01
C000:0030  out 16,al
C000:0032  mov al,00
C000:0034  out 17,al
```

Routine `C000:0327` seeds the bank-register mirrors used by the cold, warm, and
NMI/context-restore paths:

```asm
[147B] = 0F1F  ; restore port 12 from AL=1F, then port 11 from AH=0F
[147D] = 1E1D  ; restore port 14 from AL=1D, then port 13 from AH=1E
[147F] = 1C    ; restore port 15
```

Those values align with the likely hardware decode: `0x0F` selects internal
SRAM bank 1 for CPU `20000..3FFFF`, `0x1F..0x1C` select PC Card/common-memory
pages 0..3 for CPU `40000..BFFFF`, and `0x01/0x00` keep the fixed low/high ROM
service windows visible at CPU `C0000..FFFFF`.

The meaningful v3.1.260 bank writes found so far are:

| Location | Ports/values | Purpose |
| --- | --- | --- |
| `F733:0003`, `F733:0007` | `0x16=0x01`, `0x17=0x00` | Reset trampoline maps the two high ROM windows. |
| `C000:002C`, `C000:0030`, `C000:0034` | `0x10=0x17`, `0x16=0x01`, `0x17=0x00` | Startup maps low SRAM bank 0 and fixed ROM service windows. |
| `C000:009C..00B5`, `C000:00EC..0105`, `C000:02BE..02D3` | restore ports `0x11..0x15` from `[147B]`, `[147D]`, `[147F]` | Cold/warm/context restore of the shadowed low-window map. |
| `C000:033B` | updates `[147D]` and `[147F]`, then writes ports `0x14` and `0x15` | Sliding two-window PC Card/common-memory helper. |
| `C000:18B6` | after `C000:1B60`, writes `0x13=0x03`, `0x14=0x02` | Temporary ROM-resource mapping for the selected table/helper path. |
| `C000:1D3D` | `0x12=0x07`, `0x13=0x06`, `0x14=0x05`, `0x15=0x04` | Temporary ROM pages 0..3 in CPU `40000..BFFFF`; restores from mirrors after the call. |
| `C000:1D6D` | `0x12=0x04`, `0x13=0x03`, `0x14=0x02`, `0x15=0x01` | Temporary ROM pages 3..6 in CPU `40000..BFFFF`; restores from mirrors after the call. |
| `EDAB:22AD` / `EF50:085D` | save `[147F]`, set `[147F]=0x02`, write `0x15=0x02`, call `AD00:009A`, restore | Maps ROM page 5 into CPU `A0000..BFFFF` for an `AD00` banked service call. |

The shadow-address scan only found code writes to `[147B]`, `[147D]`, and
`[147F]` in the initializer, the `C000:033B` helper, and the `EDAB:22AD`
wrapper. Nearby byte-address matches such as `[147C]` and `[147E]` were data or
instruction-immediate false positives, not independent bank mirrors.

Raw byte scans also show apparent `E6 16` matches in the display-rendering area,
but disassembly shows these are operands such as `A2 E6 16`
(`mov [0x16E6],al`) and not writes to port `0x16`.

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

This target is now tracked as the banked spell/grammar/linguistic service thunk. See
[`spell-engine.md`](../v2.1/docs/spell-engine.md) for the dispatcher and diagnostic `Q/R`
service IDs. It is
reached from routines including `C000:02A8`, `C000:02B0`, `C000:02B8`,
`C000:12FB`, and `C000:15F1`.

## Dynamic Window Mapping At C000:0239 / C000:033B

Routine `C000:0239` in the older v2.1 image, and the equivalent `C000:033B` in
v3.1.260, select temporary values for ports `0x14` and `0x15` based on `DX`,
then adjust `DX` into the selected 128 KiB window:

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
