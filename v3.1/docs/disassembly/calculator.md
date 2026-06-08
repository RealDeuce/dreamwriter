# Calculator Application

The organizer calculator, entered from `DEF0:5C2E` when the user
selects CALCULATOR (item 0x31) from the organizer menu.

Entry point: `EE17:16CA`. Returns via RETF when the user exits.

## Entry Flow (EE17:16CA)

```text
1. DEF0:0D80           clear display
2. DEF0:0DF5(8,1B,189,25,push 2)  draw main frame (FF 44 rectangle)
3. DEF0:0DF5(7B,1,E6,14,push 1)   draw number display area (FF 44)
4. [A3A2]=0x0C, [A3A3]=0x0D       set display parameters
5. EE17:0047(A348)     clear register A
6. EE17:0047(A35A)     clear register B
7. [A342]=0            clear error/overflow flag
8. EE17:03DE(AX=0)     draw number display
9. EE17:07FE           draw calculator panel
10. [1107]=1           set calculator-active flag
11. EE17:103B          key processing loop (blocks until exit)
12. [1107]=0           clear calculator-active flag
13. return
```

## Register Structure

Each register is 18 bytes (0x12):

```text
[+0x00]       sign/active flag (0=positive/empty)
[+0x01..0x0E] 14 digit bytes (BCD, MSD first)
[+0x0F]       rounding digit
[+0x10]       unused
[+0x11]       decimal position (0=integer, N=N decimal places)
```

| Name | Address | Purpose |
| --- | --- | --- |
| Register A | `[A348..A359]` | Current entry / operand A |
| Register B | `[A35A..A36B]` | Previous entry / operand B |
| Panel reg | `[A37E..A38F]` | Panel display value |
| Scratch | `[A390..A3A1]` | Arithmetic scratch |

## State Variables

| Address | Purpose |
| --- | --- |
| `[A342]` | Error/overflow flag (0=normal, 1=overflow) |
| `[A344]` | Pending operator (1=add, 2=sub, 3=mul, 4=div, 0x32=equals) |
| `[A346]` | Display operator |
| `[A3A2]` | Display parameter A (set to 0x0C) |
| `[A3A3]` | Display parameter B (set to 0x0D) |
| `[1107]` | Calculator active flag |

## EE17:0047 — Clear Register

Zeroes all 18 bytes of a register. AX = register base address.

```asm
EE17:0047  mov bx,ax
EE17:0049  mov byte [bx],0x0      ; clear sign
EE17:004C  mov byte [bx+0x11],0x0 ; clear decimal position
EE17:0050  inc bx                 ; point to digit area
EE17:0051  xor ax,ax
loop: mov byte [bx],0x0           ; clear each digit
      inc bx
      cmp ax,0x10                 ; 16 bytes
      jl loop
EE17:005F  retf
```

## EE17:03DE — Draw Number Display

Called with AX = rounding mode (0=round, nonzero=raw).

1. Renders `FF 40` position command from F24A:000E (position 0x21, 0x14).
2. Copies 14 digits from register A `[A349..A356]` to local buffer.
3. If AX=0: applies rounding from `[A357]` (BCD round-up carry chain).
4. Falls through to the number rendering chain (leading-zero
   suppression at EE17:00B2, digit rendering at EE17:00FD/01E8).

### Display Script Sources

- `F24A:000E` (file `0xF24AE`, 6 bytes): `FF 40 21 00 14 00` —
  positions cursor at (0x21, 0x14) for the number display area.

## EE17:07FE — Draw Calculator Panel

1. Renders `FF 40` position from F24B:0004 (position 5, 0x90).
2. Calls `EE17:0060(AX=A37E)` to format and display the panel
   register value.

### Display Script Sources

- `F24B:0004` (file `0xF24B4`, 6 bytes): `FF 40 05 00 90 00` —
  positions cursor at (5, 0x90) for the panel area.

