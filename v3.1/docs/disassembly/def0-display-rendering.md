# DEF0 Display Rendering Pipeline

The display rendering chain at `DEF0:01BA..0D80`. These routines build
display scripts in the `[18F1]` work buffer using `FF xx` command
opcodes, then call `C000:3F35` to render them. Referenced bitmap and
glyph data lives in segments `EFCD`, `EFCE`, `EFD1`, `EFE1`, `EFE2`,
`EFE3`, `EFE6` (ROM data tables for character shapes and UI elements).

Called only from the top-level entry at `DEF0:0D25`.

See [`display-stream.md`](display-stream.md) for the `C000:3F35`
renderer and [`def0-display-services.md`](def0-display-services.md)
for the higher-level display service API.

## DEF0:0D25 — Display Composition Entry

Called from `C000:195B` (boot display init). Calls `DEF0:0D80` (display
init), then iterates 64 display slots, rendering each via the three
rendering sub-chains.

```asm
; file 0xDFC25
DEF0:0D25  55             push bp
DEF0:0D26  8BEC           mov bp,sp
DEF0:0D28  83EC40         sub sp,byte +0x40   ; 64-byte slot tracking array
DEF0:0D2B  51             push cx
DEF0:0D2C  56             push si
DEF0:0D2D  9A800DF0DE     call far DEF0:0D80  ; display init (15-byte script from EFFE)
DEF0:0D32  33F6           xor si,si            ; SI = slot counter
DEF0:0D34  EB0A           jmp short 0D40
```

First pass — render all 64 slots sequentially via `DEF0:01BA`:

```asm
DEF0:0D36  8BC6           mov ax,si
DEF0:0D38  E87FF4         call DEF0:01BA       ; render slot SI
DEF0:0D3B  C642C000       mov byte [bp+si-40],0 ; mark rendered
DEF0:0D3F  46             inc si
; ...
DEF0:0D40  83FE40         cmp si,byte +0x40    ; 64 slots
DEF0:0D43  7CF1           jl 0D36
```

Second pass — render via `DEF0:05E1` and `DEF0:0A22`, then wait for
keypress via `C000:194B` to cycle through interactive pages:

```asm
DEF0:0D45  E899F8         call DEF0:05E1       ; render chain 2
DEF0:0D48  E8D7FC         call DEF0:0A22       ; render chain 3
DEF0:0D4B  33C9           xor cx,cx
; ... loop: call C000:194B (wait key), render slot, mark done
DEF0:0D75  83F940         cmp cx,byte +0x40    ; done when 64 slots rendered
DEF0:0D78  75D5           jnz 0D4F
```

## DEF0:01BA — Slot Renderer (Chain 1)

Takes AX (slot index). Builds display scripts with `FF 40` (position)
and `FF 42` (bitmap blit) commands. Renders text labels and bitmap
glyphs using data from segments `EFE6` (glyph table) and `EFE3`
(alternate glyph set).

Large routine (DEF0:01BA..02D2, 280 bytes) with two continuation blocks
for rendering horizontal and vertical elements.

```asm
; file 0xDF0BA
DEF0:01E3  B8E6EF         mov ax,0xEFE6        ; glyph segment
DEF0:01E6  8EC0           mov es,ax
DEF0:01E7  268A87...      mov al,[es:bx+...]   ; read glyph data
```

## DEF0:05E1 — Multi-Row Renderer (Chain 2)

Renders a display section with multiple rows. Loops through positions,
building `FF 40` (position) + `FF 42` (bitmap) command pairs for each
row. Uses glyph data from `EFCE` and `EFCD`.

```asm
DEF0:05E1  ...            ; check position
DEF0:05F0  ...            ; loop body: build FF 40 + FF 42 commands
DEF0:0708  83FE...        ; row counter check
DEF0:0710  ...            ; next section (FF 40 + FF 42 for vertical)
```

Three sections rendered in sequence:
- DEF0:05F0..0708: rows using `EFCE` glyph segment (5-wide, 4-high tiles)
- DEF0:0715..082D: rows using `EFCE` glyph segment (alternate layout)
- DEF0:083A..090E: rows using `EFE6` glyph segment
- DEF0:0916..0A22: final section with combined glyphs

## DEF0:0A22 — Multi-Column Renderer (Chain 3)

Renders a display section with multiple columns. Builds nested loops
of `FF 40` + `FF 42` commands using glyph data from `EFD1`, `EFE1`,
`EFE2`, `EFCE`, `EFCD`.

Two sub-loops:
- DEF0:0AF9..0B51: inner loop (9 iterations using `EFCE` data)
- DEF0:0BA7..0BFF: inner loop (9 iterations using `EFE2` data)

Final rendering section (DEF0:0BFF..0D25) builds position/bitmap
commands for the `EFCD` glyph segment at two fixed positions
(0x1D, 0x1AE) and (0x11, 0x178).

## Display Script Buffer

All three rendering chains build display command sequences in the
`[18F1]` work buffer (tracked via `[bp-0x102]`). The pattern is:

```asm
mov bx,[bp-0x102]         ; get buffer pointer
mov byte [bx],FF          ; FF prefix
inc word [bp-0x102]
mov byte [bx],42          ; 42 = bitmap blit
inc word [bp-0x102]
mov word [bx],width       ; tile width
add word [bp-0x102],2
mov word [bx],height      ; tile height
add word [bp-0x102],2
mov [bx],offset           ; source data offset
mov [bx+2],segment        ; source data segment
add word [bp-0x102],4
```

When the buffer fills, it's flushed by calling `C000:3F35`:

```asm
lea ax,[bp-0x100]         ; buffer start
mov bx,ss                 ; segment = stack
mov cx,[bp-0x102]         ; current pointer
lea dx,[bp-0x100]
sub cx,dx                 ; CX = byte count
call far C000:3F35        ; render script
```

## Glyph Data Segments

| Segment | Purpose |
| --- | --- |
| `EFCD` | UI element bitmaps (borders, boxes) |
| `EFCE` | Character glyph set A (5x4 tiles) |
| `EFD1` | Character glyph set B |
| `EFE1` | Alternate glyph table |
| `EFE2` | Extended glyph table |
| `EFE3` | Alternate character shapes |
| `EFE6` | Primary glyph table (most referenced) |
| `EFFE` | 15-byte init script (used by `DEF0:0D80`) |

## Block Map (43 blocks)

| Address range | Blocks | Purpose |
| --- | --- | --- |
| `DEF0:01BA..02D2` | 3 | Slot renderer (chain 1) |
| `DEF0:0331..0477` | 2 | Display element builder |
| `DEF0:05E1..0A22` | 10 | Multi-row renderer (chain 2) |
| `DEF0:0A22..0D25` | 8 | Multi-column renderer (chain 3) |
| `DEF0:0D25..0D80` | 7 | Composition entry + page loop |
