# Diagnostic Application

The built-in diagnostic mode, entered by holding **F + J + SPACE**
during boot. Detected by `C000:14E6` (matrix compare against the
chord pattern at `C000:14FC`). See
[`diagnostic-keyboard-check.md`](diagnostic-keyboard-check.md) for
the chord detection and entry gate.

The diagnostic banner at `C772:005D` (265 bytes) identifies the
build as **Diagnostic 31BAB218, 98Jun21**.

## Entry Path

```text
Boot → C000:0AA0 → C000:14D4 → chord match?
  no  → return (normal boot)
  yes → C000:1506 (render banner)
      → C000:1523 (command loop)
      → loop until exit
      → set [146F]=0x1995 (battery warning marker)
```

## Display Script Data

The diagnostic renders from `C772:005D` with two different lengths:

| Caller | Offset | Length | Content |
| --- | ---: | ---: | --- |
| `C000:1506` | `C772:005D` | `0x45` (69) | Banner only: build ID and `K: Keyboard check`. |
| `C000:19A0` | `C772:005D` | `0x109` (265) | Full help: banner + all command descriptions. |

### Full Help Screen Text

```text
Diagnostic 31BAB218       98Jun21       K: Keyboard check
Mxxxx:yyyy     dump Memory
Sxxxx:yyyy,zz  Set memory
Y,Zxxxx:yyyy   Single step
Iyyyy  dump I/O, O(ut)ppH,bbH, L=dump I/O(alarm)
T=Card ATTR, N=COM, Q/R=Clear/Reset spell
```

Display script structure: `FF 00` (clear), `FF 04` (font select),
then six `FF 02` (text cursor position) commands at lines 0, 4, 6,
8, 10, 12 followed by ASCII text.

## C000:1523 — Top-Level Command Loop

Clears flag `[143C] bit 3`, initializes state via `C000:18B3`, then
loops reading keys via `DEF0:0019` (AX=1) and `C000:0A69`
(translate). Passes the key to `C000:18CC` for character
accumulation.

```text
Key dispatch:
  0x01       → C000:1571  cold reset (JMP C000:0029)
  0x00       → loop (no key)
  0x0B/02/03 → exit (STC, RET)
  0x3F '?'   → C000:19A0  show full help screen
  0x4B 'K'   → C000:1569  keyboard check mode
  0x6B 'k'   → C000:1569  keyboard check mode (lowercase)
  0xDA       → C000:15C3  command line entry
  other      → C000:1929  echo character to display
```

### C000:18B3 — Init State

Clears the command state variables:

```asm
C000:18B3  mov word [15A5], 0x0000    ; segment = 0
C000:18B9  mov word [15A3], 0x1006    ; buffer pointer
C000:18BF  mov bx, [15A3]
C000:18C3  mov byte [bx], 0x00       ; clear buffer
C000:18C6  mov byte [15A9], 0x4D     ; default command = 'M'
```

### C000:1929 — Character Echo

Echoes printable characters (0x20..0xCF) to the display via
`DEF0:0035`. Backspace (0x08) sends backspace + space + backspace
(visual erase).

## C000:15C3 — Command Line Entry (0xDA Handler)

Entered when the user presses ENTER (key code 0xDA). Sends CR/LF
via `C000:196D` (calls `DEF0:0035` with 0x0D then 0x0A), then
reads the command buffer at `[0x1006]`.

### Command Character Dispatch

Reads the first character from the buffer, converts to uppercase
(`AND AL, 0xDF`), and dispatches:

