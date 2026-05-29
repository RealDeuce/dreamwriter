# Startup UI Trace

## Cold Boot Path Into Application UI

The cold boot path still starts in `C000`, then transfers into the main
application segment:

```asm
C000:00E1  mov word [6D81],0000
C000:00EE  call C000:0225
C000:00F1  call C000:02BE
C000:00F4  call C000:5AA2
C000:00F7  call C000:0825
C000:00FA  call C000:4811
C000:00FD  call far DC98:539E
C000:011A  jmp far C688:000B
```

`DC98:539E` is an application/subsystem initializer. It calls several local
initializers and writes a simple magic/version marker:

```asm
DC98:539E  call DC98:6A32
DC98:53A1  call DC98:727D
DC98:53A4  call DC98:98E7
DC98:53A7  call DC98:B5EE
DC98:53AA  call DC98:CF0C
DC98:53AD  mov byte [8A50],4F   ; 'O'
DC98:53B2  mov byte [8A51],39   ; '9'
DC98:53B7  mov byte [8A52],32   ; '2'
```

`C688:000B` is only a far wrapper. It calls the real main application startup
routine at `C688:29D9`:

```asm
C688:000B  call C688:29D9
C688:000E  retf
```

There is a second nearby application entry used by a warm path:

```asm
C000:015C  jmp far C688:000F

C688:000F  call C688:7752
C688:0012  retf
```

`C688:7752` is inside the first-menu path; it calls `C688:77B4` to copy the
two-button menu resource and then enters the menu dispatcher. This entry bypasses
the full `C688:29D9` main startup and the `C688:7766` boot-update sequence.

## Main Application Startup

`C688:29D9` clears a large low-RAM work area, initializes display/document state,
then enters the normal UI path:

```asm
C688:29D9  mov di,77B8
C688:29DC  mov cx,7F29
C688:29DF  sub cx,77B8
C688:29EB  rep stosb              ; clear 0x77B8..0x7F28-ish
C688:29EE  mov si,[cs:2A63]
C688:29F3  mov [7671],si
C688:29FC  mov byte [8E3F],00
C688:2A01  call C688:294B         ; RAM/work-area discovery
C688:2A04  call C688:2D75
C688:2A09  mov word [75ED],793B
C688:2A0F  call C688:61DB
C688:2A12  call C688:0240         ; inline display/script interpreter
```

The bytes after `C688:2A12` are inline script data, not executable code. Linear
disassembly is misleading there until the script terminator is decoded.

After the inline script returns, the routine initializes more UI state and jumps
to `C688:7729`:

```asm
C688:2A35  mov byte [78A2],FF
C688:2A38  mov byte [7810],FF
C688:2A46  mov si,3030
C688:2A49  mov [787E],si
C688:2A4D  mov al,08
C688:2A4F  mov [798F],al
C688:2A52  mov al,03
C688:2A54  mov si,0004
C688:2A57  call C688:9541
C688:2A5A  call C688:9DFB
C688:2A5D  call C688:441A
C688:2A60  jmp C688:7729
```

## Inline Display Script Interpreter

`C688:0240` immediately jumps to `C688:3879`. That routine pops the return
address into `SI`, reads opcodes from `CS:SI`, dispatches through a table at
`C688:38A4`, then returns to `C688:3879` for the next opcode:

```asm
C688:0240  jmp C688:3879

C688:3879  pop si
C688:387A  mov al,[cs:si]
C688:387D  inc si
C688:387E  mov cl,al
C688:3880  cmp al,44
C688:3884  jc  C688:388E
C688:3886  mov al,[cs:si]       ; opcodes >= 0x44 consume an operand into DL
C688:3889  mov dl,al
C688:388B  mov dh,00
C688:388D  inc si
C688:388E  push si
C688:388F  mov si,38A4
C688:3892  mov ch,00
C688:3894  add si,cx
C688:3896  mov si,[cs:si]
C688:3899  mov cx,3879
C688:389C  push cx
C688:389D  jmp si
```

This is the right mechanism to keep in mind when tracing startup display code:
many `call C688:0240` sites are followed by data bytes. A function-boundary pass
must skip over those script bytes.

## Boot Update / Menu Screen Path

`C688:7729` is the first tight UI boundary after the main application startup.
It calls the fixed boot-update sequence, initializes a little more UI state, then
copies the two-button menu resource and waits for the first input result:

