# Word-Processor Submenus

This slice expands the horizontal word-processor submenus selected from
[`top-icon-menus.md`](top-icon-menus.md). It follows the submenu wrappers and
maps nested submenus, but intentionally stops at the actual application handlers
such as document operations, printer output, and terminal. COMMUNICATE handlers
are expanded in [`wp-communicate-handlers.md`](wp-communicate-handlers.md),
setup editors are expanded in [`setup-screens.md`](setup-screens.md), and the
ROM-card loader is expanded in [`wp-others-handlers.md`](wp-others-handlers.md).

The shared renderer/key loop is documented in
[`horizontal-icon-renderer.md`](horizontal-icon-renderer.md). All icon assets
shown here are 40x40, one bit per pixel, five bytes per row.

String labels are fixed-width 13-byte table fields. The descriptor form is
shown for each table, followed by the final rendered label sequence.

## FILE Submenu

`DC98:275A` renders the six-item `FILE` submenu from effective table base
`0x6FAEC`, then dispatches on returned ASCII digit keys.

```asm
wp_file_submenu_DC98_275A:
; file 0x5F0DA
DC98:275A  51                push cx
DC98:275B  33 C9             xor  cx,cx
DC98:275D  B8 0C 00          mov  ax,0x000c
DC98:2760  BB AE EF          mov  bx,0xefae
DC98:2763  9A 4C 12 98 DC    call DC98:124C
...
DC98:276D  9A 2E EB 88 C6    call C688:EB2E
...
DC98:278D  9A D9 EB 88 C6    call C688:EBD9
...
DC98:27A3  9A A9 EB 88 C6    call C688:EBA9
...
DC98:27B9  9A C1 EB 88 C6    call C688:EBC1
...
DC98:27CF  E8 8D 1D          call DC98:455F
...
DC98:27E4  9A 91 EB 88 C6    call C688:EB91
DC98:2806  C3                ret
```

Return map:

| Key | Label | Handler boundary | Wrapper behavior |
| ---: | --- | --- | --- |
| `1` | `RECALL` | `C688:EB2E` | Returns to caller when handler returns `0xDA`, `0x0D`, or `0x0B`; otherwise redraws with item 0 selected. |
| `2` | `STORE` | `C688:EBD9` | Returns only on `0x0B`; otherwise redraws with item 1 selected. |
| `3` | `DELETE` | `C688:EBA9` | Returns only on `0x0B`; otherwise redraws with item 2 selected. |
| `4` | `RENAME` | `C688:EBC1` | Returns only on `0x0B`; otherwise redraws with item 3 selected. |
| `5` | `COPY` | `DC98:455F` | Returns only on `0x0B`; otherwise redraws with item 4 selected. |
| `6` | `INITIALIZE` | `C688:EB91` | Returns only on `0x0B`; otherwise redraws with item 5 selected. |
| `0x0B`, `0x03` | cancel/exit | none | Returns to the WP top menu. |

Descriptor:

```text
file 0x6FAEC:
u16 mode = 1
u16 item_count = 6
far icon[0] = EE59:04BA -> file 0x6EA4A
far icon[1] = EE59:03F2 -> file 0x6E982
far icon[2] = EE59:0582 -> file 0x6EB12
far icon[3] = EE59:064A -> file 0x6EBDA
far icon[4] = EE59:0C8A -> file 0x6F21A
far icon[5] = EE59:0D52 -> file 0x6F2E2
char[13] labels at file 0x6FB08
u16 optional_key_0x0B = 1
u16 optional_key_0x02 = 0
u16 optional_key_0x03 = 1
```

| Table entry | Rendered icon |
| --- | --- |
| `file 0x6FAF0`: `EE59:04BA` -> file `0x6EA4A`, label `RECALL`. | ![RECALL icon](images/wp-file-recall-0x6ea4a.png) |
| `file 0x6FAF4`: `EE59:03F2` -> file `0x6E982`, label `STORE`. | ![STORE icon](images/wp-file-store-0x6e982.png) |
| `file 0x6FAF8`: `EE59:0582` -> file `0x6EB12`, label `DELETE`. | ![DELETE icon](images/wp-file-delete-0x6eb12.png) |
| `file 0x6FAFC`: `EE59:064A` -> file `0x6EBDA`, label `RENAME`. | ![RENAME icon](images/wp-file-rename-0x6ebda.png) |
| `file 0x6FB00`: `EE59:0C8A` -> file `0x6F21A`, label `COPY`. | ![COPY icon](images/wp-file-copy-0x6f21a.png) |
| `file 0x6FB04`: `EE59:0D52` -> file `0x6F2E2`, label `INITIALIZE`. | ![INITIALIZE icon](images/wp-file-initialize-0x6f2e2.png) |