| Key | Code | Handler | Purpose |
| --- | ---: | --- | --- |
| DA | `0xDA` | `C000:157C` | Empty line → return AL=0x0B |
| M | `0x4D` | `C000:1586` | Set command code, read address |
| I | `0x49` | `C000:1586` | Set command code, read address |
| L | `0x4C` | `C000:1580` | OUT 0xDD,0xF9 then set code `L` |
| S | `0x53` | `C000:1586` | Set command code, read address |
| O | `0x4F` | `C000:1586` | Set command code, read address |
| P | `0x50` | `C000:159A` | Bank remap: port 0x13/0x14 custom |
| Q | `0x51` | `C000:158C` | Bank switch via `C000:1B4F` |
| R | `0x52` | `C000:1595` | Bank remap via `C000:18A5` (ports 0x13=3, 0x14=2) |
| Y | `0x59` | `C000:1586` | Set command code, single-step |
| Z | `0x5A` | `C000:1586` | Set command code, single-step |
| T | `0x54` | `C000:15B7` | Card ATTR read |
| N | `0x4E` | `C000:15B0` | COM/serial config |
| 0-9,A-F | — | hex accumulator | Build DX address value |

### Hex Address Parsing

After the command letter, remaining characters are parsed as hex
digits. Each digit shifts DX left by 4 and ORs in the value:

```asm
C000:161C  shl dx, cl          ; CL=4
C000:161E  or dx, ax           ; AX = hex digit value
C000:1620  mov al, [bx]        ; next character
C000:1622  cmp al, 0xDA        ; end of input?
C000:1624  jz 0x1648           ; yes → execute command
```

Characters `A-F` are converted via `SUB AL, 0x37`; digits `0-9`
via `AND AL, 0x0F`.

## Command Execution

After parsing, `[15A9]` holds the command code and DX holds the
address. Dispatch at `C000:1648`:

### M — Memory Dump

Default command. Dumps 7 lines of 16 bytes from `[15A5]:[15A7]`
(segment:offset parsed from `xxxx:yyyy`). Each line shows the
segment:offset, 16 hex bytes separated by spaces, then loops.

```text
C000:16BE  mov dx, 7           ; 7 lines
C000:16D0  mov bx, [15A5]      ; segment
C000:16D4  call C000:18FA      ; display hex word
C000:16D7  mov al, ':'
C000:16D9  call C000:1929      ; echo ':'
C000:16DC  mov bx, [15A7]      ; offset
C000:16E0  call C000:18FA      ; display hex word
```

Reads memory using `DS:[15A5]` as the segment (pushed to DS
temporarily). After each line, advances `[15A7]` by 16.

### S — Set Memory

Writes DX (the parsed `zz` value) to `[15A5]:[15A7]`:

```asm
C000:169B  mov di, [15A7]      ; offset
C000:169F  mov si, [15A5]      ; segment
C000:16A3  push ds
C000:16A4  mov ds, si
C000:16A6  mov [di], dl        ; write byte
C000:16A8  pop ds
C000:16A9  mov byte [15A9], 'M' ; switch to dump mode
```

After writing, switches to M (dump) so the next ENTER shows the
result.

### I — Dump I/O Port

Reads from I/O port at `[15A7]` and displays the value. Skips the
segment display (no `xxxx:` prefix). Uses `IN AL, DX` to read.

### O — Output to I/O Port

Writes DL to I/O port at `[15A7]`:

```asm
C000:168C  mov al, dl          ; value to write
C000:168E  mov dx, [15A7]      ; port address
C000:1692  out dx, al          ; write to port
```

### L — Dump I/O (Alarm Ports)

Sets `[15A7]=0xD0` (RTC alarm port base), then falls through to
the I/O dump path. Reads 1 byte from port 0xD0.

### Y, Z — Single Step

Sets `[15AE]` flag (Y sets to 1, Z leaves at 0), stores the address
in `[15A7]` and `[15AA]`, then renders a step display via
`C000:17AF`. The step display shows the current `[15A5]:[15A7]`
address and the instruction at that location.

### P — Bank Remap (Custom)

Sets `[15A9]=0x50`, then maps custom bank values:

```asm
C000:159A  mov byte [15A9], 0x50
C000:159F  mov dx, 0x2B00
C000:15A2  mov [15A7], dx      ; store parsed port value
```

### Q — Bank Switch (Via C000:1B4F)