```asm
C688:7729  call C688:7766
C688:772C  mov si,0001
C688:772F  call C688:76BF
C688:774F  call C688:77AA
C688:7752  call C688:77B4
C688:7755  cmp al,02
```

Those constants are good candidates for the visible numbered boot progress
updates. The boot-update helper is:

```asm
C688:7766  mov al,0A
C688:7768  call C688:8F43
C688:776B  mov si,0003
C688:776E  call C688:9541
C688:7771  call C688:599C
C688:7774  call C688:44C4
C688:7777  mov al,04
C688:7779  call C688:77A3
...
C688:779A  mov al,00
C688:779C  call C688:77A3
C688:779F  call C688:96E1
C688:77A2  ret

C688:77A3  call C688:4473
C688:77A6  call C688:0D05
C688:77A9  ret
```

After that setup, `C688:77B4` copies the first menu script block at `C688:D133`
into the work buffer at `0x7F28` and calls `C688:8312`:

```asm
C688:77B4  mov si,D133
C688:77B7  mov cx,007C
C688:77BA  call C688:77C1
C688:77BD  call C688:8312

C688:77C1  push ds
C688:77C2  mov ax,C688
C688:77C5  mov ds,ax
C688:77C7  mov di,7F28
C688:77D1  rep movsb
C688:77D5  mov [79E2],di
C688:77D9  call C688:6B8C
C688:77DC  ret
```

`C688:D133` maps to file `0x539B3`. The copied `0x7C`-byte script contains
the text records and far pointers for the screen with the two menu choices:

```text
file 0x539E8: ORGANIZER MENU
file 0x53A1C: WORD PROCESSOR MENU?
file 0x53A2F / C688:D1AF: 36x34 visible button bitmap starts immediately after script
```

The actual button outline bitmap starts at file `0x53A2F` / `C688:D1AF`, not
at the beginning of the script block. The script's first bitmap pointer is the
little-endian far pointer `AF D1 88 C6`, i.e. `C688:D1AF`.

Render it with:

```sh
tools/rom2.py bitmap --base 0x53a2f --row-bytes 5 --height 34
```

The bitmap record declares 36 visible pixels by 34 rows. The source still needs
5 bytes per row, so it consumes `0xAA` bytes:

```text
5 source bytes * 34 rows = 170 bytes = 0xAA
0x53A2F + 0xAA = 0x53AD9
```

## Low-Level Text And Bitmap Rendering

The copied resource block is rendered through a `C688` to `C000` service edge:

```asm
C688:6B8C  mov si,[79E2]
C688:6B90  mov dx,7F28
C688:6B95  sub si,dx
C688:6B9A  mov [7727],si       ; copied resource length
C688:6B9E  mov byte [771D],0A
C688:6BA3  mov si,771F
C688:6BA6  mov [771B],si
C688:6BAA  mov si,7719
C688:6BAD  mov word [75EF],7779
C688:6BB3  mov bx,ds
C688:6BB5  mov ah,06
C688:6BB7  call C688:9364      ; far call C000:170E

C688:9364  call far C000:170E
```

`C000:170E` preserves the caller state, dispatches service `AH=06`, and reaches
the resource/text renderer at `C000:5AD6`. That renderer copies the resource
bytes into its own staging buffer, consumes printable bytes as glyphs, and
writes glyph rows into the `0x1000` framebuffer with a scanline stride of
`0x40` bytes:

```asm
C000:5AD6  push es
C000:5ADC  mov ax,[7119]
C000:5AEB  call C000:5FE3      ; select font/run metadata
C000:5AF4  mov di,7185
C000:5AFF  rep movsb           ; copy DS:SI resource bytes into staging
C000:5B14  mov si,[728E]
C000:5B18  mov al,[si]
C000:5B1E  sub al,20
C000:5B22  cmp al,C0
C000:5B29  mov dl,al           ; printable glyph index
...
C000:5CC8  mov di,[728C]       ; framebuffer byte address
C000:5CFF  mov ah,[es:di]
C000:5D09  mov [es:di],al
C000:5D0C  add di,40
```

Raw bytes `0x20..0xDF` are printable in this resource stream. Bytes
`0xE0..0xFF` enter the primary control table at `C000:5DC8`, which explains why
the manual's character set can document `0xE0..0xFF` as blank/reserved even
though the ROM font storage at those glyph slots overlaps the start of a bold
font run. `0xFF` is an escape byte: it reads a second sub-opcode through the
byte-indexed dispatch at `C000:5EE6`.

