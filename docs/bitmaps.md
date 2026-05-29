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

The display path is now identified. `C000:4C91` polls warning slots in `[6D52]`,
`C000:4C6E` saves the 48x40 screen area, and `C000:4D07` draws
`C000:4D30 + index * 0xF0` into framebuffer address `0x131B`. The slot-to-icon
mapping is:

| Slot | Poll helper | Icon index | Input condition |
| ---: | --- | ---: | --- |
| `2` | `C000:0A93` | `0` | Port `0xA0` bit `0x08` set. |
| `3` | `C000:0AA4` | `1` | Port `0xA0` bit `0x04` set. |
| `4` | `C000:0AB2` | `2` | Port `0xA0` bit `0x80` clear and bit `0x10` clear. |

## Dispatcher Table After Error Icons

The next `0xF0`-aligned location, file `0x45000` / `C000:5000`, is not a fourth
48x40 icon. It is a translation table followed by handler pointers and an
interrupt-style dispatcher.

The first table maps `AH` values below `0x60` to compact handler indices:

```text
file 0x45000 / C000:5000: 96-byte byte translation table
file 0x45060 / C000:5060: word handler table
file 0x45098 / C000:5098: dispatcher prologue
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
literal `FF 42` source-backed bitmap records in ROM. `DC98:124C` builds those
records at runtime from the table's far icon pointers, then sends the generated
stream through `C000:67AD`.

The renderer's effective table base is sometimes four bytes after the start of a
nearby data cluster. From the effective base:

```text
+0x00 word  clear/display mode
+0x02 word  item count
+0x04       six far icon pointer slots, 4 bytes each
+0x1C       fixed-width label text, 13 bytes per item
+0x6A       optional key bindings for the key loop
```

Word-processor top menu table:

```text
file 0x6FA78            surrounding cluster start
file 0x6FA7C / EE59:14EC effective table base used by DC98:124C
00 00                  clear/display mode
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
00 00                  clear/display mode; four preceding bytes at 0x708B8 are FF FF FF FC
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

## Calculator Display Resources

The Organizer -> CALCULATOR screen starts at `DC98:6A38` / file `0x633B8`.
Its numeric display redraw helpers (`DC98:54C2` and `DC98:583E`) build inline
`FF 42` bitmap records from the large 8x12 digit resource at
`F16C:000A` / file `0x716CA`. This is the same resource family used by WORLD
CLOCK for its large time readouts, but the calculator also uses the later
punctuation/blank entries selected through `[8648]` and `[8649]`.

Render the resource family with:

```sh
tools/rom2.py bitmap --base 0x716ca --row-bytes 1 --height 12 --columns 8 --count 14 --stride 0xd
tools/rom2.py bitmap --base 0x71766 --row-bytes 1 --height 12 --columns 8 --count 3 --stride 0xd
```

The calculator-specific resource cluster begins earlier:

| Source | Segment | Size | Notes |
| ---: | --- | --- | --- |
| `0x70948` | `F094:0008` | Four fixed 24-byte strings | `OVERFLOW`, `DIVISION BY ZERO`, `OUT OF RANGE`, and `UNKNOWN ERROR`. |
| `0x709B0` | `F09B:0000` | Four 8x8 glyphs | Small operator/status-looking glyphs adjacent to the calculator scripts. |
| `0x709D8` | `F09D:0008` | Display script | Right-side panel rules/areas, including six `FF 44` rectangle records and low-number `FF 02`/`FF 06` records. |

Render the adjacent 8x8 glyphs with:

```sh
tools/rom2.py bitmap --base 0x709b0 --row-bytes 1 --height 8 --columns 8 --count 4 --stride 0x8
```

The 4x7 digit run at `F0A6:000C` / file `0x70A6C` follows the calculator
panel script, but the current direct code reference is from later organizer
date/calendar-style rendering code around `DC98:6CDD`, not from the calculator
main loop. Keep it separate from the calculator display font until a calculator
caller is found.

```sh
tools/rom2.py bitmap --base 0x70a6c --row-bytes 1 --height 7 --columns 4 --count 10 --stride 0x7
```

## WORLD CLOCK Map And Header Resources

The Organizer -> WORLD CLOCK screen uses both source-backed bitmaps and stored
display scripts.

`DC98:A0CC` builds an `FF 42` record for the large map bitmap:

| Source | Segment | Size | Render command |
| ---: | --- | --- | --- |
| `0x713CA` | `F13C:000A` | `96x64`, 12 bytes per row | `tools/rom2.py bitmap --base 0x713ca --row-bytes 12 --height 64 --columns 96` |

