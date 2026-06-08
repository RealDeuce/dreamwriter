# Display Stream Renderer

The display script rendering pipeline. `C000:6557` is the core renderer
that processes bytecoded display scripts from ROM. `C000:3F35` is a thin
far-call wrapper around it used by DEF0 and EE17 (136 callers).
`C000:6523` initializes the renderer state (called from the cold boot
path).

Display scripts are binary streams containing positioning commands,
text, and resource references. They are NOT x86 instructions.

### Byte Classification

The renderer at `C000:6557` reads one byte at a time and classifies:

| Byte range | Action |
| --- | --- |
| `0x00..0x1F` | Control — skipped (advance script pointer). |
| `0x20..0xDF` | Character — rendered as a glyph via the character pipeline at `C000:65AA`. |
| `0xE0..0xFE` | Single-byte command — dispatched through the main table at `C000:6865` (slots 0..30). |
| `0xFF` | Extended prefix — slot 31 (`C000:6BAA`), reads the **next byte** as a sub-opcode. |

### Single-Byte Command Table (0xE0..0xFE)

Dispatched through the main table at `C000:6865` (32 word entries).
AL = byte − 0xE0 when the handler is entered. Index = AL, table
lookup via `SI = AL * 2; JMP [CS:SI+6865]`. All 32 bytes
0xE0..0xFF have entries. All except slot 30 consume no additional
bytes from the script.

| Byte | Slot | Handler | Purpose |
| ---: | ---: | --- | --- |
| `0xE0` | 0 | `C000:68A7` | Glyph render: AL=0 → CH=1. Sets glyph source from `[16E3]`, marks `[1729]` bit 5, enters character blit pipeline. |
| `0xE1` | 1 | `C000:68A7` | Glyph render: AL=1 → CH=2. |
| `0xE2` | 2 | `C000:68A7` | Glyph render: AL=2 → CH=3. |
| `0xE3` | 3 | `C000:68A7` | Glyph render: AL=3 → CH=4. |
| `0xE4` | 4 | `C000:68A7` | Glyph render: AL=4 → CH=5. |
| `0xE5` | 5 | `C000:68A5` | Glyph render reset: AL=0 (xor al,al → CH=1). |
| `0xE6` | 6 | `C000:68A5` | Same as slot 5. |
| `0xE7` | 7 | `C000:68D5` | Sequence end. Returns to `C000:6557` (restarts renderer with fresh state from `[172A]`). |
| `0xE8` | 8 | `C000:68D5` | Same as slot 7. |
| `0xE9` | 9 | `C000:68D5` | Same as slot 7. |
| `0xEA` | 10 | `C000:68D5` | Same as slot 7. |
| `0xEB` | 11 | `C000:68D5` | Same as slot 7. |
| `0xEC` | 12 | `C000:68D5` | Same as slot 7. |
| `0xED` | 13 | `C000:68D5` | Same as slot 7. |
| `0xEE` | 14 | `C000:68D5` | Same as slot 7. |
| `0xEF` | 15 | `C000:68D5` | Same as slot 7. |
| `0xF0` | 16 | `C000:68D8` | Set `[1729]` bit 2 — underline on. |
| `0xF1` | 17 | `C000:68DF` | Clear `[1729]` bit 2 — underline off. |
| `0xF2` | 18 | `C000:68E6` | Set `[1729]` bit 3 — bold on. |
| `0xF3` | 19 | `C000:68ED` | Clear `[1729]` bit 3 — bold off. |
| `0xF4` | 20 | `C000:68F4` | Set `[1729]` bit 1, clear `[16E7]` — inverse on. |
| `0xF5` | 21 | `C000:6900` | Clear `[1729]` bit 1, flush glyph buffer — inverse off. |
| `0xF6` | 22 | `C000:6924` | Set `[1729]` bit 4 — strikethrough on. |
| `0xF7` | 23 | `C000:692B` | Clear `[1729]` bit 4 — strikethrough off. |
| `0xF8` | 24 | `C000:6933` | Set `[1728]` bit 0 — superscript on. Reloads glyph source via `C000:6CA7`. |
| `0xF9` | 25 | `C000:693A` | Clear `[1728]` bit 0 — superscript off. Reloads glyph source. |
| `0xFA` | 26 | `C000:6948` | Set `[1729]` bit 0 + `[1728]` bit 1 — subscript on. Reloads glyph source. |
| `0xFB` | 27 | `C000:6954` | Clear `[1729]` bit 0 + `[1728]` bit 1 — subscript off. Reloads glyph source. |
| `0xFC` | 28 | `C000:6960` | Clear `[1729]` bit 0, set `[1728]` bit 1 — alternate sub/super mode. Reloads glyph source. |
| `0xFD` | 29 | `C000:6954` | Same as slot 27 (subscript off). |
| `0xFE` | 30 | `C000:6967` | Spacing: reads 1 extra byte from script → `[1734]` (character spacing value). |
| `0xFF` | 31 | `C000:6BAA` | Extended prefix — reads next byte as sub-opcode (see below). |

