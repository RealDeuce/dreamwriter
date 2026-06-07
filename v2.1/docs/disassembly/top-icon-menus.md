# Top Icon Menus

This slice continues from [`menu-entry.md`](menu-entry.md): the shared menu loop
can reach the word-processor top menu wrapper `DC98:2807`, while the organizer
route reaches `DC98:53C3`. Both wrappers call the shared horizontal icon menu
renderer `DC98:124C`.

Image assets in this slice are generated from the icon far pointers consumed by
`DC98:124C`.

String labels in this slice are fixed-width menu-table fields; see
[`display-resource-format.md`](display-resource-format.md).

## Word-Processor Wrapper

`C688:EB15` reaches this wrapper as the default word-processor top menu path.

```asm
wp_top_menu_DC98_2807:
; file 0x5F187
DC98:2807  51                push cx
DC98:2808  33 C9             xor  cx,cx
DC98:280A  C7 06 81 6D FFFF  mov  word [0x6d81],0xffff
DC98:2810  B8 0C 00          mov  ax,0x000c
DC98:2813  BB A7 EF          mov  bx,0xefa7
DC98:2816  9A 4C 12 98 DC    call DC98:124C
DC98:281B  C7 06 81 6D 0000  mov  word [0x6d81],0
```

The wrapper dispatches the returned key:

| Key | Target |
| ---: | --- |
| `1` | EDIT TEXT: return `AX=0` to the shared app/editor loop. |
| `2` | Call FILE submenu `DC98:275A`; select/enter returns `AX=0`. |
| `3` | Far-call `C688:EB46`. |
| `4` | Call PRINTER submenu `DC98:265D`. |
| `5` | Call COMMUNICATE submenu `DC98:26B8`. |
| `6` | Call OTHERS submenu `DC98:2D2B`. |
| `0x02` | Return `AX=0x00FF`. |
| Other | Redraw/re-enter the top menu. |

```asm
DC98:2821  3D 31 00          cmp  ax,0x31
DC98:2824  75 04             jnz  DC98:282A
DC98:2826  33 C0             xor  ax,ax
DC98:2828  EB 5B             jmp  DC98:2885
DC98:282A  3D 32 00          cmp  ax,0x32
DC98:282D  75 14             jnz  DC98:2843
DC98:282F  E8 28 FF          call DC98:275A
...
DC98:2848  9A 46 EB 88 C6    call C688:EB46
...
DC98:2857  E8 03 FE          call DC98:265D
...
DC98:2864  E8 51 FE          call DC98:26B8
...
DC98:2871  E8 B7 04          call DC98:2D2B
...
DC98:2885  59                pop  cx
DC98:2886  CB                retf
```

## Word-Processor Icon Table

The wrapper passes `AX:BX = EFA7:000C`, which resolves to effective table base
file `0x6FA7C`. `DC98:124C` reads six 40x40 icon far pointers and fixed-width
labels from that table.

Descriptor:

```text
file 0x6FA7C:
u16 mode = 0
u16 item_count = 6
6 * far_ptr16 icon_source
6 * char[13] nul_padded_label
```

| Table entry | Rendered icon |
| --- | --- |
| `file 0x6FA80`: `EE59:000A` -> file `0x6E59A`, label `EDIT TEXT`. | ![EDIT TEXT icon](images/wp-edit-text-0x6e59a.png) |
| `file 0x6FA84`: `EE59:019A` -> file `0x6E72A`, label `FILE`. | ![FILE icon](images/wp-file-0x6e72a.png) |
| `file 0x6FA88`: `EE59:0262` -> file `0x6E7F2`, label `CLEAR TEXT`. | ![CLEAR TEXT icon](images/wp-clear-text-0x6e7f2.png) |
| `file 0x6FA8C`: `EE59:00D2` -> file `0x6E662`, label `PRINTER`. | ![PRINTER icon](images/wp-printer-0x6e662.png) |
| `file 0x6FA90`: `EE59:096A` -> file `0x6EEFA`, label `COMMUNICATE`. | ![COMMUNICATE icon](images/wp-communicate-0x6eefa.png) |
| `file 0x6FA94`: `EE59:0E1A` -> file `0x6F3AA`, label `OTHERS`. | ![OTHERS icon](images/wp-others-0x6f3aa.png) |

Final fixed-field label text:

```text
EDIT TEXT     FILE          CLEAR TEXT    PRINTER       COMMUNICATE   OTHERS
```

## Organizer Wrapper

The first-menu organizer route reaches `DC98:53C3`. The wrapper optionally calls
`DC98:539E`, renders the five-item icon menu, stores the selected top-menu index
in `[82A6]`, and dispatches to the selected organizer app.

```asm
organizer_top_menu_DC98_53C3:
; file 0x61D43
DC98:53C3  51                push cx
DC98:53C4  80 3E 50 8A 4F    cmp  byte [0x8a50],0x4f
DC98:53C9  75 0E             jnz  DC98:53D9
DC98:53CB  80 3E 51 8A 39    cmp  byte [0x8a51],0x39
DC98:53D0  75 07             jnz  DC98:53D9
DC98:53D2  80 3E 52 8A 32    cmp  byte [0x8a52],0x32
DC98:53D7  74 05             jz   DC98:53DE
DC98:53D9  9A 9E 53 98 DC    call DC98:539E
DC98:53DE  C7 06 81 6D FFFF  mov  word [0x6d81],0xffff
DC98:53E4  B8 0C 00          mov  ax,0x000c
DC98:53E7  BB 8B F0          mov  bx,0xf08b
DC98:53EA  8B 0E A6 82       mov  cx,[0x82a6]
DC98:53EE  9A 4C 12 98 DC    call DC98:124C
DC98:53F3  8B C8             mov  cx,ax
DC98:53F5  C7 06 81 6D 0000  mov  word [0x6d81],0
```