Calls `C000:1B4F` (thunk B slot 4/5 handler) to switch banks,
then continues to command input.

### R — Bank Remap (Spell Check Banks)

Calls `C000:18A5` which writes port `0x13=0x03`, `0x14=0x02`.
This maps ROM bank 12 (file 0x80000) to CPU window 3 and bank 13
(file 0xA0000) to window 4 — the spell check dictionary banks.

### T — Card ATTR

Reads PCMCIA card attribute memory. Handler at `C000:15B7`.

### N — COM/Serial

Configures or reads the serial (COM) port. Handler at `C000:15B0`.

## C000:1569 — Keyboard Check Mode ('K')

Called via `C000:195B`. Sets `[143C] bit 0`, calls `DEF0:0D25`
(keyboard check UI), clears the flag. On return, re-renders the
diagnostic banner via `C000:1506` and re-enters `C000:1523`.

### DEF0:0D25 — Keyboard Check UI

Draws a full keyboard layout on the LCD display. The user presses
each key; when pressed, the key is highlighted. The test completes
when all 64 keys have been pressed (`CX == 0x40`).

The display has three sections (left to right):

1. **Keyboard layout** — full-size key outlines with character labels.
2. **Keyboard matrix** — 8×10 (Out × In) scan grid with indicators.
3. **Connector pinout** — physical connector pin diagram.

**Init phase** (DEF0:0D25..0D45):
1. `DEF0:0D80` — clear display.
2. Loop SI = 0..63: `DEF0:01BA(SI)` — draw keyboard layout (left section).
3. Clear pressed-state array at `[BP-0x40]` (64 bytes, one per key).
4. `DEF0:05E1` — draw keyboard matrix grid (middle section).
5. `DEF0:0A22` — draw connector pinout diagram (right section).

**Scan loop** (DEF0:0D4F..0D75):
1. `C000:194B` — read key index (returns 1..64 in AX).
2. Decrement to 0-based, bounds-check 0..63.
3. If not yet pressed (`[BP+SI-0x40] == 0`):
   - Mark pressed (`[BP+SI-0x40] = 1`).
   - `DEF0:0331(SI)` — redraw key in highlighted state.
   - Increment CX.
4. Loop until `CX == 0x40` (all 64 keys pressed).

### Display Rendering Functions

**DEF0:01BA** — Individual key renderer. Looks up key geometry
from a 6-byte record table in glyph segment `EFE6` at offset
`0x08 + key_index * 6`:

```text
EFE6:[8 + i*6 + 0]  byte  key class/type
EFE6:[8 + i*6 + 1]  byte  Y position
EFE6:[8 + i*6 + 2]  word  X position
EFE6:[8 + i*6 + 4]  word  (used for width lookup)
```

Then reads glyph shape from segment `EFE3` at offset
`0x02 + class * 6`. Builds `FF 40` (position) + `FF 42` (bitmap
blit, height=12) commands and renders via `C000:3F35`.

**DEF0:05E1** — Keyboard frame renderer. Loops over 64 keys,
drawing each as:
- `FF 44` rectangle (7×0xE6 pixels, at Y = `SI * 7 + 3`, X = 1)
  with fill=0, border=0x0F.
- `FF 40` position + `FF 42` bitmap blit (5×4 pixels) from glyph
  segment `EFCE` at offset `0x08 + SI * 5`.

**DEF0:0A22** — Title area renderer. Draws the keyboard check
title bar with `FF 40` + `FF 42` commands.

**DEF0:0331** — Key press handler. Draws three elements when a
key is pressed:

1. `FF 44` filled rectangle over the keyboard layout key (highlight).
   Position from `EFE6:[+1]`/`[+2]`, size from `EFE6:[+4]` width
   lookup via `EFE3`, height 10 (0x0A). Fill=0, border=0x0A.

2. `FF 44` 13×13 rectangle at the key position + (0x0B, 0x05) —
   a pressed-state marker inside the key outline.