### Text Attribute Flags (`[1729]`)

| Bit | Set by | Cleared by | Purpose |
| ---: | --- | --- | --- |
| 0 | `0xF4` (slot 26) | `0xF6`/`0xF8` (slot 27/28) | Subscript. |
| 1 | `0xE8` (slot 20) | `0xEA` (slot 21) | Inverse video. |
| 2 | `0xE0` (slot 16) | `0xE2` (slot 17) | Underline. |
| 3 | `0xE4` (slot 18) | `0xE6` (slot 19) | Bold. |
| 4 | `0xEC` (slot 22) | `0xEE` (slot 23) | Strikethrough. |
| 5 | slots 0-4 | — | Glyph render active. |

### Sub-Opcode Dispatch (after 0xFF)

Slot 31 reads the next byte from `[18A1]` and dispatches:

| Sub-opcode range | Action |
| --- | --- |
| `0x00..0x12` (even only) | Sub-command table at `C000:6BCF` (10 entries, byte-indexed — only even values produce valid word-aligned reads). |
| `0x13..0x3F` | Ignored (returns to main loop). |
| `0x40..0x44` (even only) | Extended command table at `C000:7421` (3 entries, byte-indexed). |
| `0x45+` | Invalid (returns to main loop). |

### Two-Byte Command Summary

AL return value = total bytes consumed (sub-opcode byte + parameter
bytes). The renderer advances `[18A1]` by AL after each handler.

