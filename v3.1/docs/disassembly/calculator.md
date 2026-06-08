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

## Digit Glyphs

The number display uses two bitmap sizes from segment `F325`
(file `0xF3250`):

- **7×13** (FF 42: height=0x0D, width=0x07, 1 byte/row): main
  digit glyphs for the number display. Source offsets computed
  at runtime from digit values.
- **5×13** (FF 42: height=0x0D, width=0x05, 1 byte/row): narrow
  glyphs (decimal point, operators).

Fixed offsets used:
- `F325:0091` (file `0xF32E1`): blank/space glyph (leading zero fill).
- `F325:00B8` (file `0xF3308`): active digit position marker.

The `F6A7` segment (file `0xF6A70`) is referenced from the
large-digit display functions at `EE17:0518`/`05F9`, containing
a 6-word table followed by larger glyph data.

## Display Script Sources Summary

| Address | File | Length | Purpose |
| --- | ---: | ---: | --- |
| `F24A:000E` | `0xF24AE` | 6 | `FF 40` position (0x21, 0x14) — number display. |
| `F24B:0004` | `0xF24B4` | 6 | `FF 40` position (5, 0x90) — panel area. |
| `F24B:000A` | `0xF24BA` | 15 | Menu bar (shared with other organizer apps). |
