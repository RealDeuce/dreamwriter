# ROM Map

Working target: `t4_ir_2.1.ic303`

```text
Size:   524288 bytes
SHA256: bb6a437d4c25f90eb7a0b8bc3d41e1ca2c74196aabe60954a598c66405397757
```

## Address Model

Current `mame/nakajies.cpp` loads the v2.1 BIOS into the MAME `bios` region at
region offset `0x80000..0xFFFFF`, because that driver also carries a 1 MiB v3.1
BIOS. These notes use offsets into the standalone 512 KiB `t4_ir_2.1.ic303`
file. For that standalone image, the reset bank state maps the last 128 KiB ROM
bank into every 128 KiB CPU window, so the reset vector at CPU physical
`0xFFFF0` corresponds to standalone file offset `0x7FFF0`.

For the normal 2.1 `C000:xxxx` code window, current notes use:

```text
physical = file offset + 0x80000
file offset = physical - 0x80000
```

Examples:

```text
C000:0000 -> physical 0xC0000 -> file 0x40000
C000:1240 -> physical 0xC1240 -> file 0x41240
C688:0053 -> physical 0xC68D3 -> file 0x468D3
F8DC:0000 -> physical 0xF8DC0 -> file 0x78DC0
```

This address conversion is valid for currently mapped CPU addresses in the boot
and main `C000` ROM windows. Other bank settings can map the same CPU address to
different 128 KiB ROM/RAM banks.

## Banking Model

Detailed banking notes are in [`banking.md`](banking.md).

MAME maps the 1 MiB V20 address space as eight 128 KiB banks:

| CPU range | Bank | Select port |
| --- | ---: | ---: |
| `0x00000..0x1FFFF` | 0 | `0x10` |
| `0x20000..0x3FFFF` | 1 | `0x11` |
| `0x40000..0x5FFFF` | 2 | `0x12` |
| `0x60000..0x7FFFF` | 3 | `0x13` |
| `0x80000..0x9FFFF` | 4 | `0x14` |
| `0xA0000..0xBFFFF` | 5 | `0x15` |
| `0xC0000..0xDFFFF` | 6 | `0x16` |
| `0xE0000..0xFFFFF` | 7 | `0x17` |

For a bank register value `v`, values `0x00..0x07` select ROM bank
`((v & 0x0F) ^ 0x0F)`, and values with bit `0x10` set select RAM. The current
MAME patch also lets selected DreamWriter configs treat bit `0x08` as RAM.
For those bit-3-only RAM selects, the RAM page follows the CPU window rather
than the low-nibble ROM-bank formula. That preserves the v3.x/T200-era use of
values through `0x07` for 1 MiB ROMs while still allowing T400 `0x0E` and the
1 MiB DreamWriter `0x0F` startup/default mappings to expose RAM in the
`0x20000..0x3FFFF` window.

Initial bank registers are zero, which maps the last ROM bank into every CPU
window.

The DreamWriter T400 has 256 KiB RAM in MAME.

Use `tools/rom2.py` for conversion checks:

```sh
tools/rom2.py verify
tools/rom2.py addr C688:0053
tools/rom2.py strings --start 0x40000 -n 12
```

## Coarse Layout

| File range | Physical range | First-pass notes |
| --- | --- | --- |
| `0x00000..0x3FFFF` | `0x80000..0xBFFFF` | Dictionaries, spelling/grammar data, character tables, and typing lesson text. Visible strings include Merriam-Webster/Proximity copyrights at file `0x1C000`, word lists around file `0x25987`, and character tables around file `0x3C096`. |
| `0x40000..0x467FF` | `0xC0000..0xC67FF` | Reset/startup code, interrupt stubs, low-level keyboard/LCD/power routines, diagnostic command code, terminal-mode strings, the three 48x40 battery/error icons at `0x44D30..0x44FFF`, and the dispatcher table at `0x45000`. |
| `0x46800..0x46BFF` | `0xC6800..0xC6BFF` | `C688:` far-call entry area plus diagnostic banner/help strings. |
| `0x46C00..0x537FF` | `0xC6C00..0xD37FF` | Mixed firmware code/tables. Needs function-boundary pass. |
| `0x53800..0x57FFF` | `0xD3800..0xD7FFF` | Main application menu and word-processor UI strings. |
| `0x58000..0x6F6FF` | `0xD8000..0xEF6FF` | Mixed application code/resources. Needs a call-reference pass from menu handlers. |
| `0x6F700..0x704FF` | `0xEF700..0xF04FF` | ROM card, communication, printer/image, and DreamLink UI strings. |
| `0x70500..0x7FFFF` | `0xF0500..0xFFFFF` | Typing tutor lessons/resources, including version text at file `0x788D3`, reset trampoline at file `0x78DC0`, and final reset vector at file `0x7FFF0`. |

## Reset Chain

The CPU reset vector is at physical `0xFFFF0`, file `0x7FFF0`:

```asm
FFFF:0000  cli
FFFF:0001  jmp far F8DC:0000
```

The reset trampoline at physical `0xF8DC0`, file `0x78DC0`, performs two port
writes before entering the normal firmware segment:

```asm
F8DC:0000  mov al,01
F8DC:0002  out 16,al
F8DC:0004  mov al,00
F8DC:0006  out 17,al
F8DC:0008  jmp far C000:0000
```

Normal startup then begins at `C000:0000`:

```asm
C000:0000  jmp C000:0029
```