The small city-marker glyphs live at `F138:0000` / file `0x71380`. WORLD CLOCK
uses the variants at offsets `0x000E` and `0x0014` for the map markers, and the
main loop toggles between those two sources for the selected city's blink.

The two current-time readouts are also bitmap-rendered, not normal text.
`DC98:A06C` updates/redraws the two displayed clocks and calls `DC98:9AC8` for
each one. `DC98:9AC8` builds an inline script that emits `FF 42` records from a
large digit resource:

| Source | Segment | Size | Notes |
| ---: | --- | --- | --- |
| `0x716CA` | `F16C:000A` | `7x12`, 1 byte per row, stride `0x0D` | Digits `0..9`. |
| `0x7174C` | `F16C:008C` | `4x12`, 1 byte per row | Time separator/colon. |
| `0x71759` | `F16C:0099` | `7x12`, 1 byte per row | Blank leading-hour glyph. |

Render the large digits with:

```sh
tools/rom2.py bitmap --base 0x716ca --row-bytes 1 --height 12 --columns 8 --count 10 --stride 0xd
tools/rom2.py bitmap --base 0x7174c --row-bytes 1 --height 12 --columns 8
tools/rom2.py bitmap --base 0x71759 --row-bytes 1 --height 12 --columns 8
```

This matches the screen behavior: the time digits look heavier than the normal
6x8 text font, and the separator is proportional because it is a narrower
bitmap resource. The script inserts `E1` style/control bytes between the digit
bitmap records; the exact visual role of that control byte in this mixed
bitmap/text stream still needs confirmation.

The right-side `WORLD CLOCK` header is not a bitmap. `DC98:B67C` sends a
`0x5A`-byte script from `F104:000C` / file `0x7104C` before drawing the title
text. That script is six 15-byte `FF 44` records:

```text
file 0x7104C  FF44 y=0 x=366 h=64 w=114 mode=0x00
file 0x7105B  FF44 y=0 x=366 h=1  w=114 mode=0x0F
file 0x7106A  FF44 y=2 x=366 h=1  w=114 mode=0x0F
file 0x71079  FF44 y=4 x=366 h=1  w=114 mode=0x0F
file 0x71088  FF44 y=6 x=366 h=1  w=114 mode=0x0F
file 0x71097  FF44 y=8 x=366 h=1  w=114 mode=0x0F
```

The rectangle form is now confirmed from the `C000:675D` handler. For records
where the words at `+9` and `+0B` are zero, the layout is:

```text
FF 44
+1  word  y
+3  word  x
+5  word  height
+7  word  width
+9  word  0
+B  word  0
+D  byte  mode: 0 clears, 0x0A XORs, other nonzero values set pixels
```

The values fit the visible layout: a 114-pixel-wide right-side strip on a
480-pixel-wide display, followed by five horizontal rules separated by one blank
scanline. The next script at
`F10D:000E` / file `0x710DE` draws the `WORLD CLOCK` title and menu text on top
of those rules, which explains why the top rules appear broken around the title
even though the stored `FF44` records are continuous.

The word-processor `FILE` submenu is reached at effective base `0x6FAEC`:

```text
file 0x6FAE8            surrounding cluster start
file 0x6FAEC / EE59:155C effective table base used by DC98:124C
01 00                  clear/display mode
06 00                  item count
BA 04 59 EE            icon 0 -> file 0x6EA4A / EE59:04BA (RECALL)
F2 03 59 EE            icon 1 -> file 0x6E982 / EE59:03F2 (STORE)
82 05 59 EE            icon 2 -> file 0x6EB12 / EE59:0582 (DELETE)
4A 06 59 EE            icon 3 -> file 0x6EBDA / EE59:064A (RENAME)
8A 0C 59 EE            icon 4 -> file 0x6F21A / EE59:0C8A (COPY)
52 0D 59 EE            icon 5 -> file 0x6F2E2 / EE59:0D52 (INITIALIZE)
file 0x6FB08           labels: RECALL, STORE, DELETE, RENAME, COPY, INITIALIZE
```

The word-processor `PRINTER` submenu is reached at effective base `0x6FB5C`:

```text
file 0x6FB58            surrounding cluster start
file 0x6FB5C / EE59:15CC effective table base used by DC98:124C
01 00                  clear/display mode
03 00                  item count
D2 00 59 EE            icon 0 -> file 0x6E662 / EE59:00D2 (PRINT OUT)
DA 07 59 EE            icon 1 -> file 0x6ED6A / EE59:07DA (SET UP 1)
A2 08 59 EE            icon 2 -> file 0x6EE32 / EE59:08A2 (SET UP 2)
file 0x6FB78           labels: PRINT OUT, SET UP 1, SET UP 2
```