## EE17:0060 — Format and Display Number

Called with AX = register pointer. Copies the register digits to a
local buffer at `[bp-0x10]`, applies rounding if needed, then enters
the number rendering pipeline (leading-zero suppression and digit
blit loop).

## EE17:076E — Key Prompt Display

Builds a display script in RAM at `[18F1]` with `FF 02` (text
cursor position) commands. Renders the operator indicator and
status line. Calls `C000:3F35` to render.

## EE17:103B — Key Processing Loop

Main calculator loop. Initializes state, then loops:

1. If `[A342]!=0` (overflow): redraw panel (`EE17:07FE`), redraw
   menu bar (`EE17:0009`).
2. `EE17:076E` — display key prompt.
3. `DEF0:0043` — read key.
4. Dispatch on key code.

### Key Dispatch

| Key | Code | Handler | Action |
| --- | --- | --- | --- |
| CANCEL | `0x02`/`0x03` | return 0 | Exit calculator. |
| EXIT | `0x0B` | return 1 | Exit calculator. |
| C (clear all) | `0x08` | `EE17:10A0` | Clear both registers, redraw. |
| CE (clear entry) | `0x0D` | `EE17:10E3` | Clear register A, redraw. |
| + | `[C000:3ACF]`/`[C000:3AD0]` | `EE17:1103` | Set operator=1 (add). |
| − | `[C000:3AD1]`/`[C000:3AD2]` | `EE17:114B` | Set operator=2 (subtract). |
| × | `[C000:3AD3]`/`[C000:3AD4]` | `EE17:1193` | Set operator=3 (multiply). |
| ÷ | `[C000:3AD5]`/`[C000:3AD6]` | `EE17:11DB` | Set operator=4 (divide). |
| = | `0xDA` | `EE17:1223` | Compute result. |
| % | — | `EE17:1247` | Percentage. |
| M+ | — | `EE17:12B2` | Memory add. |
| M− | — | `EE17:1316` | Memory subtract. |
| MR | — | `EE17:137A` | Memory recall. |
| MC | — | `EE17:13C8` | Memory clear. |
| √ | — | `EE17:1411` | Square root. |
| ± | — | `EE17:145D` | Sign change. |
| . | — | `EE17:1494` | Decimal point. |
| 0−9 | — | `EE17:14FA..164C` | Digit entry (10 handlers). |

Operator keys are looked up from the keyboard translation table at
`C000:3ACF..3AD6` (4 pairs: +, −, ×, ÷ with two key codes each).

### Operator Apply (EE17:0E9E)

Called when an operator key is pressed (after saving the current
value via `EE17:0A78`). Dispatches on `[A344]`:

| `[A344]` | Handler | Operation |
| ---: | --- | --- |
| 1 | `EE17:0BA0(A35A, A348)` | Add: B = B + A |
| 2 | `EE17:0C87(A35A, A348)` | Subtract: B = B − A |
| 3 | `EE17:0CB3(A35A, A348)` | Multiply: B = B × A |
| 4 | `EE17:0D9E(A35A, A348)` | Divide: B = B ÷ A |

After each operation, copies result from A348 to A35A via
`EE17:08AD`.

### Equals (EE17:0F54)

Applies the pending operator (same dispatch as 0E9E), then
displays the result via `EE17:03DE`. Sets `[A344]=0x32`.

## Arithmetic Functions

| Address | Purpose | Called with |
| --- | --- | --- |
| `EE17:0A78` | Register copy / normalize | AX=register |
| `EE17:08AD` | Register copy (A→B) | AX=src, BX=dst |
| `EE17:0817` | Digit shift left | AX=register |
| `EE17:087A` | BCD digit operations | AX=register |
| `EE17:0BA0` | BCD addition | AX=dst, BX=src |
| `EE17:0C87` | BCD subtraction | AX=dst, BX=src |
| `EE17:0CB3` | BCD multiplication | AX=dst, BX=src |
| `EE17:0D9E` | BCD division | AX=dst, BX=src |