| Key | Stored index | Target |
| ---: | ---: | --- |
| `1` | `0` | `DC98:6A38` calculator, expanded in [`organizer-calculator.md`](organizer-calculator.md). |
| `2` | `1` | `DC98:7284` calendar, expanded in [`organizer-calendar.md`](organizer-calendar.md). |
| `3` | `2` | `DC98:990D` scheduler, expanded in [`organizer-scheduler.md`](organizer-scheduler.md). |
| `4` | `3` | `DC98:B67C` world clock, expanded in [`organizer-world-clock.md`](organizer-world-clock.md). |
| `5` | `4` | `DC98:CF12` address book, expanded in [`organizer-address-book.md`](organizer-address-book.md). |

## Organizer Icon Table

The wrapper passes `AX:BX = F08B:000C`, effective table base file `0x708BC`.

Descriptor:

```text
file 0x708BC:
u16 mode = 0
u16 item_count = 5
5 * far_ptr16 icon_source
5 * char[13] nul_padded_label
```

| Table entry | Rendered icon |
| --- | --- |
| `file 0x708C0`: `F04D:0004` -> file `0x704D4`, label `CALCULATOR`. | ![CALCULATOR icon](images/org-calculator-0x704d4.png) |
| `file 0x708C4`: `F04D:00CC` -> file `0x7059C`, label `CALENDAR`. | ![CALENDAR icon](images/org-calendar-0x7059c.png) |
| `file 0x708C8`: `F04D:0194` -> file `0x70664`, label `SCHEDULER`. | ![SCHEDULER icon](images/org-scheduler-0x70664.png) |
| `file 0x708CC`: `F04D:025C` -> file `0x7072C`, label `WORLD CLOCK`. | ![WORLD CLOCK icon](images/org-world-clock-0x7072c.png) |
| `file 0x708D0`: `F04D:0324` -> file `0x707F4`, label `ADDRESS BOOK`. | ![ADDRESS BOOK icon](images/org-address-book-0x707f4.png) |

Final fixed-field label text:

```text
CALCULATOR    CALENDAR      SCHEDULER     WORLD CLOCK   ADDRESS BOOK
```

## Shared Renderer Boundary

`DC98:124C` is the common horizontal icon-menu renderer, expanded in
[`horizontal-icon-renderer.md`](horizontal-icon-renderer.md). It:

- reads the table mode and item count,
- computes the left edge and item spacing for a 480-pixel row,
- builds generated `FF 42 28 00 28 00` bitmap records from the table's icon far
  pointers,
- draws 13-byte labels at table offset `+0x1C`,
- calls `DC98:1198` for arrow, numeric shortcut, and select-key handling.

The word-processor top-menu `CLEAR TEXT` handler is expanded in
[`wp-clear-text.md`](wp-clear-text.md). The submenu wrappers are expanded in
[`wp-submenus.md`](wp-submenus.md), while handler bodies below those submenu
choices remain application-side boundaries.

## Render Commands

The checked-in PNGs were generated with:

```sh
tools/render_rom_bitmap_png.py 0x6e59a 40 40 docs/disassembly/images/wp-edit-text-0x6e59a.png --row-bytes 5 --scale 3
tools/render_rom_bitmap_png.py 0x6e72a 40 40 docs/disassembly/images/wp-file-0x6e72a.png --row-bytes 5 --scale 3
tools/render_rom_bitmap_png.py 0x6e7f2 40 40 docs/disassembly/images/wp-clear-text-0x6e7f2.png --row-bytes 5 --scale 3
tools/render_rom_bitmap_png.py 0x6e662 40 40 docs/disassembly/images/wp-printer-0x6e662.png --row-bytes 5 --scale 3
tools/render_rom_bitmap_png.py 0x6eefa 40 40 docs/disassembly/images/wp-communicate-0x6eefa.png --row-bytes 5 --scale 3
tools/render_rom_bitmap_png.py 0x6f3aa 40 40 docs/disassembly/images/wp-others-0x6f3aa.png --row-bytes 5 --scale 3
tools/render_rom_bitmap_png.py 0x704d4 40 40 docs/disassembly/images/org-calculator-0x704d4.png --row-bytes 5 --scale 3
tools/render_rom_bitmap_png.py 0x7059c 40 40 docs/disassembly/images/org-calendar-0x7059c.png --row-bytes 5 --scale 3
tools/render_rom_bitmap_png.py 0x70664 40 40 docs/disassembly/images/org-scheduler-0x70664.png --row-bytes 5 --scale 3
tools/render_rom_bitmap_png.py 0x7072c 40 40 docs/disassembly/images/org-world-clock-0x7072c.png --row-bytes 5 --scale 3
tools/render_rom_bitmap_png.py 0x707f4 40 40 docs/disassembly/images/org-address-book-0x707f4.png --row-bytes 5 --scale 3
```

## Next Splits

All five Organizer top-menu app roots selected by this wrapper now have named
disassembly slices. Remaining Organizer-adjacent work is in application-side
print/mail-merge readers rather than this top icon menu layer.