Final fixed-field label text:

```text
RECALL        STORE         DELETE        RENAME        COPY          INITIALIZE
```

## PRINTER Submenu

`DC98:265D` renders the three-item `PRINTER` submenu from effective table base
`0x6FB5C`.

```asm
wp_printer_submenu_DC98_265D:
; file 0x5EFDD
DC98:265D  51                push cx
DC98:265E  33 C9             xor  cx,cx
DC98:2660  B8 0C 00          mov  ax,0x000c
DC98:2663  BB B5 EF          mov  bx,0xefb5
DC98:2666  9A 4C 12 98 DC    call DC98:124C
...
DC98:2670  9A 5E EB 88 C6    call C688:EB5E
...
DC98:2685  E8 53 FE          call DC98:24DB
...
DC98:2699  E8 05 FC          call DC98:22A1
DC98:26B7  C3                ret
```

Return map:

| Key | Label | Handler boundary | Wrapper behavior |
| ---: | --- | --- | --- |
| `1` | `PRINT OUT` | `C688:EB5E` | Returns only on `0x0B`; otherwise redraws with item 0 selected. |
| `2` | `SET UP 1` | `DC98:24DB` | Returns only on `0x0B`; otherwise redraws with item 1 selected. |
| `3` | `SET UP 2` | `DC98:22A1` | Returns only on `0x0B`; otherwise redraws with item 2 selected. |
| `0x0B`, `0x03` | cancel/exit | none | Returns to the WP top menu. |

Descriptor:

```text
file 0x6FB5C:
u16 mode = 1
u16 item_count = 3
far icon[0] = EE59:00D2 -> file 0x6E662
far icon[1] = EE59:07DA -> file 0x6ED6A
far icon[2] = EE59:08A2 -> file 0x6EE32
char[13] labels at file 0x6FB78
u16 optional_key_0x0B = 1
u16 optional_key_0x02 = 0
u16 optional_key_0x03 = 1
```

| Table entry | Rendered icon |
| --- | --- |
| `file 0x6FB60`: `EE59:00D2` -> file `0x6E662`, label `PRINT OUT`. | ![PRINT OUT icon](images/wp-printer-0x6e662.png) |
| `file 0x6FB64`: `EE59:07DA` -> file `0x6ED6A`, label `SET UP 1`. | ![SET UP 1 icon](images/wp-submenu-setup1-0x6ed6a.png) |
| `file 0x6FB68`: `EE59:08A2` -> file `0x6EE32`, label `SET UP 2`. | ![SET UP 2 icon](images/wp-submenu-setup2-0x6ee32.png) |

Final fixed-field label text:

```text
PRINT OUT     SET UP 1      SET UP 2
```

## COMMUNICATE Submenu

`DC98:26B8` renders the six-item `COMMUNICATE` submenu from effective table base
`0x6FBCC`.

```asm
wp_communicate_submenu_DC98_26B8:
; file 0x5F038
DC98:26B8  51                push cx
DC98:26B9  33 C9             xor  cx,cx
DC98:26BB  B8 0C 00          mov  ax,0x000c
DC98:26BE  BB BC EF          mov  bx,0xefbc
DC98:26C1  9A 4C 12 98 DC    call DC98:124C
...
DC98:26CB  9A 24 EC 88 C6    call C688:EC24
DC98:26E1  9A 3F EC 88 C6    call C688:EC3F
DC98:26F7  9A F1 EB 88 C6    call C688:EBF1
DC98:270D  9A 09 EC 88 C6    call C688:EC09
DC98:2723  9A 5A EC 88 C6    call C688:EC5A
DC98:2739  E8 65 FB          call DC98:22A1
DC98:2759  C3                ret
```

Return map:

| Key | Label | Handler boundary | Wrapper behavior |
| ---: | --- | --- | --- |
| `1` | `SEND FILE` | `C688:EC24` | Returns only on `0x0B`; otherwise redraws with item 0 selected. |
| `2` | `SEND FILE` | `C688:EC3F` | Returns only on `0x0B`; otherwise redraws with item 1 selected. |
| `3` | `RECEIVE FILE` | `C688:EBF1` | Returns only on `0x0B`; otherwise redraws with item 2 selected. |
| `4` | `RECEIVE FILE` | `C688:EC09` | Returns only on `0x0B`; otherwise redraws with item 3 selected. |
| `5` | `TERMINAL` | `C688:EC5A` | Returns only on `0x0B`; otherwise redraws with item 4 selected. |
| `6` | `SET UP` | `DC98:22A1` | Returns only on `0x0B`; otherwise redraws with item 5 selected. |
| `0x0B`, `0x03` | cancel/exit | none | Returns to the WP top menu. |

