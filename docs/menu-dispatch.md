# Menu Dispatch

This page tracks the application-level menu/event dispatch code reached after the
startup resource has drawn the first two-button screen.

## Inline Key Dispatch Primitive

`C688:92DF` / file `0x4FB5F` is a reusable inline key dispatch trampoline:

```asm
C688:92DF  call C688:EE8C
C688:92E2  mov  bp,sp
C688:92E4  xchg [bp+0],si
C688:92E7  push dx
C688:92E8  mov  dl,al
C688:92EA  mov  al,[cs:si]
C688:92ED  inc  si
C688:92EE  cmp  al,00
C688:92F0  jz   C688:9301
C688:92F2  cmp  al,FF
C688:92F4  jz   C688:92FE
C688:92F6  cmp  al,dl
C688:92F8  jz   C688:92FE
C688:92FA  inc  si
C688:92FB  inc  si
C688:92FC  jmp  C688:92EA
C688:92FE  mov  si,[cs:si]
C688:9301  pop  dx
C688:9302  mov  bp,sp
C688:9304  xchg [bp+0],si
C688:9307  mov  al,[794A]
C688:930A  ret
```

`C688:92DF` first calls `C688:EE8C`; `C688:92E2` is the same dispatcher body
without that pre-call. Callers embed byte/word entries immediately after the
call:

```text
key-byte target-word-le
...
00              ; terminator, continue after the 00 byte
FF target       ; default target
```

The routine rewrites the caller's return address so the `ret` lands at the
selected target.

## First Two-Button Screen

The first-screen post-input code reaches `C688:928D`, which calls `C688:92DF`
and embeds this table:

```text
13 -> C688:92C0
12 -> C688:92CC
DA -> C688:92CC
0B -> C688:92A7
03 -> C688:92A7
00 -> end
```

`C688:92A0` is an indirect jump through the current word pointer in `[75EF]`.
`C688:92C0` and `C688:92CC` move `[75EF]` backward or forward by one word-table
entry, wrapping at the zero terminator. This is the first confirmed cursor/list
navigation primitive.

## Shared Menu Event Loop

`C688:EC9F` / file `0x5551F` is the shared application menu/event loop reached
after the first-screen branch setup:

```asm
C688:EC9F  call C688:77DD
C688:ECA2  mov  al,FF
C688:ECA4  mov  [75E4],al
C688:ECA7  call C688:7795
C688:ECAA  call C688:F13A
C688:ECAD  call C688:8F40
C688:ECB0  call C688:12D6
C688:ECB3  mov  [794A],al
C688:ECB6  call C688:44C4
C688:ECB9  mov  al,[794A]
C688:ECBC  cmp  al,FF
C688:ECBE  jnz  C688:ECC3
C688:ECC0  jmp  C688:ED84
C688:ECC3  call C688:92DF
```

The inline table after `C688:ECC3` starts at file `0x55546` / `C688:ECC6`:

```text
01 -> C688:ECA7
02 -> C688:EF4F
E8 -> C688:EF59
0B -> C688:ECF6
0A -> C688:8319
1D -> C688:8CFB
1B -> C688:8D23
1C -> C688:8D0F
F6 -> C688:ED1F
EA -> C688:ED15
D2 -> C688:AD5C
F7 -> C688:D8AF
F5 -> C688:ED1A
F8 -> C688:E274   ; observed editor Alt+8 / Thesaurus path
03 -> C688:ECF6
FF -> C688:EB15
```

The working key/event values are not fully named yet. The table does show that
the first menu loop is no longer a black box: ordinary events go through a fixed
dispatch table, while `0xFF` no-event/idle goes to `C688:ED84`.

## Handler Anchors

Some targets are already useful anchors:

| Target | File offset | Current read |
| --- | ---: | --- |
| `C688:EB15` | `0x55395` | Default handler. Calls `C688:77AA`, clears `[7520]`, far-calls `DC98:2807`, then loops or jumps through `C688:EF45`. |
| `C688:ECF6` | `0x55576` | Handles `0x0B` and `0x03`. Toggles/tests `[8E3F]`, otherwise calls `C688:622B`, `C688:0B11`, `C688:44C4`, and `C688:77A3`. |
| `C688:ED84` | `0x55604` | Idle/no-event state dispatch keyed by `[79A6]` through `C688:92E2`. |
| `C688:EF4F` | `0x557CF` | Far-calls `DC98:53C3`, then returns to `C688:EC9F`. |
| `C688:EF59` | `0x557D9` | Far-calls `DC98:4D08`; if the result is not `FFFF`, stores `AL` to `[7884]`. |
| `C688:AD5C` | `0x515DC` | Opens `H:ADDRESS.ODB`, reads records, and prints/steps through address-book data. Strong organizer/address-book anchor. |
| `C688:D8AF` | `0x5412F` | Large file/document-style flow with nested `C688:92DF` table. |
| `C688:E274` | `0x54AF4` | Editor Thesaurus entry. Calls `C688:E282`, draws resource `0x76`, then enters the Thesaurus list/meaning loop at `C688:E2EA`. See [`spell-engine.md`](spell-engine.md#editor-thesaurus-front-end). |

`C688:ED84` embeds another table after `C688:ED87 call C688:92E2`, keyed by
`[79A6]`:

```text
60 -> C688:ED9C
62 -> C688:EDE8
66 -> C688:EE34
6C -> C688:EE2F
64 -> C688:EDBC
FF -> C688:EDE8
```

## Local Selection Prompts

`C688:8D0F` and `C688:8D23` set `[757D]` to their own address, call
`C688:7689` with resource IDs `0x38` plus `0x19` or `0x37`, populate a 16-byte
buffer at `0x7A30`, and then enter a small inline dispatch:

```text
DA -> C688:8D86
03 -> C688:EC9F
FF -> [757D]
```

`C688:8D86` is a related branch using a second 16-byte buffer at `0x7A1F`:

```text
1D -> C688:8DBF
DA -> C688:8DC4
03 -> C688:EC9F
FF -> C688:8D8E
```

The exact menu meaning is still unnamed, but this is clearly part of the
horizontal menu/list selection machinery: it sets state flags in `[7520]`, calls
`C688:8F40`, updates UI state through `C688:44C4`, and returns to the shared
`C688:EC9F` loop.

## Screen Resource Selector

`C688:7689` is the setup wrapper used by the first confirmed ORGN branch:

```asm
C688:83EC  mov  si,0053
C688:83EF  call C688:7689
```

Inside `C688:7689`, `SI` survives as a screen/resource ID. The wrapper clears
`[799C]`, calls `C688:9541`, then updates state through `C688:2CFA`,
`C688:44C4`, and `C688:7795`.

`C688:9541` / file `0x4FDC1` is now the best concrete name for the screen
resource loader reached from menu code. When called with `AL=5`, it first checks
whether the requested `SI` matches the last cached `SI` in `[7574]`/`[7575]`:

```asm
C688:9541  cmp  al,05
C688:9543  jnz  C688:9561
C688:9545  push ax
C688:9546  mov  al,[7574]
C688:9549  mov  bx,si
C688:954B  xor  al,bl
C688:954F  jnz  C688:955C
C688:9551  mov  al,[7575]
C688:9554  xor  al,bh
C688:9558  jnz  C688:955C
C688:955A  pop  ax
C688:955B  ret
C688:955C  mov  [7574],si
```

So `AL=5` is the cacheable static-resource mode: unchanged `SI` returns without
reloading or reinterpreting the screen resource. `C688:96E1` invalidates that
cache by writing `FF` to both bytes; it is called by display-state transitions
such as `C688:7795`/`779A`, but not between every redraw inside the small
`C688:71A4`/`71B5` selection loops.

After the cache check, `C688:9541`:

```text
1. Applies the display/profile byte through C688:4473.
2. Copies a template from C688:8C9C / file `0x4F51C..0x4F57B` into low RAM at
   0x78E3. The template contains the `LIST OF DOC.` title and fixed layout
   bytes; code resumes immediately afterward at C688:8CFB.
3. Calls C688:76BF with the caller's SI value to load a resource into 0x7F28.
4. Parses a small header into 0x78D5, 0x78DB/0x78DF, and 0x78DD/0x78E1.
5. Interprets the remaining resource bytes, emitting characters via C688:5B83
   and inline display script bytes through C688:0240.
```

This loader is part of the post-template block now mapped as
`0x4F57B..0x50310`; the block remains `mixed` rather than pure code because it
contains inline key-dispatch tables and display-script bytes consumed by the
local trampolines.

`C688:76BF` has two modes:

```text
SI high byte == 0: treat SI low byte as a resource ID and call C688:936A
                  with AH=01, DL=resource ID, destination 0x7F28.
SI high byte != 0: treat SI as a CS pointer to a length-prefixed resource block
                   and copy that block to 0x7F28.
```

That means `SI=0x53` in the ORGN path is not an arbitrary state value; it is a
resource ID loaded through the same screen-resource path as other menu screens.
The next unresolved part is the resource ID to table/label binding for the
horizontal icon menus.

## Selectable Menu/List Drawing Layer

`C688:71A4`, `C688:71B5`, and `C688:71C4` wrap the small interactive
selection/list displays. They set a text/input buffer in `DX`, preserve the
caller state, call `C688:721D` to draw/setup, then call `C688:722F` to wait for
and process a key.

`C688:721D` is the split between raw screen-resource loading and the menu/list
drawing layer:

```asm
C688:721D  lahf
C688:721E  or   cl,cl
C688:7220  jz   C688:7227
C688:7222  sahf
C688:7223  call C688:9461     ; CL != 0: selectable menu/list draw
C688:7226  ret
C688:7227  sahf
C688:7228  call C688:9541     ; CL == 0: raw screen resource
C688:722B  mov  cx,0108
C688:722E  ret
```

`C688:9461` / file `0x4FCE1` is therefore the current best name for the
menu/list drawing layer. It starts by calling the cached `AL=5` path in
`C688:9541`, then performs per-item work through inline `C688:0240` display
scripts and the local emit helpers at `C688:969B` and `C688:968A`:

```asm
C688:9461  mov  al,05
C688:9463  call C688:9541     ; cached static resource load/draw
...
C688:9479  mov  al,05
C688:9483  mov  si,cx
C688:9487  and  si,00FF
...
C688:9492  call C688:9541     ; nested raw/default resource pass
...
C688:94A7  call C688:0240     ; inline script
...
C688:94F7  call C688:969B
C688:94FB  call C688:0240     ; inline script
C688:9532  call C688:968A
```

This matches the expected redraw shape for the `C688` resource/list path:
static screen/menu content is loaded on entry or when the `SI` resource changes,
while the inner key loop can redraw selection/text state without re-resolving
the same static resource every pass.

## Horizontal Icon Menu Renderer

`DC98:124C` / file `0x5DBCC` is the compact horizontal icon menu renderer used
by the word-processor and organizer icon bars. It is separate from the
`C688:9461` resource/list layer above.

Inputs:

```text
AX:BX = far pointer to the menu table
CX    = initially selected item index
```

The table consumed by `DC98:124C` starts at the effective table base, not always
at the first nearby byte of the surrounding data cluster:

```text
+0x00 word  clear/display mode; values 1 and 2 call DC98:0EE5 first
+0x02 word  item count
+0x04       six far icon pointer slots, 4 bytes each
+0x1C       fixed-width label text, 13 bytes per item
+0x6A word  optional key binding passed to the key loop
+0x6C word  optional key binding passed to the key loop
+0x6E word  optional key binding passed to the key loop
```

The renderer first calls `DC98:0E70`, emits a tiny fixed resource at
`EE4F:000A` through `C000:67AD`, and optionally clears/fills a region through
`DC98:0EE5` when the table's mode word is `1` or `2`.

It then lays out the icon bar across a 480-pixel row. The horizontal start
offset and spacing are derived from the item count:

```text
left    = 0x1B * (6 - count) + 7
spacing = ((0x1E0 - 2 * left - 0x4C * count) / (count - 1)) + 0x4C
```

That calculation matches a 480-pixel display width (`0x1E0`) and a 76-pixel
menu cell width (`0x4C`) around each 40x40 icon.

The draw pass has three loops:

```text
1. Draw stylized numeric badges from EE4F:(0x000E + item * 0x1A).
2. Draw each 40x40 icon by reading the far pointer from table+4+item*4 and
   building an inline FF 42 28 00 28 00 source-backed bitmap record.
3. Draw the 13-byte label at table+0x1C+item*0x0D through DC98:0E81 at y=0x34.
```

The generated icon blit records are sent to `C000:67AD`, which reaches the same
low-level `FF 42` bitmap handler documented in [`bitmaps.md`](bitmaps.md).

After drawing the static icon bar, `DC98:124C` calls `DC98:1198` with:

```text
AX = item count
BX = selected index
CX = first item x position
DX = item spacing
```

`DC98:1198` / file `0x5DB18` is the horizontal-menu key loop. It calls
`DC98:110E` to redraw the current selection, accepts numeric shortcuts
`'1'..`, handles arrow keys `0x10`/`0x11`, treats `0xDA` as selection, and also
checks the three optional key bindings pushed from the table tail.

Confirmed `DC98:124C` callers:

| Call site | Table pointer | Effective file base | Current read |
| --- | --- | ---: | --- |
| `DC98:2660` / `0x5EFE0` | `EFB5:000C` | `0x6FB5C` | WP `PRINTER` submenu. |
| `DC98:26BB` / `0x5F03B` | `EFBC:000C` | `0x6FBCC` | WP `COMMUNICATE` submenu. |
| `DC98:275D` / `0x5F0DD` | `EFAE:000C` | `0x6FAEC` | WP `FILE` submenu. |
| `DC98:2810` / `0x5F190` | `EFA7:000C` | `0x6FA7C` | WP top menu. |
| `DC98:2D2E` / `0x5F6AE` | `EF7A:000C` | `0x6F7AC` | WP `OTHERS` submenu. |
| `DC98:53E4` / `0x61D64` | `F08B:000C` | `0x708BC` | Organizer top menu. |

The WP top-menu wrapper dispatches return keys `1..6` to the known top-level
items. The `COMMUNICATE` wrapper similarly dispatches keys `1..6` to send,
receive, terminal, and setup handlers after the icon menu returns. The organizer
wrapper dispatches keys `1..5` after saving the selected index in `[82A6]`.

Current wrapper return-key map:

| Wrapper | Keys | Handler targets |
| --- | --- | --- |
| WP top menu `DC98:2807` | `1..6` | `1` returns `AX=0`; `2` calls FILE submenu `DC98:275A`; `3` far-calls `C688:EB46`; `4` calls PRINTER submenu `DC98:265D`; `5` calls COMMUNICATE submenu `DC98:26B8`; `6` calls OTHERS submenu `DC98:2D2B`. |
| WP FILE submenu `DC98:275A` | `1..6` | `C688:EB2E`, `C688:EBD9`, `C688:EBA9`, `C688:EBC1`, `DC98:455F`, `C688:EB91`. |
| WP PRINTER submenu `DC98:265D` | `1..3` | `C688:EB5E`, `DC98:24DB`, `DC98:22A1`. |
| WP COMMUNICATE submenu `DC98:26B8` | `1..6` | `C688:EC24`, `C688:EC3F`, `C688:EBF1`, `C688:EC09`, `C688:EC5A`, `DC98:22A1`. |
| WP OTHERS submenu `DC98:2D2B` | `1..4` | `SYSTEM` -> `DC98:288A`; `PREFERENCES` -> `DC98:2A83`; `T I M E` -> `EBBB:0000`; `ROM CARD` -> `DC98:2B75`. |
| Organizer top menu `DC98:53C3` | `1..5` | Saves selected index to `[82A6]`, then calls `DC98:6A38`, `DC98:7284`, `DC98:990D`, `DC98:B67C`, or `DC98:CF12`. |

Most handler names are still semantic candidates, but the dispatch structure is
now direct code rather than inferred from strings.

## Organizer Calculator

The organizer CALCULATOR app is the first top-menu handler:
`DC98:6A38` / file `0x633B8`. It clears/redraws two calculator display areas,
initializes calculator BCD buffers at `85EE` and `8600`, seeds display glyph
selectors `[8648]=0x0C` and `[8649]=0x0D`, and then enters the main event loop
at `DC98:640F` / file `0x62D8F`.

The calculator uses a private translation table at `C000:5619..5644`, not just
the normal alphanumeric meanings of those keys. The digit ladder is direct ROM
code in `DC98:640F`:

| Table bytes | Key values | Calculator digit |
| ---: | --- | ---: |
| `C000:5619/561A` | `M` / `m` | `0` |
| `C000:561B/561C` | `J` / `j` | `1` |
| `C000:561D/561E` | `K` / `k` | `2` |
| `C000:561F/5620` | `L` / `l` | `3` |
| `C000:5621/5622` | `U` / `u` | `4` |
| `C000:5623/5624` | `I` / `i` | `5` |
| `C000:5625/5626` | `O` / `o` | `6` |
| `C000:5627/5628` | `7` / `7` | `7` |
| `C000:5629/562A` | `8` / `8` | `8` |
| `C000:562B/562C` | `9` / `9` | `9` |

That is a good match for a calculator overlay on the right side of the keyboard:
`7 8 9`, `U I O`, `J K L`, and `M` form a numeric-pad-like cluster.

The same table also drives the arithmetic/function keys:

| Table bytes/event | Key values | Printed calculator legend | Observed handler |
| ---: | --- | --- | --- |
| `C000:562D/562E` | `,` / `,` | `.` | Decimal point entry; redraws the input display with `DC98:583E(1)`. |
| `C000:562F/5630` | `.` / `.` | `+/-` | Calls `DC98:5CD6`. |
| `C000:5631/5632` | `/` / `/` | `+` | Sets operation state `[85EA]=1`. |
| `C000:5633/5634` | `;` / `;` | `-` on the printed `:` key | Sets operation state `[85EA]=2`. |
| `C000:5635/5636` | `P` / `p` | multiply | Sets operation state `[85EA]=3`. |
| `C000:5637/5638` | `0` / `0` | divide | Sets operation state `[85EA]=4`. |
| `C000:5639/563A` | `'` / `'` | square root | Sends the short resource at `F093:0008`, then calls `DC98:6B86`. |
| `C000:563B/563C` | `\` / `\` | `%` | Finalizes through `DC98:6340` and sets `[85EA]=0x32`. |
| `C000:563D/563E` | `[` / `[` | `RM` | Calls `DC98:5D09` with the source/destination buffers reversed. |
| `C000:563F/5640` | `]` / `]` | `SM` | Calls `DC98:5D09`, then redraws/clears input. |
| `C000:5641/5642` | `-` / `-` | `M-` | Calls `DC98:60AB` after finalizing current input. |
| `C000:5643/5644` | `=` / `=` | `M+` | Calls `DC98:5FE0` after finalizing current input. |
| event `0xDA` | `RET`-style selection event | `=` | Calls `DC98:6340` and sets `[85EA]=0x32`. |

The printed legends also identify calculator functions outside the
`C000:5619..5644` table: physical `INS` is `CE`, and physical `BACK` is `CA`.
That makes a practical MAME keypad overlay a physical-key remap to calculator
legends rather than to the printed typewriter symbols: keypad `0..9` to
`M,J,K,L,U,I,O,7,8,9`, keypad `/` to physical `0`, keypad `*` to physical `P`,
keypad `-` to the physical `;`/`:` key, keypad `+` to physical `/`, keypad `.`
to physical `,`, and keypad Enter to physical `RET`. Since the real keyboard
has these calculator legends printed as an overlay, unconditional MAME keypad
aliases are a reasonable fit even outside the calculator app.

The calculator display renderer uses source-backed bitmap glyphs rather than
normal text for numeric displays. The redraw helpers at `DC98:54C2` and
`DC98:583E` build `FF 42` records from the 8x12 digit resource at
`F16C:000A` / file `0x716CA`, with punctuation/blank entries at `F16C:008C`,
`F16C:0099`, `F16C:00C0`, and nearby offsets. This is the same large digit
resource family later used by WORLD CLOCK.

## Organizer WORLD CLOCK

The organizer WORLD CLOCK app is the fourth top-menu handler:
`DC98:B67C` / file `0x67FFC`. It begins by drawing the two selected city labels
from a city table at `F1CA:0006` / file `0x71CA6`. City records are `0x38`
bytes each; the handler uses bytes at record offsets `0x1A` and `0x1B` as
display coordinates for map markers, and uses record text fields for the city
and country labels.

`DC98:B67C` then calls `DC98:A0CC` / file `0x66A4C`, which redraws the map
area. That helper builds an `FF 42` source-backed bitmap record for a `96x64`
bitmap at `F13C:000A` / file `0x713CA`, then draws two `6x6` city markers from
the small marker resource at `F138:000E` and `F138:0014`.

The live time readouts are drawn separately by `DC98:A06C` / file `0x669EC`.
That wrapper refreshes the base time, applies the selected second-city offset,
and calls `DC98:9AC8` / file `0x66448` twice. `DC98:9AC8` does not use the
normal text font; it emits `FF 42` bitmap records for 7x12 digit glyphs from
`F16C:000A` / file `0x716CA`, a 4x12 separator from `F16C:008C` / file
`0x7174C`, and a blank leading-hour glyph from `F16C:0099` / file `0x71759`.

The right-side title/menu is not a raw bitmap. It is stored as display scripts:

| Resource | Segment | Length | Contents |
| ---: | --- | ---: | --- |
| `0x7104C` | `F104:000C` | `0x5A` | Six `FF 44` rectangle records. The first clears the 114x64 right-side strip; the next five set 1-pixel-high horizontal rules at y offsets `0`, `2`, `4`, `6`, and `8`. |
| `0x710DE` | `F10D:000E` | `0x82` | `FF 40` positioned text for `WORLD CLOCK` and the menu labels `[H] SET HOME CITY`, `[2] SET 2ND CITY`, `[S] SET TIME/DATE`, `[F] DISPLAY FORM`, and `[A] DAILY ALARM`. |

The line script is sent before the title/menu text script, so the visible
header can look like broken horizontal rules: the later `WORLD CLOCK` text pass
overwrites or masks the top rules where the title sits, while the lower rule
remains continuous.

The main loop keeps `SI` as a blink state and `DI` as a small divider. Every
third loop pass it toggles `SI` between `0` and `1` and redraws the selected
city marker from `F138:(0x000E + SI * 6)`. The loop then calls `DC98:A06C` and
`DC98:0D19` while waiting for input. With MAME driving IRQ `F9` at 10 Hz, the
seconds display updates without keypresses and this marker blink becomes
visible; the exact wait/divider relationship still needs a tighter trace.

Subcommand dispatch from `DC98:B67C`:

| Key | Handler |
| --- | --- |
| `H` / `h` | `DC98:A2CF` with `AX=0`; set home city. |
| `2` | `DC98:A2CF` with `AX=1`; set second city. |
| `S` / `s` | `DC98:AAD5`; set time/date. |
| `F` / `f` | `DC98:AD1B`; display format. |
| `A` / `a` | `DC98:B457`; daily alarm. |

`DC98:B457` / file `0x67DD7`, the DAILY ALARM handler, edits four rows. Each
row is stored at `89F2 + row * 0x17`: the first word is minutes after midnight
or `0xFFFF` for disabled, and the text field begins at `+2`. These rows are not
just local WORLD CLOCK UI state. `DC98:D3BB`, called from the retained
power-transition path, scans them after the scheduler alarm table and copies the
next daily alarm into the low-RAM alarm buffer at `6D41..6D4C` for the RTC alarm
programmer. Daily alarm selections are marked as `6D4C = 0x0100 + row`.

`DC98:AAD5` / file `0x67455`, the SET TIME/DATE handler, redraws the right
panel line script at `F104:000C` and the SET TIME/DATE text resource at
`F116:0000` / file `0x71160`. It reads the current RTC-backed date/time through
the DOS-like wrappers `DC98:0D2A` (`INT 21h AH=2A`) and `DC98:0D4E`
(`INT 21h AH=2C`), then copies the values into local edit fields.

The wrapper cache layout is:

| Address | Value |
| ---: | --- |
| `72D7` | Year. |
| `72D9` | Month. |
| `72DB` | Day. |
| `72DD` | Weekday returned by `AH=2A`. |
| `72DF` | Hour. |
| `72E1` | Minute. |
| `72E3` | Second. |

The edit UI obeys `[6808]`, the display-form flag edited by `DC98:AD1B`: `0`
is 24-hour display, nonzero is 12-hour display. In 12-hour mode, `DC98:AAD5`
edits an hour in `1..12` plus an `a`/`p` flag, then converts back to 24-hour
time before committing. In 24-hour mode it edits the hour directly as `0..23`.
Minutes are limited to `0..59`; month is limited to `1..12`; the full date is
validated before commit.

On accept, `DC98:AAD5` writes year/month/day back to `72D7`/`72D9`/`72DB`,
writes hour/minute to `72DF`/`72E1`, forces `72E3` to zero, calls
`DC98:0D72` and `DC98:0D8F`, then calls `DC98:D3BB` to refresh the broader
time state. The C000 handlers behind those wrappers update the RTC BCD shadow
and write ports `0xD0..0xDC`; see [`hardware.md`](hardware.md).

The WP `FILE` submenu is the document storage workflow for Built-in, Card, and
DreamLink targets. Its card path is exposed through a DOS-like file API with
drive letters, `X:*.*`, 8.3 filenames, standard find-first DTA offsets, and
`int 21h`-style open/read/write/rename/delete/free-space calls. See
[`file-system.md`](file-system.md).

The OTHERS `ROM CARD` item is the executable/software-card path for the same
PCMCIA slot.

`DC98:2B75` / file `0x5F4F5` is the ROM-card loader. It does not appear to
query a hardware card type directly. Instead, it builds a drive-qualified path
for `EROMCARD.X`, tries `([0x6805] + 1):EROMCARD.X` first, then falls back to
`[0x6805]:EROMCARD.X`, and probes each path through `DC98:EF7B`, a DOS-like
`set DTA` plus `find first` wrapper:

```asm
DC98:2B96  mov al,[es:6805]
DC98:2B9A  inc al              ; first candidate drive
...
DC98:2BBE  call DC98:EF7B      ; find first EROMCARD.X
...
DC98:2BCC  mov al,[es:6805]    ; fallback drive
DC98:2BDC  call DC98:EF7B
```

If neither lookup succeeds, it displays `No ROM card is in the slot`. On a
successful lookup, it calls `C688:01E6`, compares the returned work-memory value
with the find-first DTA file size at `[bp-0x29]/[bp-0x27]`, opens the file with
`DC98:E946`, reads it to `0xA4F0` through `DC98:EE08`, and closes the handle
through `DC98:EE2E`.

The loaded file then gets a small executable-format check:

```asm
DC98:2CE2  mov bx,[0A4F0]
DC98:2CE6  mov ax,[0A4F2]
DC98:2CE9  cmp ax,1997
DC98:2CEE  cmp bx,0A4F0
DC98:2D15  call C688:022B      ; calls far [0xA4F4]
```

So the current read is: ROM CARD accepts a card if `EROMCARD.X` can be found and
opened through the normal DOS-like file services on one of the candidate card
drives, then requires header words
`[0xA4F0] == 0xA4F0` and `[0xA4F2] == 0x1997` before jumping through the loaded
entry pointer at `0xA4F4`. Failure paths use `Inadequate work memory`, `Can not
open EROMCARD.X`, `Not enough memory`, and `ROM Card ID error`.

`DC98:288A` is now confirmed as the WP OTHERS -> SYSTEM settings screen. It
draws the resource containing `AUTO POWER OFF PERIOD : { 2 } { 3 } { 5 }
{ 10 } { 15 } { 20 } { UNLIMITED }` and `POWER ON BUZZER : { TYPE 1 }
{ TYPE 2 } { TYPE 3 } { NO }`. The screen edits settings backed by `[6D2F]`
and `[6D30]`, and previews the selected buzzer type on Space:

```asm
DC98:2966  cmp di,0020          ; Space
DC98:296B  cmp word [bp-4],0003 ; 3 == NO
DC98:2971  mov ax,[bp-4]        ; 0..2 == TYPE 1..3
DC98:2974  call C000:077C       ; play preview
```

On selection/accept, it stores `[bp-6]` to `[6D2F]`, `[bp-4]` to `[6D30]`, and
uses `[6D30]` to choose the `POWER ON BUZZER` startup sound. It also maps
`[6D2F]` through the word table at `EF79:0002` / file `0x6F792` and stores the
active auto-off reload value in `[6D31]`:

| UI choice | `[6D2F]` | `[6D31]` reload |
| --- | ---: | ---: |
| `2` minutes | `0` | `0x04B0` / `1200` |
| `3` minutes | `1` | `0x0708` / `1800` |
| `5` minutes | `2` | `0x0BB8` / `3000` |
| `10` minutes | `3` | `0x1770` / `6000` |
| `15` minutes | `4` | `0x2328` / `9000` |
| `20` minutes | `5` | `0x2EE0` / `12000` |
| `UNLIMITED` | `6` | `0x0000` |

The values match a 10 Hz idle countdown. The buzzer hardware path and auto-off
power path are documented in [`hardware.md`](hardware.md).

`DC98:2A83` is the WP OTHERS -> PREFERENCES screen. It draws the resource at
`EF8E:0000` / file `0x6F8EE`, then edits two toggle rows:

| UI row | Backing storage | Confirmed behavior |
| --- | --- | --- |
| `GRAMMAR CHECKING : { ON } { OFF }` | word `[6D55]` | Startup initializes this to `0`; the C688 spell/grammar front-end treats `[6D55] == 0` as grammar enabled. |
| `STICKY SHIFT KEY : { ON } { OFF }` | byte `[6D24]` | Startup initializes this to `1`; keyboard code also references `[6D24]`. |

The PREFERENCES handler commits both values only on the select key
(`DI == 0xDA`); cancel-style exits leave the original backing values intact.

## Resource Lookup Service

When `C688:76BF` is called with an 8-bit resource ID in `SI`, it calls
`C688:936A`, a far wrapper for `C000:1712`. With `AH=01`, the service dispatches
through `C000:1873` to `C000:18EE`.

`C000:18EE` uses segment `D59C` / file base `0x559C0` as a resource table:

```asm
C000:18F3  mov bx,[75ED]       ; stream offset inside resource
C000:18F9  mov si,D59C
C000:18FD  mov ds,si
C000:1901  add dx,dx           ; DL resource ID -> word index
C000:1903  mov si,0004
C000:1906  add si,dx
C000:1908  mov si,[si]         ; resource offset in D59C segment
C000:190A  mov dx,[si]         ; resource length/limit
C000:190C  add si,0002         ; payload start
C000:190F  add si,bx           ; support chunked reads
C000:191A  cmp cx,ax
C000:1928  rep movsb           ; copy to caller buffer
```

Resource table entry `n` is the word at file `0x559C4 + n * 2`. The copied
payload begins at `0x559C0 + entry + 2`.

Examples from the first menu branch:

| Resource ID | Table word | Payload file offset | Notes |
| ---: | ---: | ---: | --- |
| `0x53` | `0x1574` | `0x56F36` | ORGN branch setup resource; starts with centered `*** W A I T ***`. |
| `0x5B` | `0x1748` | `0x5710A` | Word-processor-side setup resource; printer/paper setup text follows in the same resource area. |

This establishes the source of resources loaded by `C688:7689`/`C688:9541`.
The 40x40 horizontal-menu icon sources are documented in
[`bitmaps.md`](bitmaps.md).
