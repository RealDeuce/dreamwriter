# Display Stream Service

This slice expands the low-level display/resource entries exposed through the
low-RAM ABI table. It stays at the service layer: the `DC98` display wrappers,
horizontal icon renderer, and application/menu callers remain separate queued
work.

No concrete image assets are reached in this slice. `C000:5AD6` consumes
display resources, but this slice documents the parser entry rather than a
specific resource instance; concrete string resources are decoded in the caller
slices that provide the bytes.

## Low-RAM Far Wrapper

`[0200]` points to `C000:67AD`. This is a far-call ABI wrapper around the local
display resource parser `C000:5AD6`.

Call convention inferred from the wrapper:

```text
AX = resource offset
BX = resource segment
CX = resource byte count
```

The wrapper maps that to the local parser convention:

```text
DX:SI = resource far pointer
CX    = resource byte count
```

```asm
display_stream_far_C000_67AD:
; file 0x467AD
C000:67AD  55                push bp
C000:67AE  57                push di
C000:67AF  56                push si
C000:67B0  52                push dx
C000:67B1  51                push cx
C000:67B2  8B D3             mov  dx,bx
C000:67B4  8B F0             mov  si,ax
C000:67B6  E8 1D F3          call display_resource_C000_5AD6
C000:67B9  59                pop  cx
C000:67BA  5A                pop  dx
C000:67BB  5E                pop  si
C000:67BC  5F                pop  di
C000:67BD  5D                pop  bp
C000:67BE  CB                retf
```

The wrapper preserves `BP`, `DI`, `SI`, `DX`, and `CX` around the parser. It
does not preserve `AX` or `BX`, so parser return/state effects in those
registers remain visible to far-table callers.

## Poll/Idle Far Wrapper

`[023C]` points to `C000:67BF`. It adapts the foreground poll helper
`C000:49FD` to the far ABI. Before the call it sets `ES=DS`; after the call it
clears `AH`.

```asm
poll_idle_far_C000_67BF:
; file 0x467BF
C000:67BF  55                push bp
C000:67C0  57                push di
C000:67C1  56                push si
C000:67C2  52                push dx
C000:67C3  51                push cx
C000:67C4  53                push bx
C000:67C5  06                push es
C000:67C6  8C D8             mov  ax,ds
C000:67C8  8E C0             mov  es,ax
C000:67CA  E8 30 E2          call foreground_poll_C000_49FD
C000:67CD  B4 00             mov  ah,0
C000:67CF  07                pop  es
C000:67D0  5B                pop  bx
C000:67D1  59                pop  cx
C000:67D2  5A                pop  dx
C000:67D3  5E                pop  si
C000:67D4  5F                pop  di
C000:67D5  5D                pop  bp
C000:67D6  CB                retf
```

`C000:49FD` is the shared foreground poll/cancel path used by idle and blocked
I/O flows; it is documented from the keyboard/idle side in
[`idle-power.md`](idle-power.md).

## Resource Parser Entry

`C000:5AD6` is the local display resource parser used directly by service code
and indirectly through the far wrapper above.

Entry convention:

```text
DX:SI = source resource bytes
CX    = byte count
```

The parser snapshots style state from `[7119]` into `[7117]` and `[7118]`, maps
the current font/style through `C000:5FE3`, copies the resource into scratch
buffer `7185`, and then consumes bytes from `[728E]`.

```asm
display_resource_C000_5AD6:
; file 0x45AD6
C000:5AD6  06                push es
C000:5AD7  BD 00 00          mov  bp,0
C000:5ADA  8E C5             mov  es,bp
C000:5ADC  A1 19 71          mov  ax,[0x7119]
C000:5ADF  88 26 17 71       mov  [0x7117],ah
C000:5AE3  A2 18 71          mov  [0x7118],al
C000:5AE6  33 C0             xor  ax,ax
C000:5AE8  A0 F4 70          mov  al,[0x70f4]
C000:5AEB  E8 F5 04          call select_display_font_C000_5FE3
C000:5AEE  E3 E4             jcxz parser_done_C000_5AD4
C000:5AF0  89 0E F0 70       mov  [0x70f0],cx
C000:5AF4  BF 85 71          mov  di,0x7185
C000:5AF7  89 3E 8E 72       mov  [0x728e],di
C000:5AFB  8C DD             mov  bp,ds
C000:5AFD  8E DA             mov  ds,dx
C000:5AFF  FC                cld
C000:5B00  F3 A4             rep  movsb
C000:5B02  8E DD             mov  ds,bp
```

The main loop decrements `[70F0]`, reads one byte from the scratch stream, and
normalizes printable bytes by subtracting `0x20`. Values below `0x20` are
ignored. Normalized values below `0xC0` are drawn as glyphs; normalized values
`>= 0xC0` branch into the control-opcode dispatcher.

```asm
display_resource_loop_C000_5B04:
C000:5B04  83 3E F0 70 00    cmp  word [0x70f0],0
C000:5B09  74 C9             jz   parser_done_C000_5AD4
C000:5B0B  80 26 18 71 DF    and  byte [0x7118],0xdf
C000:5B10  FF 0E F0 70       dec  word [0x70f0]
C000:5B14  8B 36 8E 72       mov  si,[0x728e]
C000:5B18  8A 04             mov  al,[si]
C000:5B1A  FF 06 8E 72       inc  word [0x728e]
C000:5B1E  2C 20             sub  al,0x20
C000:5B20  72 E2             jc   display_resource_loop_C000_5B04
C000:5B22  3C C0             cmp  al,0xc0
C000:5B24  72 03             jc   draw_glyph_C000_5B29
C000:5B26  E9 9F 02          jmp  control_opcode_C000_5DC8
```

This matches the local notation in
[`display-resource-format.md`](display-resource-format.md): resource bytes are
copied and interpreted by `C000:5AD6`; they are not executed as code.

## Text/Glyph State

For printable glyphs, the parser selects glyph width/style, finds the bitmap
data in the font table, and writes into the display buffer at the current cursor
state. The shown code is enough to identify the state variables without
flattening every render subpath.

```asm
draw_glyph_C000_5B29:
C000:5B29  8A D0             mov  dl,al
C000:5B2B  8B 36 F2 70       mov  si,[0x70f2]
C000:5B31  03 C0             add  ax,ax
C000:5B33  03 C0             add  ax,ax
C000:5B35  03 C0             add  ax,ax
C000:5B37  03 F0             add  si,ax
C000:5B39  C7 06 90 72 EFD7  mov  word [0x7290],0xd7ef
C000:5B3F  8A 2E F5 70       mov  ch,[0x70f5]
...
C000:5B81  8A CD             mov  cl,ch
C000:5B8B  2E 8A 8C 67 5A    mov  cl,[cs:si+0x5a67]
```

The display buffer writes use `ES=0` and line stride `0x40`, consistent with the
framebuffer layout used elsewhere in the ROM.

## State Boundary

| RAM | Meaning |
| ---: | --- |
| `70F0` | Remaining display-resource byte count while parsing. |
| `70F2` | Current font/glyph table base. |
| `70F4`, `70F5` | Font/style selectors used before glyph rendering. |
| `70F6..7118` | Scratch/style bytes for underline/inverse/masking and glyph staging. |
| `7117`, `7118` | Active display style flags copied from `[7119]`. |
| `7119` | Saved/default display style word. |
| `7185..` | Resource scratch buffer copied from caller-provided `DX:SI`. |
| `728B`, `728C` | Bit cursor and framebuffer byte offset. |
| `728E` | Current pointer into copied resource stream. |
| `7290` | Segment selector for copied/glyph data; often `D7EF` for fonts. |
