# Printer Controls

Escape sequences and control codes sent to each configured printer model,
extracted from the C688 printer output layer in the T400 v2.1 ROM.

## Supported Printer Models

| Index | UI Label | Family |
| ---: | --- | --- |
| 0 | X24E | IBM |
| 1 | XIII | IBM |
| 2 | LQ | EPSON |
| 3 | FX | EPSON |
| 4 | BJ-10e | CANON |
| 5 | JET | HP |
| 6 | WRITER | IMAGE |

The model selector byte is stored at `[6D59]`, masked with `& 7`, and
copied to `[829E]` by `C688:C0D7` at print start.

## Model Dispatch

The per-model dispatch at `C688:C6E8` uses a 2D byte table at `C688:C200`
indexed as `C200[operation × 8 + model]`.  The byte value selects a handler
table through a secondary lookup at `C688:C1F4`:

| Value | Table base | Models |
| ---: | --- | --- |
| 0x02 | `C688:AF36` | IBM X24E, IBM XIII, Epson LQ, Epson FX, Canon BJ-10e |
| 0x03 | `C688:BAAB` | HP JET |
| 0x05 | `C688:A527` | ImageWriter |
| 0x00 | — | No-op for this model/operation |

Within each handler table, the operation index (BL) selects a function
pointer: `handler_table[BL × 2]`.  The AF36 handlers for IBM/Epson/Canon
sometimes use a secondary per-caller dispatch at `C688:B056` that indexes
a 5- or 7-word jump table by `[829E] & 7` to split IBM, Epson LQ, Epson FX,
and Canon into separate paths.

## Initialization

### IBM X24E / XIII / Epson LQ / FX / Canon BJ-10e

C200 value 0x00 for BL=1 (no-op through C6E8).  The init handler at
`C688:A647` is reached through the token dispatch path and emits a counted
string (`C688:A65F`, 18 bytes):

| Bytes | Sequence |
| --- | --- |
| `18` | CAN |
| `1B 5A 00 20` | ESC Z 0x2000 |
| `1B 5A 80 00` | ESC Z 0x0080 |
| `0F` | SI |
| `1B 57` | ESC W |
| `1B 4B 30` | ESC K 0x30 |
| `1B 76` | ESC v |
| `0D` | CR |

