# Horizontal Icon Renderer

This slice expands the shared horizontal icon-menu renderer reached from
[`top-icon-menus.md`](top-icon-menus.md) and reused by the word-processor
submenus in [`wp-submenus.md`](wp-submenus.md).

No fixed ROM bitmap is reached directly here. `DC98:124C` reads icon far
pointers from caller-supplied tables, builds `FF 42` bitmap records in scratch
RAM, and sends the generated stream through `C000:67AD`.

String labels in this slice are fixed-width fields inside the icon-menu tables;
see [`display-resource-format.md`](display-resource-format.md).

## Selection Marker

`DC98:110E` redraws the selected-item marker. The key loop calls it both before
blocking for input and when toggling the old/new item during arrow movement.

Inputs:

```text
AX = selected item index
BX = left x position for item 0
CX = item spacing
```

It builds one positioned rectangle/fill record at scratch buffer `72E5`:

```text
FF 44
word y      = 0x0033
word x      = BX + 2 + AX * CX
word height = 0x0009
word width  = 0x004C
word 0
word 0
byte mode   = 0x0A
```

The `0x0A` mode is the same XOR-style rectangle mode used elsewhere, which
fits the redraw behavior: calling the helper on an item toggles its marker.

```asm
selection_marker_DC98_110E:
; file 0x5DA8E
DC98:110E  55                push bp
...
DC98:1133  C7 07 33 00       mov  word [bx],0x0033
DC98:113B  F7 E1             mul  cx
DC98:113D  83 C6 02          add  si,0x0002
DC98:1140  03 F0             add  si,ax
DC98:1145  89 37             mov  [bx],si
...
DC98:1159  C7 07 4C 00       mov  word [bx],0x004c
...
DC98:117A  C6 07 0A          mov  byte [bx],0x0a
DC98:118C  9A AD 67 00 C0    call C000:67AD
DC98:1197  C3                ret
```

## Key Loop

`DC98:1198` is the horizontal-menu input loop.

Inputs from `DC98:124C`:

```text
AX = item count
BX = initially selected item index
CX = left x position for item 0
DX = item spacing
stack +4 = allow key 0x0B return
stack +6 = allow key 0x02 return
stack +8 = allow key 0x03 return
```

The loop saves the item count in `SI` and the selected index in `DI`. It sets
`[6811]=1` while blocked in the key-read wrapper `DC98:0CF9`, then clears it
after the key returns.

Return behavior:

| Input key | Return |
| ---: | --- |
| `0xDA` | Returns ASCII digit `selected_index + 0x31`. |
| ASCII digit `'1'..('0'+item_count)` | Returns that digit directly. |
| `0x0B` | Returns only when the table's first optional-key word is nonzero. |
| `0x02` | Returns only when the table's second optional-key word is nonzero. |
| `0x03` | Returns only when the table's third optional-key word is nonzero. |
| `0x11` | Moves selection left when `DI > 0`; redraws old and new markers. |
| `0x10` | Moves selection right when `DI < item_count - 1`; redraws old and new markers. |

```asm
horizontal_icon_key_loop_DC98_1198:
; file 0x5DB18
DC98:119E  8B F0             mov  si,ax
DC98:11A0  8B FB             mov  di,bx
DC98:11A9  E8 62 FF          call DC98:110E
DC98:11AD  C6 06 11 68 01    mov  byte [6811],1
DC98:11B2  9A F9 0C 98 DC    call DC98:0CF9
DC98:11B7  C6 06 11 68 00    mov  byte [6811],0
DC98:11BC  3D DA 00          cmp  ax,0x00da
DC98:11C1  83 C7 31          add  di,0x31
...
DC98:11C8  3D 31 00          cmp  ax,0x0031
DC98:11CD  BB 31 00          mov  bx,0x0031
DC98:11D0  03 DE             add  bx,si
...
DC98:1200  3D 11 00          cmp  ax,0x0011
...
DC98:1221  3D 10 00          cmp  ax,0x0010
...
DC98:1247  5F                pop  di
DC98:124B  C3                ret
```

## Renderer Entry

`DC98:124C` is a far-callable table renderer and selector.

Inputs:

```text
AX:BX = far pointer to the menu table
CX    = initially selected item index
```

Table descriptor at the effective base:

```text
+0x00  u16       clear/display mode; 1 and 2 call DC98:0EE5 first
+0x02  u16       item_count
+0x04  far[6]    icon source pointers
+0x1C  char[13]  fixed-width, nul-padded label for item 0
       char[13]  fixed-width, nul-padded label for item 1
       ...
+0x6A  u16       optional key 0x0B enable
+0x6C  u16       optional key 0x02 enable
+0x6E  u16       optional key 0x03 enable
```

The wrapper first calls `DC98:0E70`, sends a four-byte stream from `EE4F:000A`
through `C000:67AD`, then optionally fills a `480x64` region through
`DC98:0EE5` when the mode word is `1` or `2`.