All check `[A342]` (overflow flag) and skip if already in error.
The scratch register at `[A390]` is used for intermediate results
during multiplication and division.

## Large Digit Glyphs (F6A7 Segment)

The main number display uses 16×25 pixel digit bitmaps from segment
`F6A7` (file `0xF6A70`). Each glyph is 50 bytes (0x32): 25 rows ×
2 bytes/row. Source offset computed by EE17:0642:

```text
offset = 0x0C + digit_value × 0x32
```

FF 42 parameters: height=0x19 (25), width=0x10 (16) for full-width
digits; width=0x08 (8) for half-width (decimal point, separator).

| Index | File offset | Source | Purpose | Image |
| ---: | ---: | --- | --- | --- |
| 0 | `0xF6A7C` | `F6A7:000C` | Digit 0 | ![](images/calc-digit-0-0xF6A7C.png) |
| 1 | `0xF6AAE` | `F6A7:003E` | Digit 1 | ![](images/calc-digit-1-0xF6AAE.png) |
| 2 | `0xF6AE0` | `F6A7:0070` | Digit 2 | ![](images/calc-digit-2-0xF6AE0.png) |
| 3 | `0xF6B12` | `F6A7:00A2` | Digit 3 | ![](images/calc-digit-3-0xF6B12.png) |
| 4 | `0xF6B44` | `F6A7:00D4` | Digit 4 | ![](images/calc-digit-4-0xF6B44.png) |
| 5 | `0xF6B76` | `F6A7:0106` | Digit 5 | ![](images/calc-digit-5-0xF6B76.png) |
| 6 | `0xF6BA8` | `F6A7:0138` | Digit 6 | ![](images/calc-digit-6-0xF6BA8.png) |
| 7 | `0xF6BDA` | `F6A7:016A` | Digit 7 | ![](images/calc-digit-7-0xF6BDA.png) |
| 8 | `0xF6C0C` | `F6A7:019C` | Digit 8 | ![](images/calc-digit-8-0xF6C0C.png) |
| 9 | `0xF6C3E` | `F6A7:01CE` | Digit 9 | ![](images/calc-digit-9-0xF6C3E.png) |
| 11 | `0xF6CA2` | `F6A7:0232` | Blank (leading zero fill) | ![](images/calc-blank-0xF6CA2.png) |
| 12 | `0xF6CD4` | `F6A7:0264` | Decimal point `.` (`[A3A2]`) | ![](images/calc-decimal-0xF6CD4.png) |
| 13 | `0xF6D06` | `F6A7:0296` | Thousands separator `,` (`[A3A3]`) | ![](images/calc-separator-0xF6D06.png) |
| 14 | `0xF6D38` | `F6A7:02C8` | Minus sign `−` (negative indicator) | ![](images/calc-minus-0xF6D38.png) |

The decimal point glyph index is stored in `[A3A2]` (set to 0x0C
at init). The thousands separator glyph index is stored in `[A3A3]`
(set to 0x0D). At EE17:065F, when the current position matches
the decimal position (DI), the code falls through to EE17:0664
which reads `[A3A2]` to render the decimal point. When positions
don't match, EE17:06B1 reads `[A3A3]` for the thousands separator.
The minus sign at `F6A7:02C8` is used when `[A348]!=0` (negative
number, EE17:0568).

## Small Digit Glyphs (F325 Segment)

The panel display area uses smaller glyphs from segment `F325`
(file `0xF3250`). Stride = 13 (0x0D), base offset = 2 (0x02).
Offset = `2 + glyph_index × 13`. FF 42 parameters: height=0x0D
(13), width=0x07 (7) for digits, width=0x05 (5) for separators.