3. `FF 44` **5×5 filled rectangle** at the matrix grid intersection.
   Row = `EFE6:[+4] >> 4`, column = `EFE6:[+4] & 0x0F`.
   Position: Y = `row * 7 + 1`, X = `col * 12 + 0xED`.
   Fill=0, border=0x0F.

**DEF0:02D2** — ISO Enter key renderer. Second branch of
`DEF0:01BA`, reached for key class 8. Draws a 25×19 bitmap
(FF 42: height=0x19, width=0x13) from `EFC8:0006` (file
`0xEFC86`). This is the L-shaped ISO Enter keycap.

![ISO Enter](images/diagnostic-key-iso-enter-0xEFC86.png)

### Glyph Segments Used

| Segment | Physical base | Used by | Purpose |
| --- | ---: | --- | --- |
| `EFE6` | `0xEFE60` | `DEF0:01BA`, `DEF0:0331` | Key geometry table (6 bytes/key, 64 keys at offset 8). |
| `EFE3` | `0xEFE30` | `DEF0:01BA`, `DEF0:0331` | Key shape table (9 classes, 6 bytes each). |
| `EFCE` | `0xEFCE0` | `DEF0:05E1` | Matrix grid labels (4×5 pixels, 5 bytes each at offset 8). |
| `EFB1`..`EFC8` | `0xEFB10`..`0xEFC80` | `DEF0:01BA` | Key shape bitmaps (12px tall, variable width). |

### EFE3 Key Shape Table

9 classes at `EFE3:0000`, 6 bytes each: `(bitmap_offset:u16,
bitmap_segment:u16, width_base:u16)`. Bitmap height is hardcoded
to 12 (DEF0:0258). Display width = `width_base + 2`.

| Class | File offset | Segment:Offset | Width | Notes | Image |
| ---: | ---: | --- | ---: | --- | --- |
| 0 | `0xEFB1E` | `EFB1:000E` | 12 | Standard key | ![](images/diagnostic-key-class0-0xEFB1E.png) |
| 1 | `0xEFB36` | `EFB3:0006` | 12 | Standard key (alt) | ![](images/diagnostic-key-class1-0xEFB36.png) |
| 2 | `0xEFB4E` | `EFB4:000E` | 12 | Standard key (alt 2) | ![](images/diagnostic-key-class2-0xEFB4E.png) |
| 3 | `0xEFB66` | `EFB6:0006` | 18 | Wide key | ![](images/diagnostic-key-class3-0xEFB66.png) |
| 4 | `0xEFB8A` | `EFB8:000A` | 22 | Wider key | ![](images/diagnostic-key-class4-0xEFB8A.png) |
| 5 | `0xEFBAE` | `EFBA:000E` | 25 | Extra-wide key | ![](images/diagnostic-key-class5-0xEFBAE.png) |
| 6 | `0xEFBDE` | `EFBD:000E` | 28 | Double-wide key | ![](images/diagnostic-key-class6-0xEFBDE.png) |
| 7 | `0xEFC0E` | `EFC0:000E` | 77 | Spacebar | ![](images/diagnostic-key-class7-0xEFC0E.png) |
| 8 | `0xEFC86` | `EFC8:0006` | 19 | ISO Enter key (class table says 12px tall, but DEF0:02D2 renders 25×19 for the full L-shape). | ![](images/diagnostic-key-iso-enter-0xEFC86.png) |

### EFCE Digit Glyphs

Small digit/character glyphs at `EFCE:0008`, 5 bytes each (FF 42:
height=5, width=4). Used as labels by:

- `DEF0:05E1` — matrix grid row/column labels (middle section).
- `DEF0:0A22` — connector pin number labels (right section),
  indexed via `EFE1` (In pins) and `EFE2` (Out pins).