Layout math:

```text
left    = 0x1B * (6 - item_count) + 7
spacing = ((0x1E0 - 2 * left - 0x4C * item_count) / (item_count - 1)) + 0x4C
```

That places `0x4C`-wide cells across the 480-pixel display, with each 40x40 icon
drawn at `cell_x + 0x14` and each numeric badge drawn near `cell_x + 5`.

```asm
horizontal_icon_renderer_DC98_124C:
; file 0x5DBCC
DC98:124C  55                push bp
...
DC98:1256  89 46 FC          mov  [bp-4],ax
DC98:1259  89 5E FE          mov  [bp-2],bx
DC98:125D  9A 70 0E 98 DC    call DC98:0E70
DC98:1262  B8 0A 00          mov  ax,0x000a
DC98:1265  BB 4F EE          mov  bx,0xee4f
DC98:1268  B9 04 00          mov  cx,0x0004
DC98:126B  9A AD 67 00 C0    call C000:67AD
...
DC98:12B1  26 8B 77 02       mov  si,[es:bx+0x02]
DC98:12B5  BB 06 00          mov  bx,0x0006
DC98:12B8  2B DE             sub  bx,si
DC98:12BA  B8 1B 00          mov  ax,0x001b
DC98:12BD  F7 E3             mul  bx
DC98:12C1  83 C7 07          add  di,0x0007
...
DC98:12D5  8B C2             mov  ax,dx
DC98:12D9  4B                dec  bx
DC98:12DB  F7 FB             idiv bx
DC98:12DD  05 4C 00          add  ax,0x004c
```

## Draw Passes

The renderer emits three separate draw passes.

Numeric badges:

```text
FF 02
word y = 0x0003
word x = cell_x + 5
FF 42
word height = 0x000D
word width  = 0x0009
far source  = EE4F:(0x000E + item_index * 0x1A)
```

Icons:

```text
FF 02
word y = 0x0002
word x = cell_x + 0x14
FF 42
word height = 0x0028
word width  = 0x0028
far source  = table.icon_source[item_index]
```

Labels:

```text
source = table + 0x1C + item_index * 13
width  = DC98:10EC(source) * 3
x      = cell_x + 0x24 - width
y      = 0x34
draw   = DC98:0E81(source, x, y)
```

The `* 3` adjustment is an observed centering scale used by this renderer. The
label fields are fixed 13-byte descriptors, but `DC98:10EC` measures the
visible text before positioning.

```asm
DC98:13D5  C4 5E FC          les  bx,[bp-4]
DC98:13D8  83 C3 04          add  bx,0x0004
DC98:13DD  D1 E0             shl  ax,1
DC98:13DF  D1 E0             shl  ax,1
DC98:13E3  26 8B 07          mov  ax,[es:bx]
DC98:13E6  26 8B 57 02       mov  dx,[es:bx+0x02]
...
DC98:141D  BB 0D 00          mov  bx,0x000d
DC98:1428  83 C2 1C          add  dx,0x001c
DC98:1448  E8 A1 FC          call DC98:10EC
DC98:144B  B9 03 00          mov  cx,0x0003
DC98:144E  F7 E1             mul  cx
DC98:1456  BA 34 00          mov  dx,0x0034
DC98:145B  9A 81 0E 98 DC    call DC98:0E81
```

## Tail Call

After drawing the static bar, the renderer pushes three optional-key enable
words from the table tail and calls the near key loop:

```asm
DC98:146A  C4 5E FC          les  bx,[bp-4]
DC98:146E  26 FF 77 6E       push word [es:bx+0x6e]
DC98:1475  26 FF 77 6C       push word [es:bx+0x6c]
DC98:147C  26 FF 77 6A       push word [es:bx+0x6a]
DC98:1480  8B C6             mov  ax,si
DC98:1482  8B D9             mov  bx,cx
DC98:1484  8B CF             mov  cx,di
DC98:1486  8B 56 FA          mov  dx,[bp-6]
DC98:1489  E8 0C FD          call DC98:1198
DC98:148C  83 C4 06          add  sp,0x0006
DC98:1496  CB                retf
```

Confirmed callers:

| Call site | Table pointer | Effective file base | Current read |
| --- | --- | ---: | --- |
| `DC98:2660` | `EFB5:000C` | `0x6FB5C` | WP `PRINTER` submenu. |
| `DC98:26BB` | `EFBC:000C` | `0x6FBCC` | WP `COMMUNICATE` submenu. |
| `DC98:275D` | `EFAE:000C` | `0x6FAEC` | WP `FILE` submenu. |
| `DC98:2810` | `EFA7:000C` | `0x6FA7C` | WP top menu. |
| `DC98:2D2E` | `EF7A:000C` | `0x6F7AC` | WP `OTHERS` submenu. |
| `DC98:53E4` | `F08B:000C` | `0x708BC` | Organizer top menu. |
