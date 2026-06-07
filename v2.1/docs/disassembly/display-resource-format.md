# Display Resource Format

This is the local notation for string/display resources encountered by the
reachable disassembly. These byte streams are consumed by the renderer at
`C000:5AD6`, not executed as code.

## Text Runs

```text
FF 02 <x:u16le> <y:u16le> <text bytes until next control>
```

Positions the text cursor in pixels, then renders printable bytes
`0x20..0xDF`. Inline control bytes `0xE0..0xFF` switch style or dispatch to
sub-opcodes; do not treat them as literal glyphs.

Descriptor example:

```text
FF 02 0C 00 6A 00
text "ORGANIZER MENU"
```

Final formatted text:

```text
ORGANIZER MENU
```

## Bitmap Runs

```text
FF 40 <x:u16le> <y:u16le>
FF 42 <height:u16le> <width-bits:u16le> <offset:u16le> <segment:u16le>
```

`FF 40` positions the bitmap cursor. `FF 42` blits a 1bpp bitmap from the far
pointer. Source row bytes are `ceil(width-bits / 8)` unless a surrounding
resource format proves a wider stride.

## Horizontal Icon Menu Tables

The shared icon menu renderer `DC98:124C` consumes fixed tables, not `C000:5AD6`
display scripts:

```text
u16le mode
u16le item_count
item_count * far_ptr16 icon_source
item_count * char[13] nul_padded_label
```

Labels should be shown in their final fixed-field form as rendered menu text,
with trailing NUL padding removed and meaningful spaces preserved.

## Documentation Rule

When a string resource is reached, include:

- the resource descriptor bytes or a named fixed-field descriptor,
- the decoded text with control bytes interpreted,
- the final formatted text block that represents what the user sees.