The primary `0xE0..0xFF` table is at `C000:5DDC`:

| Bytes | Handler | Current read |
| --- | --- | --- |
| `E0..E4` | `C000:5E1E` | Compact render/advance helpers. The control value becomes `CH = 1..5`, sets `[7118] bit 0x20`, and re-enters glyph-row output. |
| `E5..E6` | `C000:5E1C` | Same path with `CH = 1`; likely additional compact spacing/control aliases. |
| `E7..EF` | `C000:5E36` | Shared reserved/unconfirmed path. No confirmed resource use yet. |
| `F0` / `F1` | `C000:5E39` / `5E40` | Set/clear `[7118] bit 0x04`. |
| `F2` / `F3` | `C000:5E47` / `5E4E` | Set/clear `[7118] bit 0x08`. |
| `F4` / `F5` | `C000:5E55` / `5E61` | Set/clear `[7118] bit 0x02`; the clear path renders from the temporary row buffer at `0x70F7`. |
| `F6` / `F7` | `C000:5E7B` / `5E82` | Set/clear `[7118] bit 0x10`. |
| `F8` / `F9` | `C000:5E8A` / `5E91` | Set/clear `[7117] bit 0x01`, then call `C000:5FE3` to reselect the font/run pointer in `[70F2]`. |
| `FA` / `FB` | `C000:5E9F` / `5EAB` | Set/clear `[7118] bit 0x01` and `[7117] bit 0x02`, then reselect font/run metadata. |
| `FC` / `FD` | `C000:5EB7` / `5EAB` | Variant of the `[7117] bit 0x02` font/run selection path. |
| `FE xx` | `C000:5EBE` | Consumes one byte into `[7123]`; exact layout role still needs naming. |
| `FF xx` | `C000:5EE6` | Escape to the second display sub-opcode dispatch. |

The `F8..FD` entries are the strongest evidence that high bytes select font or
font-adjacent rendering properties rather than representing printable glyphs.
`C000:5FE3` computes the active glyph base from the current font family in
`[70F4]` plus the style bits in `[7117]`, then stores that pointer in `[70F2]`.

The typing-tutor title resource gives a concrete example. Around file
`0x7881B`, the text that the rough scanner prints as
`.A.lmena .K.eyboard .T.raining .S.ystem` is actually:

```text
F8 41 F9 6C 6D 65 6E 61 20
F8 4B F9 65 79 62 6F 61 72 64 20
F8 54 F9 72 61 69 6E 69 6E 67 20
F8 53 F9 79 73 74 65 6D
```

So `F8` enables a style for the initial capital, `F9` disables it, and the rest
of each word is rendered with the previously selected family. In MAME, the
surrounding letters are narrow while `A`/`K`/`T`/`S` are bold, so this is a
confirmed inline bold marker for the active family, not a hard-coded switch to
the main bold font. The related `FA..FD` controls change `[7117] bit 0x02`,
which selects the small variant within the active family.

That `FF` sub-opcode space has at least two groups:

```text
FF 00..12  low-number text/cursor/window/line helpers via table C000:5F0B
FF 40..44  positioned drawing helpers via table C000:6621
```

The low-number and positioned-drawing groups are distinct. For example,
`FF 04` and `FF 06` are real low-number sub-opcodes seen in organizer/address
book resources, while `FF 40`, `FF 42`, and `FF 44` are the currently confirmed
positioned drawing forms.

Confirmed forms so far:

| Resource bytes | Handler | Meaning |
| --- | --- | --- |
| `FF 00` | `C000:5F32` | Clear the `0x1000` framebuffer. |
| `FF 02 xx xx yy yy` | `C000:5F42` | Position text cursor. The following bytes are rendered as text until the next control byte. |
| `FF 04 nn nn` | `C000:60AF` | Low-number cursor/spacing helper; exact semantics still need naming. |
| `FF 06 ...` | `C000:605F` | Low-number line/region helper; exact semantics still need naming. |
| `FF 40 xx xx yy yy` | `C000:6627` | Position bitmap/pixel cursor. |
| `FF 42 hh hh ww ww off off seg seg` | `C000:6648` | Bitmap blit. `hh` is the row count, `ww` is the bit width rounded up to source bytes per row, and `off:seg` is the source pointer. |
| `FF 44 ...` | `C000:675D` | Positioned region/line/fill-style draw operation; exact fields still need decoding. |