| Command | Handler | AL | Parameters | Purpose |
| --- | --- | ---: | --- | --- |
| `FF 00` | `C000:6BF6` | 1 | (none) | Screen clear. Zeroes framebuffer at `[8000]` (2048 words). |
| `FF 02` | `C000:6C06` | 5 | X:u16, Y:u16 | Text cursor position. Sets `[189F]` (pixel column) and `[189E]` (bit offset) from X; sets `[18A3]` (row base) from Y × `[16DD]` (row height). |
| `FF 04` | `C000:6C91` | 3 | style:u16 | Font/glyph source select. Sets glyph segment `[16E3]` and glyph parameters `[16E5]`/`[16E6]` based on style value. |
| `FF 06` | `C000:6CD7` | 7 | width:u8, height:u8, seg:u16, flags:u16 | Attribute set. Configures character cell dimensions `[16E1]`×`[16DF]`, glyph source segment `[16E3]`, and rendering flags `[172A]`. |
| `FF 08` | `C000:6D79` | 3 | offset:u16 | Horizontal scroll left. Subtracts offset from `[1733]` (pixel X position). If underflow, fills gap with `C000:7324` (rectangle clear), adjusting `[189F]`/`[189E]`. |
| `FF 0A` | `C000:6C27` | 8 | column:u8, X:u16, Y:u16, vscroll:u8, hscroll:u8 | Rendering window setup. Sets column width `[1733]`, calls `C000:6E5A` to compute framebuffer position from X/Y, sets vertical scroll `[1737]` and horizontal scroll `[1739]` from params × row height. |
| `FF 0C` | `C000:6D29` | 10 | X:u16, Y:u16, voffset:u8, width:u16, height:u8, border:u8 | Rectangle with offset. Calls `C000:6E5A` for position, adds voffset × 64 to `[189F]`, draws rectangle via `C000:7324`. |
| `FF 0E` | `C000:6D79` | 3 | offset:u16 | Horizontal scroll left (same handler as `FF 08`). |
| `FF 10` | `C000:6D79` | 3 | offset:u16 | Horizontal scroll left (same handler as `FF 08`). |
| `FF 12` | `C000:6D4F` | 7 | mode:u8 | Display mode select. Sets `[16DF]` (row height: 7 or 8 depending on mode), `[16DD]` (row stride), and `[173B]` (half-width flag). Mode 2 clears `[173C]`. |
| `FF 40` | `C000:7427` | 5 | X:u16, Y:u16 | Position set. Calls `C000:6E55` to compute framebuffer address from X/Y. Clears `[173C]`, `[1733]`, `[1737]`, `[1739]`, `[172C]`. |
| `FF 42` | `C000:7448` | 9 | height:u16, width_bits:u16, offset:u16, segment:u16 | Bitmap blit. Copies `height` rows of `ceil(width_bits/8)` bytes from source `segment:offset` to framebuffer at `ES:DI` with 64-byte row stride, shifting by bit offset `[189E]`. |
| `FF 44` | `C000:755D` | 14 | X:u16, Y:u16, width:u16, height:u16, fill:u16, pattern:u16, border:u8 | Rectangle draw. Calls `C000:6E55` for position. If fill, pattern, and border are all zero, calls `C000:7324` (solid fill). Otherwise dispatches to `C000:71C6` (bordered) or `C000:724D` (patterned). |

## C000:3F35 — Display Script Far Wrapper

The most-called routine in the entire ROM (136 callers, all from DEF0
and EE17). Pushes registers, calls the core renderer, pops, returns via
RETF. Arguments: AX = display page/mode, BX = script source offset,
CX = script length. DX is set by the caller but typically unused here.

```asm
; file 0xC3F35
C000:3F35  55                push bp
C000:3F36  57                push di
C000:3F37  56                push si
C000:3F38  52                push dx
C000:3F39  51                push cx
C000:3F3A  8B D3             mov dx,bx       ; DX = source offset
C000:3F3C  8B F0             mov si,ax       ; SI = page/mode
C000:3F3E  E8 1626           call C000:6557  ; core renderer
C000:3F41  59                pop cx
C000:3F42  5A                pop dx
C000:3F43  5E                pop si
C000:3F44  5F                pop di
C000:3F45  5D                pop bp
C000:3F46  CB                retf
```

## C000:3F47 — Display Script Far Wrapper (Alternate)

Same pattern, slightly different register setup. Also in the far-call
table at `[023C]`.

```asm
; file 0xC3F47
C000:3F47  55                push bp
C000:3F48  57                push di
C000:3F49  56                push si
C000:3F4A  52                push dx
C000:3F4B  51                push cx
C000:3F4C  8B D3             mov dx,bx
C000:3F4E  8B F0             mov si,ax
C000:3F50  8B CB             mov cx,bx
C000:3F52  E8 0226           call C000:6557
C000:3F55  59                pop cx
C000:3F56  5A                pop dx
C000:3F57  5E                pop si
C000:3F58  5F                pop di
C000:3F59  5D                pop bp
C000:3F5A  CB                retf
```

## C000:6557 — Display Script Core Renderer

The actual renderer. Called with:
- SI = display page/mode value
- DX = segment of display script source
- CX = byte count

