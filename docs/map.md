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

The machine-readable first-pass region map is
[`rom-regions.tsv`](rom-regions.tsv). It is deliberately conservative: confirmed
code/resource ranges are split out where we have evidence, while broad mixed and
unknown ranges remain coarse until a recursive pass can prove tighter
boundaries. `tools/rom2.py regions` lists the map, and `tools/rom2.py io-scan`
uses it for code-only I/O sweeps.

## Coarse Layout

| File range | Physical range | First-pass notes |
| --- | --- | --- |
| `0x00000..0x3FFFF` | `0x80000..0xBFFFF` | Dictionaries, spelling/grammar data, character tables, and typing lesson text. The low mapped payload runs through file `0x1B413`, followed by a zero tail and erased padding to `0x1C000`; `3000:527C` confirms it is slot-0 engine page data by synthesizing a `6000:0000` descriptor, and `3000:2D5C`/`3000:20C2`/`3000:20F8` consume it as a nibble-coded page stream. Even 0x4000 pages in this low payload start with six-byte headers whose first bytes are `0x04`, `0x14`, `0x24`, and `0x34`, though the remaining header fields and token format remain undecoded. Visible strings include Merriam-Webster/Proximity copyrights at file `0x1C000`, the dictionary stream header at `0x1C100`, word lists around file `0x25987`, and character tables around file `0x3C096`. |
| `0x40000..0x467FF` | `0xC0000..0xC67FF` | Reset/startup code, interrupt stubs, low-level keyboard/LCD/power routines, diagnostic command code, terminal-mode strings, the three 48x40 battery/error icons at `0x44D30..0x44FFF`, and the dispatcher table at `0x45000`. |
| `0x46800..0x46A1C` | `0xC6800..0xC6A1C` | `C688:` far-call entry area plus diagnostic display script and embedded help strings. |
| `0x46A1D..0x46D12` | `0xC6A1D..0xC6D12` | C688 diagnostic/card wrappers, ROM-card execution helpers, inline display-script entry, and small state tables. |
| `0x46D13..0x49258` | `0xC6D13..0xC9258` | Early C688 editor/display and text-flow helpers with inline display-script bytes. |
| `0x49259..0x4A4E7` | `0xC9259..0xCA4E7` | Main application startup, inline display-script dispatcher/table area, and confirmed editor block heap manager. |
| `0x4A4E8..0x53884` | `0xCA4E8..0xD3884` | Mixed firmware code/tables, including split editor control/dispatch tables at `0x4A6DE..0x4A701`, `0x4CC78..0x4CC99`, and `0x4D1F8..0x4D234`, startup/file-menu/first-menu handlers through `0x4F51C`, the confirmed document-list template at `0x4F51C..0x4F57B`, document-picker/resource-loader helpers at `0x4F57B..0x50310`, accented-character tables at `0x50310..0x50376`, WP status refresh code/resources at `0x50376..0x5072B`, the 12x24 WP `Pag/Lin/Col` status-label bitmap at file `0x5072B`, its display-script island at `0x50AD0..0x50BD5`, split WP print/merge/address helpers and embedded filenames at `0x50BD5..0x517B6`, printer motion helpers at `0x517B6..0x52317`, and a split printer formatting/output cluster at `0x52317..0x53885`. Needs further function-boundary pass outside the confirmed subranges. |
| `0x53885..0x57FFF` | `0xD3885..0xD7FFF` | Startup banner, main application menu, and word-processor UI strings/resources; the banner display-script stream begins at `0x53888` / `C688:D008`. |
| `0x58000..0x6F6FF` | `0xD8000..0xEF6FF` | Font tail, DC98 application code, and menu resources. The main font runs continue through `0x5C8B6`, a confirmed 27-slot glyph tail runs at `0x5C8B6..0x5C98E`, DC98 code begins at file `0x5C98E`, known WP/Organizer/menu/file/WORLD CLOCK/terminal/file-wrapper code spans through `0x6DFA0`, and late display/resource tables occupy `0x6DFA0..0x6EFC2` before the confirmed icon/menu resource cluster. |
| `0x6EFC2..0x70500` | `0xEEFC2..0xF0500` | Communication, printer, ROM-card, and DreamLink menu icons/strings. |
| `0x70500..0x7FFFF` | `0xF0500..0xFFFFF` | Organizer resources, Typin' Time resources, high-ROM monitor data/code, and reset vectors. Split resources include organizer/WORLD CLOCK UI data at `0x70500..0x71CA6`, the 222-record WORLD CLOCK city table at `0x71CA6..0x74D36`, typing-practice text and pointer tables at `0x750E0..0x787E0`, Typin' Time UI resources at `0x787E0..0x78DC0`, the reset trampoline code island at `0x78DC0..0x78DD0`, a high-ROM resource prelude and alternate typing-practice copy at `0x78DD0..0x7C000`, CSiMON extension records at `0x7C000..0x7C0A0`, the CSiMON monitor body and entry stub at `0x7C0A0..0x7FF0A`, zero padding at `0x7FF0A..0x7FFF0`, and the final reset vector at `0x7FFF0`. |

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
