# Organizer Calculator

This slice expands the Organizer top-menu `CALCULATOR` handler at `DC98:6A38`
/ file `0x633B8`. It bottoms in a private decimal fixed-point calculator core;
there is no evidence of a binary floating-point library in this path.

## App Entry

`DC98:6A38` clears/redraws the calculator panel, initializes the working
buffers, and enters the calculator event loop:

```asm
; file 0x633B8
DC98:6A38  51                push cx
DC98:6A39  52                push dx
DC98:6A3A  9A 70 0E 98 DC    call DC98:0E70
DC98:6A3F  B8 02 00          mov  ax,0x0002
DC98:6A42  50                push ax
DC98:6A43  B8 08 00          mov  ax,0x0008
DC98:6A46  BB 1B 00          mov  bx,0x001b
DC98:6A49  B9 89 01          mov  cx,0x0189
DC98:6A4C  BA 25 00          mov  dx,0x0025
DC98:6A4F  9A E5 0E 98 DC    call DC98:0EE5      ; clear top display area
...
DC98:6A6F  C6 06 48 86 0C    mov  byte [0x8648],0x0c
DC98:6A74  C6 06 49 86 0D    mov  byte [0x8649],0x0d
DC98:6A79  B8 EE 85          mov  ax,0x85ee
DC98:6A7C  E8 2A EA          call DC98:54A9      ; clear input/result record
DC98:6A7F  B8 00 86          mov  ax,0x8600
DC98:6A82  E8 24 EA          call DC98:54A9      ; clear accumulator record
DC98:6A85  C7 06 E8 85 0000  mov  word [0x85e8],0
DC98:6A8B  33 C0             xor  ax,ax
DC98:6A8D  E8 AE ED          call DC98:583E      ; redraw input display
DC98:6A90  E8 C9 F1          call DC98:5C5C      ; redraw memory display
DC98:6A93  C6 06 07 68 01    mov  byte [0x6807],1
DC98:6A98  E8 74 F9          call DC98:640F      ; main calculator loop
DC98:6A9B  C6 06 07 68 00    mov  byte [0x6807],0
```

The main numeric records are:

| Buffer | Observed role |
| ---: | --- |
| `85EE` | Current input/result record. |
| `8600` | Pending accumulator / left operand. |
| `8612` | Temporary result used by equals/finalization. |
| `8624` | Memory register record. |
| `8636` | Arithmetic scratch record. |

Each numeric record is 18 bytes: byte `+0` is a sign flag, bytes `+1..+10h`
are decimal digit bytes, and byte `+11h` is a decimal/exponent position used
by normalization and display. The routines operate on byte values `0..9`, not
ASCII digits.

## Event Loop

`DC98:640F` reads key events through `DC98:0CF9`, compares them against the
private calculator overlay table at `C000:5619..5644`, and dispatches by
function.

| Event | Function |
| ---: | --- |
| `0x02`, `0x03` | Exit and return `AX=0`. |
| `0x0B` | Exit and return `AX=1`. |
| `0x08` | Clear all: clears `8600`, `85EE`, pending operation, error state, and redraws. |
| `0x0D` | Clear entry: clears `85EE` and redraws the input display. |
| `0xDA` | Equals/select: finalizes pending operation through `DC98:6340` and sets `[85EA]=0x32`. |

Operation keys first normalize the current input with `DC98:5ED4`, run the
pending-operation dispatcher at `DC98:629E`, store the new operation in
`[85EA]` and `[85EC]`, then return to the loop:

| Operation | `[85EA]` / `[85EC]` | Core helper used by the dispatcher |
| --- | ---: | --- |
| `+` | `1` | `DC98:5FE0` |
| `-` | `2` | `DC98:60AB` |
| multiply | `3` | `DC98:60D1` |
| divide | `4` | `DC98:61B8` |
| equals / percent finalization | `0x32` | `DC98:6340` final dispatcher |

The memory keys use the same decimal core:

