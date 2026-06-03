# DC98 Display Wrappers

This slice follows the `DC98` display wrapper entries exposed by the low-RAM
ABI table. It deliberately stops before the horizontal icon-menu renderer
`DC98:124C` and application/menu callers.

No image assets are reached here. `DC98:0E81` can render caller-provided text;
the actual final text is documented in the caller slice that supplies the
string bytes.

## Clear/Setup Resource Wrapper

`DC98:0E70` is the low-RAM ABI entry at `[0220]`. It emits a fixed 15-byte
display resource from `EDFA:0002` through `C000:67AD`.

```asm
display_fixed_resource_DC98_0E70:
; file 0x5D7F0
DC98:0E70  51                push cx
DC98:0E71  B8 02 00          mov  ax,0x0002
DC98:0E74  BB FA ED          mov  bx,0xedfa
DC98:0E77  B9 0F 00          mov  cx,0x000f
DC98:0E7A  9A AD 67 00 C0    call C000:67AD
DC98:0E7F  59                pop  cx
DC98:0E80  CB                retf
```

Resource descriptor:

```text
source: EDFA:0002
bytes: FF 06 00 00 00 00 10 00 E0 01 00 00 00 00 00
format: display-control opcode FF 06 with six u16le payload words
```

This is not a string resource. Its effect is a display-control operation handled
inside `C000:5AD6`; the wrapper does not inspect the payload.

## Text Wrapper

`DC98:0E81` is the low-RAM ABI entry at `[0204]`. It builds a transient display
resource at `72E5` and forwards it through `C000:67AD`.

Call convention:

```text
AX:BX = far pointer to NUL-terminated text
DX    = x position
CX    = y position
```

The wrapper emits `FF 40`, two coordinate words, then the caller's text bytes up
to but not including the NUL.

```asm
display_text_DC98_0E81:
; file 0x5D801
DC98:0E81  55                push bp
DC98:0E82  8B EC             mov  bp,sp
DC98:0E84  83 EC 06          sub  sp,6
DC98:0E88  89 46 FC          mov  [bp-4],ax
DC98:0E8B  89 5E FE          mov  [bp-2],bx
DC98:0E8E  C7 46 FA E5 72    mov  word [bp-6],0x72e5
DC98:0E96  C6 07 FF          mov  byte [bx],0xff
DC98:0E9F  C6 07 40          mov  byte [bx],0x40
DC98:0EA8  89 17             mov  [bx],dx
DC98:0EB1  89 0F             mov  [bx],cx
...
DC98:0EC4  C4 5E FC          les  bx,[bp-4]
DC98:0EC8  26 8A 07          mov  al,[es:bx]
DC98:0ECB  84 C0             test al,al
DC98:0ECD  75 EA             jnz  copy_text_byte_DC98_0EB9
DC98:0ECF  B8 E5 72          mov  ax,0x72e5
DC98:0ED2  8C DB             mov  bx,ds
DC98:0EDB  9A AD 67 00 C0    call C000:67AD
```

String/resource format:

```text
bytes: FF 40 <x:u16le> <y:u16le> <text bytes>
format: text_position(x=DX, y=CX), text=NUL-terminated caller string without NUL
final formatted text:
  <caller text>
```

The NUL terminator is consumed only as a local copy terminator; it is not sent
to `C000:5AD6`.

## Rectangle/Blit Wrapper

`DC98:0EE5` is the low-RAM ABI entry at `[0208]`. It constructs a sequence of
`FF 44` display-control records at `72E5` and forwards the combined stream to
`C000:67AD`.

Call convention inferred from the fields:

```text
AX = y/base coordinate
BX = x/base coordinate
CX = height/extent
DX = width/extent
[BP+6] = split/clip coordinate
```

The wrapper writes four `FF 44` records. The first starts at `(BX, AX)` with
`[BP+6]` and `CX`; the later records derive split rectangles from
`BX + DX - [BP+6]`, `DX`, and `AX + CX - [BP+6]`.

```asm
display_rects_DC98_0EE5:
; file 0x5D865
DC98:0EE5  55                push bp
DC98:0EE6  8B EC             mov  bp,sp
DC98:0EEE  C7 46 FE E5 72    mov  word [bp-2],0x72e5
DC98:0EF6  C6 04 FF          mov  byte [si],0xff
DC98:0EFF  C6 04 44          mov  byte [si],0x44
DC98:0F08  89 1C             mov  [si],bx
DC98:0F11  89 04             mov  [si],ax
DC98:0F1A  8B 7E 06          mov  di,[bp+6]
DC98:0F1D  89 3C             mov  [si],di
DC98:0F26  89 0C             mov  [si],cx
...
DC98:106B  9A AD 67 00 C0    call C000:67AD
```

Record format:

```text
FF 44 <x:u16le> <y:u16le> <w:u16le> <h:u16le> 00 00 00 00 0F
```

This is a display-control/rectangle stream, not a string resource.

## State Boundary

| RAM | Meaning |
| ---: | --- |
| `72E5..` | Transient display-resource stream constructed by wrappers. |
| `EDFA:0002` | Static 15-byte display-control resource used by `DC98:0E70`. |

