# Bitmap And UI Resource Tables

## 48x40 LCD Error Icons

The routines around `C000:4C4F` and `C000:4C6E` copy 40 rows of 6 bytes between
`0x94F0` and `0x131B`, with a destination/source stride of `0x3A`:

```asm
C000:4C5E  mov cx,0028   ; 40 rows
C000:4C62  mov cx,0006   ; 6 bytes per row
C000:4C65  rep movsb
C000:4C68  add di,003A
```

That is a 48x40-pixel bitmap block. `C000:4D07` copies one selected `0xF0`-byte
block from `C000:4D30` into the same `0x131B` screen area:

```asm
C000:4D0E  mov cx,00F0
C000:4D12  mul cx
C000:4D14  mov si,4D30
C000:4D17  add si,ax
```

Use:

```sh
tools/rom2.py bitmap --base 0x44d30 --row-bytes 6 --height 40 --count 3
```

Do not invert these when checking against the manual. The documented icons are
mostly solid, so the raw bit polarity is the useful LCD view.

Confirmed documented 48x40 error icons:

| Index | File offset | Code address | Meaning |
| ---: | ---: | --- | --- |
| `0` | `0x44D30` | `C000:4D30` | Main battery low. |
| `1` | `0x44E20` | `C000:4E20` | CR2032 memory-retention battery low. |
| `2` | `0x44F10` | `C000:4F10` | PCMCIA SRAM card battery low. |

## Dispatcher Table After Error Icons

The next `0xF0`-aligned location, file `0x45000` / `C000:5000`, is not a fourth
48x40 icon. It is a translation table followed by handler pointers and an
interrupt-style dispatcher.

The first table maps `AH` values below `0x60` to compact handler indices:

```text
file 0x45000 / C000:5000: 96-byte byte translation table
file 0x45060 / C000:5060: word handler table
file 0x45097 / C000:5097: dispatcher prologue
```

The dispatcher indexes both tables through `CS`:

```asm
C000:50C1  cmp ah,FF
C000:50C6  cmp ah,60
C000:50D1  mov al,[cs:si+5000]
C000:50D6  cmp al,FF
C000:50DA  shl ax,1
C000:50DE  mov ax,[cs:si+5060]
C000:50E4  call ax
```

This explains why rendering from `0x45000` as a bitmap produces garbage: it is
code/table material that happens to follow the three same-sized error-icon
frames.

## Startup Menu Bitmap Records

The first menu screen uses `FF 42` bitmap records decoded by `C000:6648`. Scan
for those records with:

```sh
tools/rom2.py bitmap-records --start 0x53800 --end 0x58000 --commands
tools/rom2.py bitmap-records --start 0x40000 --end 0x80000 --require-position --commands
tools/rom2.py position-ops --start 0x50000 --end 0x58000
```

The scanner defaults to the MAME LCD geometry as the maximum plausible visible
bitmap size: 480x64 pixels. MAME renders 60 bytes per row from a 64-byte-stride
scanout buffer, so the stored framebuffer window is `0x1000` bytes while the
visible area is 480x64.

The whole-ROM positioned scan currently finds only the four startup menu records
below. Without `--require-position`, the scan also finds a confirmed unpositioned
12x24 label bitmap at file `0x5072B`; see below.

Confirmed startup menu bitmap records:

| Record | Position | Source | Size | Bytes |
| ---: | --- | --- | --- | ---: |
| `0x539C8` | `6,130` | `C688:D1AF` / `0x53A2F` | `36x34` | `0xAA` |
| `0x539D8` | `11,135` | `C688:D259` / `0x53AD9` | `24x7` | `0x15` |
| `0x539FC` | `6,314` | `C688:D1AF` / `0x53A2F` | `36x34` | `0xAA` |
| `0x53A0C` | `11,319` | `C688:D26E` / `0x53AEE` | `24x7` | `0x15` |

The rounded button outline starts at file `0x53A2F` / `C688:D1AF`. The record
declares 36 visible bits per row, which still requires 5 source bytes per row.
Rendering all 5 bytes shows the full 40-bit stored row:

```sh
tools/rom2.py bitmap --base 0x53a2f --row-bytes 5 --height 34
```