| Key | Handler path |
| --- | --- |
| `RM` | Copies memory record `8624` into current input `85EE` via `DC98:5D09`. |
| `SM` | Copies current input `85EE` into memory record `8624`, then redraws. |
| `M+` | Finalizes pending input, adds `85EE` into memory `8624` with `DC98:5FE0`, then redraws memory. |
| `M-` | Finalizes pending input, subtracts `85EE` from memory `8624` with `DC98:60AB`, then redraws memory. |

`+/-` toggles byte `+0` of the current record, but only if at least one digit
byte is nonzero:

```asm
; file 0x62656
DC98:5CD6  51                push cx
DC98:5CD7  56                push si
DC98:5CD8  8B D8             mov  bx,ax
DC98:5CDA  83 3E E8 85 00    cmp  word [0x85e8],0
...
DC98:5CE8  cmp  byte [si],0
DC98:5CEB  jz   DC98:5CFC
DC98:5CED  cmp  byte [bx],0
DC98:5CF2  mov  al,1
DC98:5CF8  mov  [bx],al
```

## Decimal Core

The calculator core is a compact fixed-point decimal library:

| Helper | Role |
| --- | --- |
| `DC98:54A9` | Clears one 18-byte numeric record. |
| `DC98:5C73` | Shifts digit bytes left and appends `BL`. Used while entering digits. |
| `DC98:5CA3` | Shifts digit bytes right and inserts `BL`. Used for normalization. |
| `DC98:5D09` | Copies one numeric record to another. |
| `DC98:5D3D` | Swaps two numeric records. |
| `DC98:5D77` | Increments the mantissa with decimal carry. |
| `DC98:5D9F` | Compares digit arrays. |
| `DC98:5DE7` | Adds digit arrays with carry. |
| `DC98:5E2D` | Subtracts digit arrays with borrow. |
| `DC98:5ED4` | Normalizes left/right by shifting and adjusting byte `+11h`. |
| `DC98:5F42` | Rounding/overflow normalization. |
| `DC98:5FE0` | Signed decimal add. Aligns decimal positions, then adds or subtracts by sign. |
| `DC98:60AB` | Decimal subtract. Negates/copies the right operand, then calls add. |
| `DC98:60D1` | Decimal multiply. Builds a 32-byte scratch product with `mul byte [bx]` and decimal carry. |
| `DC98:61B8` | Decimal divide. Repeatedly subtracts the divisor to generate quotient digits. |

The multiply routine is the clearest evidence of the representation. It walks
digit bytes and uses byte `mul`, base-10 division, and a 32-byte temporary
product:

```asm
; file 0x62A51
DC98:60D1  55                push bp
DC98:60D2  8B EC             mov  bp,sp
DC98:60D4  83 EC 20          sub  sp,0x20        ; scratch product
...
DC98:6116  F6 27             mul  byte [bx]      ; digit * digit
DC98:611E  02 5A E1          add  bl,[bp+si-0x1f]
DC98:612A  B1 0A             mov  cl,0x0a
DC98:612E  F6 F1             div  cl             ; base-10 carry/remainder
```

The divide routine checks for a zero divisor, then performs long division by
repeated subtract/compare steps:

```asm
; file 0x62B38
DC98:61B8  55                push bp
DC98:61B9  8B EC             mov  bp,sp
DC98:61BB  83 EC 02          sub  sp,0x02
DC98:61E3  C7 06 E8 85 0200  mov  word [0x85e8],2 ; division by zero
...
DC98:6239  8B C7             mov  ax,di
DC98:623B  8B DE             mov  bx,si
DC98:623D  E8 ED FB          call DC98:5E2D      ; subtract divisor
DC98:6243  41                inc  cx             ; quotient digit
DC98:624A  8B C7             mov  ax,di
DC98:624C  8B DE             mov  bx,si
DC98:624E  E8 4E FB          call DC98:5D9F      ; compare
DC98:6251  3D 00 00          cmp  ax,0
DC98:6254  7D E3             jnl  DC98:6239
```

The pending-operation dispatcher at `DC98:629E` selects those same helpers from
`[85EA]` before returning to the calculator UI:

```asm
; file 0x62C1E
DC98:629E  51                push cx
DC98:629F  52                push dx
DC98:62A0  8B D0             mov  dx,ax
DC98:62BE  83 3E EA 85 01    cmp  word [0x85ea],1
DC98:62CB  E8 12 FD          call DC98:5FE0
...
DC98:62E6  E8 C2 FD          call DC98:60AB
DC98:6301  E8 CD FD          call DC98:60D1
DC98:631C  E8 99 FE          call DC98:61B8
```

This is decimal integer/fixed-point arithmetic over local digit arrays. There
are no x87-style instructions, no IEEE-style constants, and no shared binary
floating-point package reached by the calculator root.

## Square Root

The square-root key draws a short calculator resource at `F093:0008`, then
calls `DC98:6B86` on the current input record. The routine rejects negative
numbers by setting `[85E8]=3`, clears five scratch records at `864A`, `866A`,
`868A`, `86AA`, and `86CA`, then uses the same decimal helpers to iteratively
build a result.

```asm
; file 0x63506
DC98:6B86  51                push cx
DC98:6B8A  8B F0             mov  si,ax
DC98:6B96  80 3C 01          cmp  byte [si],1
DC98:6B9B  C7 06 E8 85 0300  mov  word [0x85e8],3
...
DC98:6C32  B8 AA 86          mov  ax,0x86aa
DC98:6C35  BB CA 86          mov  bx,0x86ca
DC98:6C38  E8 11 FF          call DC98:6B4C
...
DC98:6CCB  88 54 11          mov  [si+0x11],dl
DC98:6CD0  E8 6F F2          call DC98:5F42
DC98:6CD5  E8 FC F1          call DC98:5ED4
```

This is not a general floating-point square-root routine; it is a calculator
decimal-array square-root implementation.

## Display Resources

The calculator display renderer builds `FF 42` image records rather than using
the normal text font for digits. The main large digit family starts at
`F16C:000A` / file `0x716CA`, with 8x12 glyphs spaced by `0x0D` bytes. The
decimal mark and blank/status glyphs are in the same family.

| Resource | PNG | Descriptor |
| --- | --- | --- |
| Digit `0` | ![digit 0](images/calc-digit-0-0x716ca.png) | `file 0x716CA`, `8x12`, row bytes `1`. |
| Digit `1` | ![digit 1](images/calc-digit-1-0x716d7.png) | `file 0x716D7`, `8x12`, row bytes `1`. |
| Decimal mark | ![decimal mark](images/calc-decimal-0x7174c.png) | `file 0x7174C`, `4x12`, row bytes `1`. |
| Blank glyph | ![blank](images/calc-blank-0x71759.png) | `file 0x71759`, `8x12`, row bytes `1`. |
| Operator/status glyph strip | ![operator glyphs](images/calc-operator-glyphs-0x709b0.png) | `file 0x709B0`, four contiguous `8x8` glyphs rendered as `8x32`. |

The calculator error strings at `F094:0008` / file `0x70948` are four fixed
24-byte, space-padded strings:

| Index | Display text |
| ---: | --- |
| `1` | `OVERFLOW` |
| `2` | `DIVISION BY ZERO` |
| `3` | `OUT OF RANGE` |
| `4` | `UNKNOWN ERROR` |

`[85E8]` selects the error string. The display helper computes
`F094:0008 + ([85E8] - 1) * 0x18` and passes exactly `0x18` bytes to
`C000:67AD`, so the final on-screen field is the chosen text padded to 24
columns.

## Bottom

The `CALCULATOR` root bottoms inside this slice:

| Root | Bottomed at |
| --- | --- |
| App entry | `DC98:6A38` initializes records and calls `DC98:640F`. |
| Event loop | `DC98:640F` dispatches calculator overlay keys and exits on menu-return events. |
| Arithmetic | `DC98:5FE0`, `60AB`, `60D1`, `61B8`, dispatchers `629E`/`6340`, and helpers `5C73..5F42`. |
| Square root | `DC98:6B86` decimal-array square-root path. |
| Display | `DC98:54C2`, `583E`, `5BCC`, `5C5C` emit display-resource scripts and bitmap glyph records. |

No remaining calculator-only roots are queued.