Descriptor:

```text
file 0x6FBCC:
u16 mode = 1
u16 item_count = 6
far icon[0] = EE59:0A32 -> file 0x6EFC2
far icon[1] = EE59:0EE2 -> file 0x6F472
far icon[2] = EE59:0AFA -> file 0x6F08A
far icon[3] = EE59:0FAA -> file 0x6F53A
far icon[4] = EE59:0BC2 -> file 0x6F152
far icon[5] = EE59:08A2 -> file 0x6EE32
char[13] labels at file 0x6FBE8
u16 optional_key_0x0B = 1
u16 optional_key_0x02 = 0
u16 optional_key_0x03 = 1
```

| Table entry | Rendered icon |
| --- | --- |
| `file 0x6FBD0`: `EE59:0A32` -> file `0x6EFC2`, label `SEND FILE`. | ![SEND FILE icon](images/wp-comm-send-file-1-0x6efc2.png) |
| `file 0x6FBD4`: `EE59:0EE2` -> file `0x6F472`, label `SEND FILE`. | ![SEND FILE icon](images/wp-comm-send-file-2-0x6f472.png) |
| `file 0x6FBD8`: `EE59:0AFA` -> file `0x6F08A`, label `RECEIVE FILE`. | ![RECEIVE FILE icon](images/wp-comm-receive-file-1-0x6f08a.png) |
| `file 0x6FBDC`: `EE59:0FAA` -> file `0x6F53A`, label `RECEIVE FILE`. | ![RECEIVE FILE icon](images/wp-comm-receive-file-2-0x6f53a.png) |
| `file 0x6FBE0`: `EE59:0BC2` -> file `0x6F152`, label `TERMINAL`. | ![TERMINAL icon](images/wp-comm-terminal-0x6f152.png) |
| `file 0x6FBE4`: `EE59:08A2` -> file `0x6EE32`, label `SET UP`. | ![SET UP icon](images/wp-submenu-setup2-0x6ee32.png) |

Final fixed-field label text:

```text
SEND FILE     SEND FILE     RECEIVE FILE RECEIVE FILE TERMINAL      SET UP
```

## OTHERS Submenu

`DC98:2D2B` renders the four-item `OTHERS` submenu from effective table base
`0x6F7AC`. The system/preferences screens are expanded in
[`setup-screens.md`](setup-screens.md), the `T I M E` entry boundary and
ROM-card loader are expanded in [`wp-others-handlers.md`](wp-others-handlers.md),
and the Typin' Time app states are expanded in [`typin-time.md`](typin-time.md).

```asm
wp_others_submenu_DC98_2D2B:
; file 0x5F6AB
DC98:2D2B  51                push cx
DC98:2D2C  33 C9             xor  cx,cx
DC98:2D2E  B8 0C 00          mov  ax,0x000c
DC98:2D31  BB 7A EF          mov  bx,0xef7a
DC98:2D34  9A 4C 12 98 DC    call DC98:124C
...
DC98:2D3E  E8 49 FB          call DC98:288A
DC98:2D51  E8 2F FD          call DC98:2A83
DC98:2D65  9A 00 00 BB EB    call EBBB:0000
DC98:2D7D  E8 F5 FD          call DC98:2B75
DC98:2D9B  C3                ret
```

Return map:

| Key | Label | Handler boundary | Wrapper behavior |
| ---: | --- | --- | --- |
| `1` | `SYSTEM` | `DC98:288A` | Returns only on `0x0B`; otherwise redraws with item 0 selected. |
| `2` | `PREFERENCES` | `DC98:2A83` | Returns only on `0x0B`; otherwise redraws with item 1 selected. |
| `3` | `T I M E` | `EBBB:0000` | Clears `AH`, returns only on `0x0B`; otherwise redraws with item 2 selected. |
| `4` | `ROM CARD` | `DC98:2B75` | Returns only on `0x0B`; otherwise redraws with item 3 selected. |
| `0x0B`, `0x03` | cancel/exit | none | Returns to the WP top menu. |

Descriptor:

```text
file 0x6F7AC:
u16 mode = 1
u16 item_count = 4
far icon[0] = EE59:07DA -> file 0x6ED6A
far icon[1] = EF60:0002 -> file 0x6F602
far icon[2] = EF6C:000A -> file 0x6F6CA
far icon[3] = EE59:0712 -> file 0x6ECA2
char[13] labels at file 0x6F7C8
u16 optional_key_0x0B = 1
u16 optional_key_0x02 = 0
u16 optional_key_0x03 = 1
```

| Table entry | Rendered icon |
| --- | --- |
| `file 0x6F7B0`: `EE59:07DA` -> file `0x6ED6A`, label `SYSTEM`. | ![SYSTEM icon](images/wp-submenu-setup1-0x6ed6a.png) |
| `file 0x6F7B4`: `EF60:0002` -> file `0x6F602`, label `PREFERENCES`. | ![PREFERENCES icon](images/wp-others-preferences-0x6f602.png) |
| `file 0x6F7B8`: `EF6C:000A` -> file `0x6F6CA`, label `T I M E`. | ![T I M E icon](images/wp-others-time-0x6f6ca.png) |
| `file 0x6F7BC`: `EE59:0712` -> file `0x6ECA2`, label `ROM CARD`. | ![ROM CARD icon](images/wp-others-rom-card-0x6eca2.png) |

Final fixed-field label text:

```text
SYSTEM        PREFERENCES   T I M E       ROM CARD
```

## Render Commands

The checked-in PNGs were generated with:

```sh
tools/render_rom_bitmap_png.py 0x6ea4a 40 40 docs/disassembly/images/wp-file-recall-0x6ea4a.png --row-bytes 5 --scale 3
tools/render_rom_bitmap_png.py 0x6e982 40 40 docs/disassembly/images/wp-file-store-0x6e982.png --row-bytes 5 --scale 3
tools/render_rom_bitmap_png.py 0x6eb12 40 40 docs/disassembly/images/wp-file-delete-0x6eb12.png --row-bytes 5 --scale 3
tools/render_rom_bitmap_png.py 0x6ebda 40 40 docs/disassembly/images/wp-file-rename-0x6ebda.png --row-bytes 5 --scale 3
tools/render_rom_bitmap_png.py 0x6f21a 40 40 docs/disassembly/images/wp-file-copy-0x6f21a.png --row-bytes 5 --scale 3
tools/render_rom_bitmap_png.py 0x6f2e2 40 40 docs/disassembly/images/wp-file-initialize-0x6f2e2.png --row-bytes 5 --scale 3
tools/render_rom_bitmap_png.py 0x6ed6a 40 40 docs/disassembly/images/wp-submenu-setup1-0x6ed6a.png --row-bytes 5 --scale 3
tools/render_rom_bitmap_png.py 0x6ee32 40 40 docs/disassembly/images/wp-submenu-setup2-0x6ee32.png --row-bytes 5 --scale 3
tools/render_rom_bitmap_png.py 0x6efc2 40 40 docs/disassembly/images/wp-comm-send-file-1-0x6efc2.png --row-bytes 5 --scale 3
tools/render_rom_bitmap_png.py 0x6f472 40 40 docs/disassembly/images/wp-comm-send-file-2-0x6f472.png --row-bytes 5 --scale 3
tools/render_rom_bitmap_png.py 0x6f08a 40 40 docs/disassembly/images/wp-comm-receive-file-1-0x6f08a.png --row-bytes 5 --scale 3
tools/render_rom_bitmap_png.py 0x6f53a 40 40 docs/disassembly/images/wp-comm-receive-file-2-0x6f53a.png --row-bytes 5 --scale 3
tools/render_rom_bitmap_png.py 0x6f152 40 40 docs/disassembly/images/wp-comm-terminal-0x6f152.png --row-bytes 5 --scale 3
tools/render_rom_bitmap_png.py 0x6f602 40 40 docs/disassembly/images/wp-others-preferences-0x6f602.png --row-bytes 5 --scale 3
tools/render_rom_bitmap_png.py 0x6f6ca 40 40 docs/disassembly/images/wp-others-time-0x6f6ca.png --row-bytes 5 --scale 3
tools/render_rom_bitmap_png.py 0x6eca2 40 40 docs/disassembly/images/wp-others-rom-card-0x6eca2.png --row-bytes 5 --scale 3
```

## Next Splits

| Root | Split | Reason |
| --- | --- | --- |
| `C688:EB5E` | wp-print-out.md | PRINTER -> PRINT OUT application handler; wrapper enters the `C688:AAA6` print flow. |