| Index | File offset | Source | Purpose | Image |
| ---: | ---: | --- | --- | --- |
| 0 | `0xF3252` | `F325:0002` | Digit 0 | ![](images/calc-sm-digit-0-0xF3252.png) |
| 1 | `0xF325F` | `F325:000F` | Digit 1 | ![](images/calc-sm-digit-1-0xF325F.png) |
| 2 | `0xF326C` | `F325:001C` | Digit 2 | ![](images/calc-sm-digit-2-0xF326C.png) |
| 3 | `0xF3279` | `F325:0029` | Digit 3 | ![](images/calc-sm-digit-3-0xF3279.png) |
| 4 | `0xF3286` | `F325:0036` | Digit 4 | ![](images/calc-sm-digit-4-0xF3286.png) |
| 5 | `0xF3293` | `F325:0043` | Digit 5 | ![](images/calc-sm-digit-5-0xF3293.png) |
| 6 | `0xF32A0` | `F325:0050` | Digit 6 | ![](images/calc-sm-digit-6-0xF32A0.png) |
| 7 | `0xF32AD` | `F325:005D` | Digit 7 | ![](images/calc-sm-digit-7-0xF32AD.png) |
| 8 | `0xF32BA` | `F325:006A` | Digit 8 | ![](images/calc-sm-digit-8-0xF32BA.png) |
| 9 | `0xF32C7` | `F325:0077` | Digit 9 | ![](images/calc-sm-digit-9-0xF32C7.png) |
| 10 | `0xF32D4` | `F325:0084` | Colon `:` | ![](images/calc-sm-glyph-10-0xF32D4.png) |
| 11 | `0xF32E1` | `F325:0091` | Blank | ![](images/calc-sm-glyph-11-0xF32E1.png) |
| 12 | `0xF32EE` | `F325:009E` | Decimal point `.` | ![](images/calc-sm-glyph-12-0xF32EE.png) |
| 13 | `0xF32FB` | `F325:00AB` | Thousands separator `,` | ![](images/calc-sm-glyph-13-0xF32FB.png) |
| 14 | `0xF3308` | `F325:00B8` | Minus `−` | ![](images/calc-sm-glyph-14-0xF3308.png) |
| 15 | `0xF3315` | `F325:00C5` | Blank (alt) | ![](images/calc-sm-glyph-15-0xF3315.png) |

The hardcoded offsets in the rendering code correspond to:
- `F325:0091` (index 11): blank glyph for leading-zero fill.
- `F325:00B8` (index 14): minus sign for negative indicator.

## Error Messages

Four 24-byte padded strings at `F24C:0009` (file `0xF24C9`),
displayed when `[A342]!=0` (overflow/error state):

| Index | File offset | Text |
| ---: | ---: | --- |
| 0 | `0xF24C9` | `OVERFLOW` |
| 1 | `0xF24E1` | `DIVISION BY ZERO` |
| 2 | `0xF24F9` | `OUT OF RANGE` |
| 3 | `0xF2511` | `UNKNOWN ERROR` |

## Display Frames

The entry code draws two `FF 44` rectangles via `DEF0:0DF5`:

| Call | X | Y | Width | Height | Purpose |
| --- | ---: | ---: | ---: | ---: | --- |
| 1st | 0x1B | 0x08 | 2 | 0x189 | Main calculator frame (tall border). |
| 2nd | 0x01 | 0x7B | 1 | 0xE6 | Number display area (inner panel). |

## Display Script Sources

| Address | File | Length | Purpose |
| --- | ---: | ---: | --- |
| `F24A:000E` | `0xF24AE` | 6 | `FF 40` position (0x21, 0x14) — number display area cursor. |
| `F24B:0004` | `0xF24B4` | 6 | `FF 40` position (5, 0x90) — panel area cursor. |
| `F24B:000A` | `0xF24BA` | 15 | `FF 06` attribute — sets glyph rendering parameters (shared with other organizer apps). |
| `F24C:0009` | `0xF24C9` | 96 | Error message strings (4 × 24 bytes). |