Followed by six subroutines emitting: `0F` (SI), `1B 59` (ESC Y),
`1B 21` (ESC !), `1B 22` (ESC "), `1B 7A` (ESC z), `1B 7A` (ESC z).

BL=3 (C200 value 0x02) adds model-specific character table setup via
`C688:B064`:

| Models | Sends |
| --- | --- |
| IBM X24E, XIII, Canon BJ-10e | `1B 36` (ESC 6) |
| Epson LQ, FX | `1B 74 01 1B 36` (ESC t 1, ESC 6) |

BL=19 (C200 value 0x02) adds pitch reset via `C688:B08F`:

| Models | Sends |
| --- | --- |
| IBM X24E, XIII, Canon BJ-10e | `12 0D` (DC2, CR) |
| Epson LQ, FX | `1B 50 0D` (ESC P, CR) |

### HP JET

C200 value 0x00 for BL=1.  Initialization is handled by BL=4–12 (all C200
value 0x03), routed through the BAAB table to PCL handlers at
`C688:BC4A..BD50`:

| Sequence | PCL command |
| --- | --- |
| `1B 26 6C 36 44` | `ESC &l6D` — 6 LPI |
| `1B 26 6C 31 78` | `ESC &l1x` — 1 copy |
| `1B 26 6C 30 65` | `ESC &l0e` — top margin 0 |
| `1B 26 6C 30 4C` | `ESC &l0L` — perforation skip off |
| `1B 28 73 30 70` | `ESC (s0p` — fixed spacing |
| `1B 28 73 31 30 68` | `ESC (s10h` — 10 CPI |
| `1B 28 73 31 32 76` | `ESC (s12v` — 12 pt |
| `1B 28 73 30 73` | `ESC (s0s` — upright |
| `1B 28 73 30 42` | `ESC (s0B` — medium weight |
| `1B 28 31 30 55` | `ESC (10U` — PC-8 symbol set |
| `1B 26 61 30 68` | `ESC &a0h` — horizontal pos 0 |
| `1B 26 61 30 56` | `ESC &a0V` — vertical pos 0 |
| `1B 26 6B 30 53` | `ESC &k0S` — line wrap off |

Code at `C688:BD2C` computes additional commands from page dimensions:

| Sequence | PCL command |
| --- | --- |
| `ESC &l`*n*`D` | Page length (computed) |
| `ESC &a`*n*`V` | Vertical start position (computed) |

### ImageWriter

C200 value 0x05 for BL=1, dispatching to `C688:A647` — the same handler
body as the token dispatch for IBM/Epson/Canon.  Emits the same 18-byte
init string and subroutines listed above.

BL=3 (C200 value 0x05) dispatches to `C688:A67E`, which emits:
`1B 5A 07 00` (ESC Z), `1B 24` (ESC $), `1B 44 00 04` (ESC D).

BL=5 (C200 value 0x05) dispatches to `C688:A6A0`, which emits:
`1B 44 00 04` (ESC D).

## Formatting Attributes

Dispatched through C6E8 at operation indices 44–53.  Each model class has
its own handler.

### Underline (BL=46/47)

| Models | ON | OFF |
| --- | --- | --- |
| IBM/Epson/Canon | `1B 2D 01` (ESC - 1) | `1B 2D 00` (ESC - 0) |
| HP JET | `1B 26 64 30 44` (ESC &d0D) | `1B 26 64 40` (ESC &d@) |
| ImageWriter | `1B 58` (ESC X) | `1B 59` (ESC Y) |

### Bold (BL=48/49)

| Models | ON | OFF |
| --- | --- | --- |
| IBM/Epson/Canon | `1B 45` (ESC E) | `1B 46` (ESC F) |
| HP JET | `1B 28 73 33 42` (ESC (s3B) | `1B 28 73 30 42` (ESC (s0B) |
| ImageWriter | `1B 21` (ESC !) | `1B 22` (ESC ") |

### Superscript (BL=50/51)

| Models | ON | OFF |
| --- | --- | --- |
| IBM/Epson/Canon | `1B 53 00` (ESC S 0) | `1B 54` (ESC T) |
| HP JET | `1B 26 61 2D 33 36 56` (ESC &a-36V) | `1B 26 61 2B 33 36 56` (ESC &a+36V) |
| ImageWriter | `1B 78` (ESC x) | `1B 7A` (ESC z) |

### Subscript (BL=52/53)

| Models | ON | OFF |
| --- | --- | --- |
| IBM/Epson/Canon | `1B 53 01` (ESC S 1) | `1B 54` (ESC T) |
| HP JET | `1B 26 61 2B 33 36 56` (ESC &a+36V) | `1B 26 61 2D 33 36 56` (ESC &a-36V) |
| ImageWriter | `1B 79` (ESC y) | `1B 7A` (ESC z) |

### Double-wide (BL=44/45)

| Models | ON | OFF |
| --- | --- | --- |
| IBM/Epson/Canon | `1B 57 01` (ESC W 1) | `1B 57 00` (ESC W 0) |
| HP JET | Sets/clears `[829E]` bit 0x40, recomputes spacing | |
| ImageWriter | `0E` (SO) | `0F` (SI) |

### Proportional (BL=20/21)

| Models | ON | OFF |
| --- | --- | --- |
| IBM/Epson/Canon | (no-op, C200 value 0x00) | |
| HP JET | (no-op, C200 value 0x00) | |
| ImageWriter | `1B 70 1B 73 31` (ESC p, ESC s 1) | `1B 71` (ESC q) |

## Page and Spacing Setup

### Page Length (BL=11)

All three model classes have handlers (C200 values 0x02, 0x03, 0x05).
The page length value is computed from `[7901]`.

| Models | Handler | Sends |
| --- | --- | --- |
| IBM/Epson/Canon | `C688:B151` | `1B 43` *n* (ESC C *n*), where *n* = `[7901] / 2` |
| HP JET | `C688:BC4A` | `1B 26 6C` ... (ESC &l) with computed parameter, then `50` (P) |
| ImageWriter | `C688:A6AB` | `1B 48` (ESC H) followed by computed parameter bytes |

### Line Feed Spacing (BL=13)

| Models | Handler | Sends |
| --- | --- | --- |
| IBM/Epson/Canon | `C688:B0C2` | Computed from `[7916] / 6`; selects per-model line spacing command via B056 dispatch |
| HP JET | `C688:BC81` | No output (stub) |
| ImageWriter | `C688:A6CD` | `1B 4C` (ESC L) followed by computed parameter |

BL=14 (`C688:B107` for IBM/Epson/Canon) is a related adjustment computed
from `[7916] + [78F9]`.  ImageWriter is a no-op for BL=14.

### Line Spacing Mode (BL=15, 16, 17)

| BL | IBM/Epson/Canon | HP JET | ImageWriter |
| ---: | --- | --- | --- |
| 15 | `C688:B168` — sets `[829D]=2`, sub-dispatches | `1B 26 6C 36 44` (ESC &l6D) | `1B 54 32 34` (ESC T 24) |
| 16 | (no-op) | (no-op) | `1B 54 33 36` (ESC T 36) |
| 17 | (no-op) | (no-op) | `1B 54 34 38` (ESC T 48) |

### Pitch Reset (BL=19)

| Models | Handler | Sends |
| --- | --- | --- |
| IBM X24E, XIII, Canon BJ-10e | `C688:B08F` | `12 0D` (DC2, CR) |
| Epson LQ, FX | `C688:B08F` | `1B 50 0D` (ESC P, CR) |
| HP JET | `C688:BD1E` | PCL pitch command (computed) |
| ImageWriter | `C688:A716` | `1B 4E` (ESC N) |

## Graphics Mode

### Pitch Selection (BL=22)

All three model classes have handlers (C200 values 0x02, 0x03, 0x05).
The AF36 handler at `C688:B891` uses a sub-dispatch to select between
graphics density modes based on the current CPI setting.  The BAAB handler
at `C688:BE3C` computes PCL font selection commands.  The A527 handler at
`C688:A73D` calls `C688:C801` for ImageWriter-specific mode selection.

### Graphics Density (BL=33–40)

BL=33 (`C688:B99F` for IBM/Epson/Canon) selects line spacing for graphics
output.  BL=34–40 set pitch modes used during graphics rendering.  These
operations have handlers for all three model classes.  The AF36 handlers
use per-model sub-dispatches at B056 to split IBM 24-pin, IBM 9-pin, Epson
24-pin, and Epson 9-pin paths, each building escape sequences in a buffer
at `[827B]`.  The BAAB handlers build PCL font and positioning commands.
The A527 handlers use ImageWriter pitch and graphics commands.

IBM/Epson/Canon pitch commands built by BL=33–40 (via `C688:B8A3`/`B8E7`):

| Mode | Epson | IBM |
| --- | --- | --- |
| 10 CPI | `1B 50` (ESC P) | `12` (DC2) |
| 12 CPI | `1B 4D` (ESC M) | `1B 3A` (ESC :) |
| 15 CPI | `1B 67` (ESC g) | `1B 50` (ESC P) |
| Proportional | `1B 70` (ESC p) | `1B 50 01` (ESC P 1) |

### LPI Divisor (BL=18)

Returns a value in AX used for spacing calculations.

| Models | Handler | Returns |
| --- | --- | --- |
| IBM/Epson/Canon | `C688:BA74` | Dispatches per model; Epson LQ returns 0x0F, others return 0x12 |
| HP JET | (no-op) | |
| ImageWriter | `C688:A710` | Calls `C688:C7D8` for mode-specific setup |

## Diacritic Overlay Bitmaps

BL=55 and BL=56 overlay accent marks on the preceding character position.

### IBM/Epson/Canon (BL=55: C200 value 0x02)

The AF36 handler at `C688:B171` (acute accent) and `C688:B17F` (diaeresis)
print bit-image graphics using a two-part operation: a graphics mode select
command from the table at `C688:B223`, followed by dot-column bitmap data
from `C688:B28B` (acute) or `C688:B547` (diaeresis).

The table index is computed from `([829E] & 3) × 4 + (2 if [829A] ≠ 6)`.
This groups models as: 0 = X24E/BJ-10e, 1 = XIII, 2 = LQ, 3 = FX.

**Graphics mode commands** (`C688:B223`):

| Group | [829A]=6 | [829A]≠6 |
| --- | --- | --- |
| 0 (X24E/BJ-10e) | `1B 5B 67 6D 00 0C` — ESC [g n=109 mode=12 | `1B 5B 67 5B 00 0C` — ESC [g n=91 mode=12 |
| 1 (XIII) | `1B 4C 0C 00` — ESC L 12 cols | `1B 4C 0A 00` — ESC L 10 cols |
| 2 (LQ) | `1B 2A 28 24 00` — ESC * mode=40 36 cols | `1B 2A 28 1E 00` — ESC * mode=40 30 cols |
| 3 (FX) | `1B 4C 0C 00` — ESC L 12 cols | `1B 4C 0A 00` — ESC L 10 cols |

**Bitmap data sizes**:

| Group | [829A]=6 | [829A]≠6 |
| --- | ---: | ---: |
| 0, 2 (24-pin) | 36 cols (108 bytes) | 30 cols (90 bytes) |
| 1, 3 (9-pin) | 12 cols (12 bytes) | 10 cols (10 bytes) |

24-pin printers send 3 bytes per column; 9-pin send 1.  Groups 0 and 2
share bitmap data, as do groups 1 and 3.

**Acute accent** (`C688:B28B`) — 9-pin, 12 columns:

```
pin 0: ······█·····
pin 1: ·····█······
pin 2: ····█·······
```

**Diaeresis** (`C688:B547`) — 9-pin, 12 columns:

```
pin 0: ··█···█·····
```

The 24-pin versions render the same shapes at higher resolution.  When
`[829E]` bit 0x40 is set (double-wide), the index shifts by 16 into wider
variants.

### HP JET (BL=55: C200 value 0x00)

HP JET does not use the bit-image overlay path.

### ImageWriter (BL=55: C200 value 0x05)

The A527 handler at `C688:A8F5` uses ImageWriter-specific diacritic
rendering rather than the bit-image approach.

## HP JET Character Translation

Three characters not in the PC-8 symbol set are printed by temporarily
switching to Roman-8 (`C688:BDC3..BDD9`):

| Character | Sequence |
| --- | --- |
| ¨ (diaeresis) | `1B 28 38 55 A8 1B 28 31 30 55` — ESC (8U, 0xA8, ESC (10U |
| « (left guillemet) | `1B 28 38 55 AB 1B 28 31 30 55` — ESC (8U, 0xAB, ESC (10U |
| ½ (one-half) | `1B 28 38 55 BD 1B 28 31 30 55` — ESC (8U, 0xBD, ESC (10U |

## Output Path

All bytes reach the printer through the byte sink at `C688:C82A`.  The
interface selector at `[6D5A]` bit 0 chooses:

| Bit 0 | Interface | INT 21h | I/O port |
| ---: | --- | --- | --- |
| 0 | Parallel (Centronics) | AH=05 | Port 0x40, strobe 0x30 bit 0x20 |
| 1 | Serial (RS-232) | AH=04 | Port 0xC0 |

Pause (SPACE) and cancel (CAN/0x03) are handled by `C688:CB64`.