Copies CX bytes from `DX:SI` to a work buffer at `[1798]`, then
processes the script. The script format uses `FF xx` command opcodes
interspersed with text and positioning data.

```asm
; file 0xC6557
C000:6557  06                push es
C000:6558  BD 0000           mov bp,0
C000:655B  8E C5             mov es,bp
C000:655D  A1 2A17           mov ax,[172A]    ; save current display state
C000:6560  88 26 2817        mov [1728],ah
C000:6564  A2 2917           mov [1729],al
C000:6567  33 C0             xor ax,ax
C000:6569  A0 E516           mov al,[16E5]    ; current drive
C000:656C  E8 3807           call C000:6CA7   ; get display page config
C000:656F  E3 E4             jcxz C000:6555   ; CX=0 -> skip (no script)
C000:6571  89 0E E116        mov [16E1],cx    ; save byte count
C000:6575  BF 9817           mov di,1798      ; work buffer
C000:6578  89 3E A118        mov [18A1],di
C000:657C  8C DD             mov bp,ds
C000:657E  8E DA             mov ds,dx        ; DS = script segment
C000:6580  FC                cld
C000:6581  F3 A4             rep movsb        ; copy script to [1798]
C000:6583  8E DD             mov ds,bp        ; restore DS
```

After copying, the renderer enters a processing loop at `C000:6585`
that reads commands from the work buffer. When it encounters an
`FF` prefix byte, the next byte selects a command via the dispatch
table at `C000:6865`.

### Display Attribute Bytes

| Address | Bit | Set by | Cleared by | Meaning |
| --- | ---: | --- | --- | --- |
| `[1728]` | 0 | `0xF8` (superscript on) | `0xF9` | Superscript. |
| `[1728]` | 1 | `0xFA`/`0xFC` (subscript on) | `0xFB` | Subscript/overtype component. |
| `[1729]` | 0 | `0xFA` (subscript on) | `0xFB`/`0xFC` | Subscript stroke. |
| `[1729]` | 1 | `0xF4` (inverse on) | `0xF5` | Inverse video. |
| `[1729]` | 2 | `0xF0` (underline on) | `0xF1` | Underline. |
| `[1729]` | 3 | `0xF2` (bold on) | `0xF3` | Bold. |
| `[1729]` | 4 | `0xF6` (strikethrough on) | `0xF7` | Strikethrough / double-width. |
| `[1729]` | 5 | slots 0–4 (`0xE0`–`0xE4`) | — | Glyph render active. |

### Blit Helpers

| Address | Purpose |
| --- | --- |
| `C000:6E55` | Position setup from X:u16, Y:u16. Computes `[189F]` and `[189E]`. |
| `C000:6E5A` | Position setup from DX:CX. Calls `C000:6E81`. |
| `C000:6CA7` | Glyph source reconfigure from `[16E5]`. |
| `C000:7324` | Rectangle fill: AL (height) rows of CH-byte width at `ES:DI` with 64-byte stride. |
| `C000:71C6` | Bordered rectangle: bit-aligned fill with border byte. |
| `C000:724D` | Patterned rectangle: fill with pattern data. |

### Callers

- Boot path (`C000:09D4` for "INITIALIZING" banner)
- Startup display (`C000:08E5..0951` for copyright screens)
- Diagnostic banner (`C000:1506` for chord UI)
- Menu scripting engine (via `C772:022D` inline scripts)
- DEF0 service layer (via `C000:3F35` wrapper, 136 call sites)

## Callers Via C000:3F35

The far-call wrapper is called with consistent argument patterns:

```text
MOV AX, page       ; display page number
MOV BX, offset     ; script source offset within segment
MOV CX, length     ; script byte count
CALL FAR C000:3F35
```

The BX values typically point into ROM data regions within the caller's
segment (C772 for app scripts, DEF0 for service scripts, EE17 for
utility scripts). The display script data is NOT x86 code.
