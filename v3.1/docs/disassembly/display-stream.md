# Display Stream Renderer

The display script rendering pipeline. `C000:6557` is the core renderer
that processes bytecoded display scripts from ROM. `C000:3F35` is a thin
far-call wrapper around it used by DEF0 and EE17 (136 callers).
`C000:6523` initializes the renderer state (called from the cold boot
path).

Display scripts are binary streams containing positioning commands,
text, and resource references. They are NOT x86 instructions — the
`FF xx` opcodes within display scripts are display commands, not CPU
instructions.

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

## Display Command Dispatch Table (C000:6865, 32 entries)

The `FF xx` byte pair dispatches through a 32-entry word table.
The second byte (`xx`) is doubled as an index. All handlers return
to the renderer loop at `C000:6585` (or restart the renderer at
`C000:6557`).

### Glyph Setup (slots 0–6)

| Slot | `FF xx` | Handler | Behavior |
| ---: | --- | --- | --- |
| 0–4 | `FF 00`–`FF 08` | `C000:68A7` | Load glyph source from `[16E3]`, set segment `[18A3]=D8C6`, set render flag `[1729]\|=0x20`. If `[16E6]==0x0C`: clear glyph buffer `[16E8]` (32 bytes), enter glyph render at `6A7B`. Otherwise enter text render at `65EF`. |
| 5–6 | `FF 0A`–`FF 0C` | `C000:68A5` | Same as slot 0 but with AL=0 (null glyph). Falls through to `68A7`. |

### Renderer Restart (slots 7–15)

| Slot | `FF xx` | Handler | Behavior |
| ---: | --- | --- | --- |
| 7–15 | `FF 0E`–`FF 1E` | `C000:68D5` | Restart the renderer: `JMP C000:6557`. Effectively reloads the display page configuration. |

### Attribute Flags (slots 16–29)

These handlers set or clear individual bits in the display attribute
bytes `[1729]` and `[1728]`, then return to the renderer loop.

| Slot | `FF xx` | Handler | Effect |
| ---: | --- | --- | --- |
| 16 | `FF 20` | `C000:68D8` | Set `[1729] \|= 0x04` (underline on) |
| 17 | `FF 22` | `C000:68DF` | Clear `[1729] &= ~0x04` (underline off) |
| 18 | `FF 24` | `C000:68E6` | Set `[1729] \|= 0x08` (inverse on) |
| 19 | `FF 26` | `C000:68ED` | Clear `[1729] &= ~0x08` (inverse off) |
| 20 | `FF 28` | `C000:68F4` | Set `[1729] \|= 0x02` (bold on), clear `[16E7]` |
| 21 | `FF 2A` | `C000:6900` | Clear `[1729] &= ~0x02` (bold off), restore glyph source from `[16E7]`, enter render path |
| 22 | `FF 2C` | `C000:6924` | Set `[1729] \|= 0x10` (wide on) |
| 23 | `FF 2E` | `C000:692B` | Clear `[1729] &= ~0x10` (wide off) |
| 24 | `FF 30` | `C000:6933` | Set `[1728] \|= 0x01` (alternate font) |
| 25 | `FF 32` | `C000:693A` | Clear `[1728] &= ~0x01` (default font), reconfigure via `C000:6CA7` |
| 26 | `FF 34` | `C000:6948` | Set `[1729] \|= 0x01`, `[1728] \|= 0x02` (double-strike on) |
| 27 | `FF 36` | `C000:6954` | Clear `[1729] &= ~0x01`, `[1728] &= ~0x02` (double-strike off), reconfigure |
| 28 | `FF 38` | `C000:6960` | Clear `[1729] &= ~0x01`, set `[1728] \|= 0x02` (partial double-strike) |
| 29 | `FF 3A` | `C000:6954` | Same as slot 27 (double-strike off) |

### Data Commands (slots 30–31)

| Slot | `FF xx` | Handler | Behavior |
| ---: | --- | --- | --- |
| 30 | `FF 3C` | `C000:6967` | Read pixel shift value. Decrements `[16E1]` (byte count), reads next byte from `[18A1]` (script pointer), stores to `[1734]`. If `[173B]!=0`, shifts right by 2. If nonzero, sets `[172C]\|=0x08`. |
| 31 | `FF 3E` | `C000:6BAA` | Bitmap blit. Reads next byte from `[18A1]`, dispatches on value: if `>=0x40` enters the extended blit path at `C000:7409`, otherwise processes as a glyph index with direct pixel blitting to the display buffer via `[189F]` (pixel column) and `[189E]` (bit offset). |

### Display Attribute Bytes

| Address | Bit | Meaning |
| --- | --- | --- |
| `[1728]` | bit 0 | Alternate font |
| `[1728]` | bit 1 | Double-strike component |
| `[1729]` | bit 0 | Strike-through |
| `[1729]` | bit 1 | Bold |
| `[1729]` | bit 2 | Underline |
| `[1729]` | bit 3 | Inverse |
| `[1729]` | bit 4 | Wide (double-width) |
| `[1729]` | bit 5 | Glyph render active |

The renderer is called from:
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