The button image record in the first menu resource is:

```text
FF 40 06 00 82 00
FF 42 22 00 24 00 AF D1 88 C6
```

That positions the bitmap, then blits `0x22` rows by `0x24` bits from
`C688:D1AF` / file `0x53A2F`. The source stride is `(0x24 + 7) / 8 = 5` bytes,
which matches the observed `5 * 34 = 0xAA` byte button bitmap. The record seems
to use a 36-bit visible width inside 5-byte rows; the extra bits are padding or
right-edge detail.

## First Input Wait

After the menu resource is copied, `C688:8312` enters the first menu/input
dispatcher. The loop around `C688:837E` consumes the current key/event code
from `[0x794A]` and branches on values such as `0x03`, `0x12`, `0x13`, and
`0xDA`:

```asm
C688:8312  call C688:2D26
C688:8315  call C688:4848
C688:8318  ret
C688:8319  call C688:8926
C688:831C  call C688:F140
...
C688:834F  mov word [75EF],833B
C688:8355  mov si,005B
...
C688:837E  pop si
C688:837F  pop word [75EF]
C688:8383  mov al,[794A]
C688:8386  cmp al,03
C688:8388  jz  C688:83D8
C688:838A  cmp al,DA
C688:838C  jz  C688:83DD
C688:838E  cmp al,13
C688:8390  jz  C688:8399
C688:8392  cmp al,12
C688:8394  jz  C688:8399
C688:8396  jmp C688:92A0
C688:8399  jmp C688:928D
```

Observed behavior in MAME/manual-driven testing:

| Input from first two-button screen | Working key/event code | Next screen |
| --- | ---: | --- |
| `ORGN` key | `0xDA` | Organizer horizontal icon menu. |
| Any other ordinary key | not `0xDA` | Word processor horizontal icon menu. |

The `0xDA` key/event mapping is inferred from the `C688:838A` branch and the
observed `ORGN` behavior; the keyboard translation table still needs a complete
pass.

The immediate post-keypress targets are now bounded:

```asm
C688:83D8  call C688:898A
C688:83DB  jmp  C688:8419

C688:83DD  mov  al,[794A]
C688:83E0  cmp  al,DA
C688:83E2  jz   C688:83EC
C688:83E4  mov  word [75EF],8347
C688:83EA  jmp  C688:83AB

C688:83EC  mov  si,0053
C688:83EF  call C688:7689
C688:83F2  call C688:8610
C688:83F5  call C688:89F6
C688:83F8  jz   C688:8402
C688:83FA  call C688:5B7D
C688:83FD  call C688:86C9
C688:8400  jmp  C688:8413
C688:8402  mov  si,78D1
C688:8405  mov  bx,[si]
C688:8407  mov  [78F5],bx
C688:840D  mov  bx,[si+2]
C688:840F  mov  [78D9],bx
C688:8413  call C688:44C4
C688:8416  call C688:88FC
C688:8419  jmp  C688:EC9F
```

`C688:928D` is another inline key-dispatch trampoline. It calls `C688:92DF`,
then consumes key/target pairs embedded immediately after the call:

```text
13 -> C688:92C0
12 -> C688:92CC
DA -> C688:92CC
0B -> C688:92A7
03 -> C688:92A7
00 -> end
```

So the first-level key handling is real code, not speculation. The shared menu
loop after `C688:8419` is now split out in `menu-dispatch.md`; the later
horizontal icon/menu table consumer is `DC98:124C`, documented in
`menu-dispatch.md` and `bitmaps.md`.

The next-level menus are not in the first-menu `C688:D133` resource block. They
live in later menu/table clusters:

| Menu | File offsets | Labels |
| --- | --- | --- |
| Word processor | `0x6FA98..0x6FADF` | `EDIT TEXT`, `FILE`, `CLEAR TEXT`, `PRINTER`, `COMMUNICATE`, `OTHERS` |
| Organizer | `0x708D8..0x70917` | `CALCULATOR`, `CALENDAR`, `SCHEDULER`, `WORLD CLOCK`, `ADDRESS BOOK` |