The two small 24x7 records immediately after the outline are embedded button
labels/icons:

```sh
tools/rom2.py bitmap --base 0x53ad9 --row-bytes 3 --height 7 --columns 24
tools/rom2.py bitmap --base 0x53aee --row-bytes 3 --height 7 --columns 24
```

## Word Processor Page/Line/Column Status Label

The whole-ROM `FF 42` scan without `--require-position` finds a real 12x24
bitmap record at file `0x50B5F`, pointing to source file `0x5072B`:

```text
record=0x50B5F source=C688:9EAB file=0x5072B size=12x24 row_bytes=2 bytes=0x30
```

It renders as the very thin stacked labels `Pag`, `Lin`, and `Col`:

```sh
tools/rom2.py bitmap --base 0x5072b --row-bytes 2 --height 24 --columns 12
```

This is used by the word processor status display in the top-left corner of the
LCD.

## Horizontal Menu Icon Tables

The word-processor and organizer menus use compact icon/label tables, not
`FF 42` source-backed bitmap records. Each table starts with a six-byte header,
then a word item count, then one far pointer per icon, followed by fixed-width
label strings.

Word-processor top menu table:

```text
file 0x6FA78 / EE59:14E8
00 00 00 00 00 00      header
06 00                  item count
0A 00 59 EE            icon 0 -> file 0x6E59A / EE59:000A
9A 01 59 EE            icon 1 -> file 0x6E72A / EE59:019A
62 02 59 EE            icon 2 -> file 0x6E7F2 / EE59:0262
D2 00 59 EE            icon 3 -> file 0x6E662 / EE59:00D2
6A 09 59 EE            icon 4 -> file 0x6EEFA / EE59:096A
1A 0E 59 EE            icon 5 -> file 0x6F3AA / EE59:0E1A
file 0x6FA98           labels: EDIT TEXT, FILE, CLEAR TEXT, PRINTER, COMMUNICATE, OTHERS
```

The top-level word-processor pointers render as confirmed menu-matching 40x40
icons at 5 bytes per row:

```sh
tools/rom2.py bitmap --base 0x6e59a --row-bytes 5 --height 40 --columns 40
tools/rom2.py bitmap --base 0x6e72a --row-bytes 5 --height 40 --columns 40
tools/rom2.py bitmap --base 0x6e7f2 --row-bytes 5 --height 40 --columns 40
tools/rom2.py bitmap --base 0x6e662 --row-bytes 5 --height 40 --columns 40
tools/rom2.py bitmap --base 0x6eefa --row-bytes 5 --height 40 --columns 40
tools/rom2.py bitmap --base 0x6f3aa --row-bytes 5 --height 40 --columns 40
```

The far-pointer-to-file conversion here is normal segmented addressing through
the mapped ROM window; for example `EE59:096A` maps to file `0x6EEFA`.

Organizer top menu table:

```text
file 0x708BC / F04D:03EC
00 00                  header tail; four preceding bytes at 0x708B8 are FF FF FF FC
05 00                  item count
04 00 4D F0            icon 0 -> file 0x704D4 / F04D:0004
CC 00 4D F0            icon 1 -> file 0x7059C / F04D:00CC
94 01 4D F0            icon 2 -> file 0x70664 / F04D:0194
5C 02 4D F0            icon 3 -> file 0x7072C / F04D:025C
24 03 4D F0            icon 4 -> file 0x707F4 / F04D:0324
file 0x708D8           labels: CALCULATOR, CALENDAR, SCHEDULER, WORLD CLOCK, ADDRESS BOOK
```

The organizer icon run is confirmed to match the manual's organizer menu. The
first organizer icon at `0x704D4` is the calculator icon. Render the full run
with:

```sh
tools/rom2.py bitmap --base 0x704d4 --row-bytes 5 --height 40 --columns 40 --count 5 --stride 0xc8
```

The word-processor `COMMUNICATE` submenu table at file `0x6FBC8` has six entries:

```text
file 0x6FBC8 / EE59:1638
00 00 01 00 01 00      header
06 00                  item count
32 0A 59 EE            icon 0 -> file 0x6EFC2 / EE59:0A32 (SEND FILE)
E2 0E 59 EE            icon 1 -> file 0x6F472 / EE59:0EE2 (SEND FILE, XMODEM)
FA 0A 59 EE            icon 2 -> file 0x6F08A / EE59:0AFA (RECEIVE FILE)
AA 0F 59 EE            icon 3 -> file 0x6F53A / EE59:0FAA (RECEIVE FILE, XMODEM)
C2 0B 59 EE            icon 4 -> file 0x6F152 / EE59:0BC2 (TERMINAL)
A2 08 59 EE            icon 5 -> file 0x6EE32 / EE59:08A2 (SET UP)
file 0x6FBE8           labels: SEND FILE, SEND FILE, RECEIVE FILE, RECEIVE FILE, TERMINAL, SET UP
```

All six entries match the manual's communicate menu icon order. Render them with:

```sh
tools/rom2.py bitmap --base 0x6efc2 --row-bytes 5 --height 40 --columns 40
tools/rom2.py bitmap --base 0x6f472 --row-bytes 5 --height 40 --columns 40
tools/rom2.py bitmap --base 0x6f08a --row-bytes 5 --height 40 --columns 40
tools/rom2.py bitmap --base 0x6f53a --row-bytes 5 --height 40 --columns 40
tools/rom2.py bitmap --base 0x6f152 --row-bytes 5 --height 40 --columns 40
tools/rom2.py bitmap --base 0x6ee32 --row-bytes 5 --height 40 --columns 40
```

The table-to-drawing consumer is not fully named yet. Current evidence points to
the menu/resource setup path through `C688:7689` and `C688:9541`, with the
horizontal selection/list layer using helpers around `C688:721D`, `C688:722F`,
and `C688:72E5`. The icon table far pointers themselves are not referenced as
literal constants elsewhere in the ROM, so they are probably reached through a
resource/table indirection.

## Other Positioned 0x4x Drawing Records

The `0x4x` resource handler dispatch at `C000:6609` uses a byte-indexed table,
so even opcodes select the real handlers:

| Opcode | Handler | Current interpretation |
| --- | --- | --- |
| `FF 40` | `C000:6627` | Set pixel/bitmap cursor position. |
| `FF 42` | `C000:6648` | Source-backed bitmap blit. |
| `FF 44` | `C000:675D` | Region/line/fill-style draw operation; exact fields still need decoding. |

The startup menu resource window only has `FF 40` followed immediately by
`FF 42`. Wider UI resource windows have many positioned text records followed by
`FF 44`, for example:

```sh
tools/rom2.py position-ops --start 0x6f000 --end 0x79000 --min-opcode 0x41 --max-opcode 0x44
```

Examples include calendar/address-book/tutorial screens, where `FF 44` appears
after strings such as `DELETE`, `Deletes this entry.`, `SALUTATION`, `SEARCH`,
and tutorial prompts. That pattern looks like framed-region or line drawing
rather than bitmap source blitting.

## Candidate Status/Icon Resource Cluster

The area around file `0x55110` / physical `0xD5110` sits inside the main
application string/resource region, near status-line text:

```text
0x552AD: OFF   CHA  LIN      CAPS SHIFTCAPS
0x5530C: CODE
0x55312: PRNT
0x55318: FULL
0x5531E: HYPH
0x55324: FRM
0x5532A: INS
0x55330: ins
0x55336: BLOK
0x5533C: ZOOM
0x55342: MARK
0x55348: REPL
```

The bytes before those strings contain repeated high values such as `F1`, `F3`,
`F7`, and `FD`, plus compact sequences that render with repeated single- and
double-row horizontal line patterns if treated as raw 1bpp blocks. That makes
this a plausible UI/status/icon resource area, but it is not yet confirmed as a
simple fixed-size bitmap stream.

Useful exploratory renderings:

```sh
tools/rom2.py bitmap --base 0x55110 --row-bytes 2 --height 8 --count 24
tools/rom2.py bitmap --base 0x55110 --row-bytes 2 --height 16 --count 12
tools/rom2.py bitmap --base 0x551c0 --row-bytes 1 --height 16 --count 16
```

Keep the dimensions and encoding marked as tentative. The repeated `F1/F3/FD`
values could be glyph/tile/control codes rather than literal pixels, so the
next useful trace is to find the consumer that references this resource cluster.
