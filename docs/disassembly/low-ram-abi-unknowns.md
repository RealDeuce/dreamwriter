# Low-RAM ABI UI Widgets

This slice follows the remaining low-RAM ABI targets that are service-level UI
helpers. They are exposed through the copied far-pointer table at `0000:0200`;
the application/menu callers remain intentionally outside this slice.

No image assets are reached here. String resources are caller-supplied text
buffers, so the concrete final string is documented as the formatted caller
text rather than a fixed ROM literal.

## Wrapped Text Block

`DC98:1555` is the low-RAM ABI entry at `[0210]`. It formats a caller string
into one or more display-stream records and sends each record to `C000:67AD`.
Inputs observed:

| Register/stack | Role |
| --- | --- |
| `AX` | Near pointer to a NUL-terminated text buffer. |
| `BX` | Row width in characters. |
| `CX` | Row count. |
| `DX` | Starting vertical coordinate. |
| `[BP+6]` | Horizontal coordinate/control word forwarded into the record. |

```asm
wrapped_text_DC98_1555:
; file 0x5DED5
DC98:1555  55                push bp
DC98:1556  8B EC             mov  bp,sp
...
DC98:1564  F7 E1             mul  cx              ; total capacity = BX * CX
...
DC98:157A  C6 05 FF          mov  byte [di],0xff
DC98:1583  C6 05 40          mov  byte [di],0x40  ; display text record
...
DC98:15A4  8A 04             mov  al,[si]
DC98:15A6  46                inc  si
...
DC98:15BD  C6 04 FF          mov  byte [si],0xff
DC98:15C6  C6 04 0E          mov  byte [si],0x0e  ; spacing/pad control
...
DC98:165B  9A AD 67 00 C0    call C000:67AD
DC98:1693  CB                retf
```

The emitted string/control format is:

```text
FF 40 <x:u16le> <y:u16le> <text bytes, no NUL>
[ FF 0E <remaining_cell_width_pixels:u16le> ]
```

Final formatted text: `<caller text>`, NUL removed, wrapped into rows of `BX`
characters for up to `BX * CX` visible characters.

## Cell Highlight Helpers

`DC98:1694` and `DC98:171D` build `FF 44` rectangle records and immediately
send them through `C000:67AD`. They are used by the input widgets to erase or
draw the current text cell.

```text
FF 44 <x:u16le> <y:u16le> <w:u16le> <h:u16le> 00 00 00 00 <mode:u8>
```

`DC98:1694` computes the vertical coordinate as `SI + AX * 6 - 1` and emits an
8-by-7 rectangle. `DC98:171D` treats `AX` as a linear cell index: it divides by
`BX`, then derives `x = quotient * 8 + DX` and `y = remainder * 6 + CX - 1`.

## Edit Buffer Helpers

`DC98:17BE` inserts a validated character into a caller buffer. It bounds the
operation by the maximum length supplied on the stack, supports insert/overwrite
mode through another stack flag, shifts trailing bytes when needed, and returns
the updated string length.

`DC98:1844` deletes one byte from a caller string by shifting all following
bytes left from the requested index.

`DC98:1876` validates a candidate key code in `AX` according to selector `BX`:

| Selector | Accepted input |
| ---: | --- |
| `1` | ASCII digit `0`..`9`. |
| `2` | Printable range `0x20..0xBF`. |
| `3` | Digit, `*`, `#`, or `-`. |
| `4` | `Y`, `y`, `N`, or `n`. |

The return is `AX=1` for accepted input and `AX=0` otherwise.

## Callback Setter

`DC98:1859` is the low-RAM ABI entry at `[022C]`. It installs the optional idle
callback used by the input widgets. The routine stores the far pointer with the
offset from `BX` and the segment from `AX`.

```asm
set_input_idle_callback_DC98_1859:
; file 0x5E1D9
DC98:1859  55                push bp
DC98:185A  8B EC             mov  bp,sp
...
DC98:186B  89 1E E5 74       mov  [0x74e5],bx     ; callback offset
DC98:186F  A3 E7 74          mov  [0x74e7],ax     ; callback segment
DC98:1875  CB                retf
```

When option bit `0x1000` is set, the widgets call this pointer between
`DC98:0D19` poll cycles while waiting for input.

## Line Editor Widgets

`DC98:18EA` (`[0214]`) and `DC98:1BB7` (`[0218]`) are related editable text
widgets. Both render the existing buffer, draw a cell cursor, poll or block for
keys through `DC98:0D19`/`DC98:0CF9`, validate printable input with
`DC98:1876`, and update the caller buffer through `DC98:17BE` and `DC98:1844`.

`DC98:1BB7` is the clearer grid-oriented variant: it calls `DC98:1555` to draw
the full wrapped buffer, calls `DC98:171D` for the cursor cell, and treats the
maximum visible capacity as `BX * CX`.

Key values observed in these editors:

| Key code | Observed action |
| ---: | --- |
| `0xDA` | Exit/accept path. |
| `0x13` | Move within the grid, with optional early return when flag `0x0008` is set. |
| `0x12` | Move within the grid, with optional early return when flag `0x0004` is set. |
| `0x03` | Clear/reset edit state. |
| `0x08` | Backspace/delete path. |
| `0x02` | Optional early return when flag `0x0010` is set. |
| `0x0B` | Optional early return when flag `0x0020` is set. |

The text resource format is the wrapped-text format from `DC98:1555`. Final
formatted text: `<edited caller text>`, NUL terminated in memory and displayed
without the NUL.

## Styled Prompt Selector

`DC98:20AA` transforms a caller string into a temporary display stream at
`72E5` and passes it to `C000:67AD`. Literal bytes are copied unchanged except
for brace markup, which becomes display-control bytes before the stream is
sent.

`DC98:214E` is the low-RAM ABI entry at `[021C]`. It displays a styled prompt,
tracks a caller selection word at `DS:CX`, and waits for selection keys. If the
caller passes a zero option count, it only displays the string and returns
`AX=0`; otherwise it loops until a permitted key returns or the selection index
is adjusted.

```asm
prompt_selector_DC98_214E:
; file 0x5EACE
DC98:214E  55                push bp
DC98:214F  8B EC             mov  bp,sp
...
DC98:218B  FF 76 0A          push word [bp+0x0a]
DC98:218E  FF 76 06          push word [bp+0x06]
DC98:2191  8B 46 FC          mov  ax,[bp-0x04]
DC98:2194  8B 5E FE          mov  bx,[bp-0x02]
DC98:2197  8B 0C             mov  cx,[si]
DC98:2199  E8 0E FF          call DC98:20AA
...
DC98:21E3  9A F9 0C 98 DC    call DC98:0CF9
...
DC98:229F  5D                pop  bp
DC98:22A0  CB                retf
```

String format descriptor:

```text
<styled-prompt> := literal bytes with brace markup converted to display controls
```

Final formatted text: `<caller prompt text>`, with markup braces consumed by
the display-control conversion.

## Resolved Boundary

`DC98:2887` is the low-RAM ABI entry at `[02A0]`, but it is only a two-instruction
stub immediately before the OTHERS -> SYSTEM handler:

```asm
DC98:2887  33 C0             xor  ax,ax
DC98:2889  CB                retf
```

It does not need a separate expansion queue entry.