The word-processor `COMMUNICATE` submenu table at file `0x6FBC8` has six entries:

```text
file 0x6FBC8            surrounding cluster start
file 0x6FBCC / EE59:163C effective table base used by DC98:124C
01 00                  clear/display mode
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

The word-processor `OTHERS` submenu is reached by the same renderer at effective
base `0x6F7AC`:

```text
file 0x6F7A0            preceding string/data includes "EROMCARD.X"
file 0x6F7AC / EE59:121C effective table base used by DC98:124C
01 00                  clear/display mode
04 00                  item count
DA 07 59 EE            icon 0 -> file 0x6ED6A / EE59:07DA (SYSTEM)
02 00 60 EF            icon 1 -> file 0x6F602 / EF60:0002 (PREFERENCES)
0A 00 6C EF            icon 2 -> file 0x6F6CA / EF6C:000A (T I M E)
12 07 59 EE            icon 3 -> file 0x6ECA2 / EE59:0712 (ROM CARD)
file 0x6F7C8           labels: SYSTEM, PREFERENCES, T I M E, ROM CARD
```

`ROM CARD` is the executable/software-card path for the PCMCIA slot. Its handler
at `DC98:2B75` searches candidate card drives for `EROMCARD.X`, loads it to
`0xA4F0`, validates header words `0xA4F0/0x1997`, and calls the far entry
pointer at `[0xA4F4]`. This is distinct from the WP `FILE` submenu, which is for
working with PCMCIA SRAM storage cards.

Render the four `OTHERS` icons with:

```sh
tools/rom2.py bitmap --base 0x6ed6a --row-bytes 5 --height 40 --columns 40
tools/rom2.py bitmap --base 0x6f602 --row-bytes 5 --height 40 --columns 40
tools/rom2.py bitmap --base 0x6f6ca --row-bytes 5 --height 40 --columns 40
tools/rom2.py bitmap --base 0x6eca2 --row-bytes 5 --height 40 --columns 40
```

`DC98:124C` is now the named table-to-drawing consumer for these icon menus. The
separate `C688:71A4`/`71B5` -> `C688:721D` -> `C688:9461` path is a
resource/list drawing layer that uses the `C688:9541(AL=5)` static-resource
cache and local text/list helpers, rather than this compact 40x40 icon table
format.

## Other Positioned 0x4x Drawing Records

`FF` is an escape into a second display sub-opcode dispatch. Low-number
sub-opcodes such as `FF 04` and `FF 06` are separate text/cursor/window helpers
handled through the table at `C000:5F0B`. Sub-opcodes `FF 40..44` branch to
`C000:6609`, which uses another byte-indexed table. The currently confirmed
positioned drawing entries are the even opcodes:

| Opcode | Handler | Current interpretation |
| --- | --- | --- |
| `FF 40` | `C000:6627` | Set pixel/bitmap cursor position. |
| `FF 42` | `C000:6648` | Source-backed bitmap blit. |
| `FF 44` | `C000:675D` | Positioned rectangle/fill operation; the simple form is decoded, while copy/shift forms still need naming. |

The byte-indexed `0x4x` table would send `FF 41` and `FF 43` to overlapping
words in the table bytes; no confirmed resource uses those odd sub-opcodes yet.

The startup menu resource window only has `FF 40` followed immediately by
`FF 42`. Wider UI resource windows have many positioned text records followed by
`FF 44`, for example:

```sh
tools/rom2.py position-ops --start 0x6f000 --end 0x79000 --min-opcode 0x41 --max-opcode 0x44
```

Examples include calendar/address-book/tutorial screens, where `FF 44` appears
after strings such as `DELETE`, `Deletes this entry.`, `SALUTATION`, `SEARCH`,
and tutorial prompts. That pattern looks like framed-region or line drawing
rather than bitmap source blitting. The WORLD CLOCK header resource at
`0x7104C` is now a concrete `FF44` rectangle example: it clears a right-side
strip and sets five horizontal rules before the title text is overlaid.

The non-rectangle `FF44` forms still need naming. In `C000:675D`, nonzero
fields at `+9` or `+0B` dispatch to helpers at `C000:644D` or `C000:63C6`,
which look like in-framebuffer copy/shift operations rather than immediate
source-backed blits.

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