Both screens are horizontal icon menus. The visible labels are fixed-width text
entries after compact metadata/pointer tables; they are not found by the
`FF 42` bitmap-record scanner because `DC98:124C` builds the bitmap records
dynamically from far pointers in the menu table. Arrow keys move the
highlighted/inverted label, Enter selects it, and number keys can jump directly
to an item.

One input wrapper stores the newly-read key/event byte back to `[0x794A]`:

```asm
C688:93B5  lahf
C688:93BA  push word [75EF]
C688:93BE  call C688:5358
C688:93C1  mov [794A],al
```

`C688:5358` is a higher-level keyboard/event wait. In the no-event case it
loops through the local input helpers until a value other than `0xFF` is
available. The lower-level idle halt found in this pass is in the `C000`
keyboard/power wait code, not in the menu resource itself:

```asm
C000:4A94  mov al,[6D4F]
C000:4A97  out 60h,al
C000:4A99  sti
C000:4A9A  hlt
C000:4A9B  nop
C000:4A9C  ret
```

`C000:4A9D` and the related loop at `C000:4AB9..4AC6` call that tiny idle
routine after checking the keyboard/event ring state. This gives a useful
working boundary for the cold boot display path: from `C000:0000` through
`C688:77BD`, the firmware is still drawing and initializing; once execution
settles into the `C688:8312`/`C688:5358` input path and reaches `C000:4A9A`,
the boot screen is up and the firmware is waiting for keyboard input.

Several apparent `hlt` hits in the `C688` UI area are false positives from
linear disassembly through resource data or through byte values used as
characters/control codes. In particular, the cluster around `C688:9A4F` compares
or emits `0xF4` and `0xF5` as data; it is not the CPU idle instruction.

## Startup Banner Resource Block

The manual and the local `mame/nakajies.cpp` TODO both indicate that boot should
show version/copyright messages. The ROM has exactly that resource block
immediately before the first menu resource:

```text
file 0x53888 / C688:D008: resource script header
file 0x53892 / C688:D012: INITIALIZING
file 0x538AA / C688:D02A: WORD PROCESSOR                      LINGUISTIC TECHNOLOGY
file 0x538E9 / C688:D069: (C) 1992 NER Inc. Ver. 3.00         (C) 1983 Proximity Technology Inc.
file 0x53935 / C688:D0B5: (C) 1992 mikrolab Ver. 5.00         (C) 1983 Merriam-Webster Inc.
file 0x5397C / C688:D0FC: All Rights Reserved                 All Rights Reserved
```

This makes the current emulated startup behavior suspicious: if it shows only
`INITIALIZING` before reaching the two-button menu, MAME may be taking the wrong
reset/retained-RAM path, skipping a timing/input wait, or missing a hardware
condition that selects the banner screen. The direct consumer for this resource
block has not been confirmed. Static search did not find a simple `mov si,D008`,
`mov si,D012`, or `mov si,D02A` reference; it may be reached through an indexed
resource table or through an inline-script/data pointer decoded by `C688:0240`.

The V20 hard reset mapping itself does not currently look like the likely cause.
MAME reset maps the final ROM bank everywhere, executes the reset vector at file
`0x7FFF0`, then the trampoline maps `C0000..DFFFF` to file `0x40000..0x5FFFF`
before jumping to `C000:0000`. A more plausible split is hard reset versus the
product's normal power/wake path: IRQ `F8` saves a retained resume context under
`6D65..6D87`, and IRQ `FF` can set warm/diagnostic state before writing port
`0x70` and looping. The real device may show the copyright banner during a
retained-RAM wake path that MAME reset does not reproduce.

Good next breakpoints/watchpoints:

```text
C000:00FD      application/subsystem init call
C688:000B      main application wrapper
C688:29D9      main application startup
C688:0240      inline script interpreter entry
C688:3879      inline script dispatcher
C688:7766      boot update sequence
C688:77A3      individual boot update helper
C688:77B4      two-button/menu resource copy
C688:77C1      copy resource block to 0x7F28
C688:6B8C      hand copied resource to C000 renderer
C688:9364      C688 wrapper for C000:170E
C000:5AD6      low-level resource/text renderer
C000:6648      FF 42 bitmap blit handler
C688:8312      first menu/input dispatcher
C688:93B5      wrapper that reads key/event into [0x794A]
C688:5358      higher-level keyboard/event wait
C000:4A9A      idle HLT reached by low-level keyboard/event wait
```