| Index | File offset | Image |
| ---: | ---: | --- |
| 0 | `0xEFCE8` | ![](images/diagnostic-keycap-0-0xEFCE8.png) |
| 1 | `0xEFCED` | ![](images/diagnostic-keycap-1-0xEFCED.png) |
| 2 | `0xEFCF2` | ![](images/diagnostic-keycap-2-0xEFCF2.png) |
| 3 | `0xEFCF7` | ![](images/diagnostic-keycap-3-0xEFCF7.png) |
| 4 | `0xEFCFC` | ![](images/diagnostic-keycap-4-0xEFCFC.png) |
| 5 | `0xEFD01` | ![](images/diagnostic-keycap-5-0xEFD01.png) |
| 6 | `0xEFD06` | ![](images/diagnostic-keycap-6-0xEFD06.png) |
| 7 | `0xEFD0B` | ![](images/diagnostic-keycap-7-0xEFD0B.png) |
| 8 | `0xEFD10` | ![](images/diagnostic-keycap-8-0xEFD10.png) |
| 9 | `0xEFD15` | ![](images/diagnostic-keycap-9-0xEFD15.png) |

## C000:1571 — Cold Reset (Key 0x01)

Calls `C000:0571` (subsystem shutdown), sets `[1447]=0x55` (reinit
marker), and jumps to `C000:0029` (cold boot entry).

## State Variables

| Address | Purpose |
| --- | --- |
| `[1006]` | Command input buffer |
| `[143C]` | Diagnostic flags (bit 0: keyboard check, bit 3: diagnostic active) |
| `[1447]` | Reinit marker (0x55 triggers full cold init) |
| `[146F]` | Set to 0x1995 after diagnostic exit (battery warning state) |
| `[15A3]` | Buffer pointer (init to 0x1006) |
| `[15A5]` | Current segment for M/S commands |
| `[15A7]` | Current offset for M/S/I/O commands |
| `[15A9]` | Current command code (default 'M' = 0x4D) |
| `[15AA]` | Saved offset for Y/Z step |
| `[15AC]` | Saved segment for Y/Z step |
| `[15AE]` | Single-step flag (0=Z step, 1=Y step) |

### DEF0:0A22 — Connector Pinout Diagram (Right Section)

Renders the physical keyboard connector pin layout.

**Connector image**: FF 42 height=20 (0x14), width=102 (0x66),
source `EFD1:000A` (file `0xEFD1A`, 260 bytes). Shows the two
connector halves with pin outlines.

![connector](images/diagnostic-connector-0xEFD1A.png)

**"In" pin labels** (10 iterations): reads pin order from `EFE1`
at offset `0x0E` — bytes `00 03 04 05 02 01 06 07 08 09` — then
indexes into `EFCE` digit glyphs. Renders as "0345216789".

**"Out" pin labels** (9 iterations): reads pin order from `EFE2`
at offset `0x08` — bytes `00 02 03 04 06 07 05 01 00` — then
indexes into `EFCE` digit glyphs. Renders as "023467510".

**"In" / "Out" text labels**: FF 42 from `EFCD`:

| File offset | Source | Dimensions | Image |
| ---: | --- | --- | --- |
| `0xEFCD8` | `EFCD:0008` | 8×5 | ![In](images/diagnostic-label-in-0xEFCD8.png) |
| `0xEFCDE` | `EFCD:000E` | 12×5 | ![Out](images/diagnostic-label-out-0xEFCDE.png) |

### Glyph Segment Index Tables

| Segment | Offset | Entries | Purpose |
| --- | ---: | ---: | --- |
| `EFE1` | `+0x0E` | 10 bytes | In pin → EFCE glyph index. Order: 0,3,4,5,2,1,6,7,8,9. |
| `EFE2` | `+0x08` | 9 bytes | Out pin → EFCE glyph index. Order: 0,2,3,4,6,7,5,1,0. |

## Related Docs

- [`diagnostic-keyboard-check.md`](diagnostic-keyboard-check.md) — chord detection and entry gate
- [`diagnostic-monitor.md`](diagnostic-monitor.md) — serial terminal monitor (thunk B slot 7)
