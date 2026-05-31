# Font Tables

## Main Glyph Table

MAME's `drwrt400` `GFXDECODE_ENTRY` points at ROM file offset `0x580B6` and
treats the data as 8x8, 1bpp glyphs. The first glyphs line up with printable
ASCII starting at space:

```text
0x580B6 + (code - 0x20) * 8
```

Examples:

| Character | Code | File offset | Bytes |
| --- | ---: | ---: | --- |
| space | `0x20` | `0x580B6` | `00 00 00 00 00 00 00 00` |
| `!` | `0x21` | `0x580BE` | `20 20 20 20 20 00 20 00` |
| `0` | `0x30` | `0x58136` | `70 88 98 A8 C8 88 70 00` |
| `A` | `0x41` | `0x581BE` | `70 88 88 F8 88 88 88 00` |

The glyphs are stored as one byte per row, most-significant bit first. Most
ASCII letters use a 5x7 visible shape in an 8-byte slot. That matches the
machine's 480-pixel display width if text is rendered into 6-pixel cells for
80 columns, with spacing/cropping handled by the text renderer.

Use the helper to inspect glyphs:

```sh
tools/rom2.py glyphs --text 'A0!'
tools/rom2.py glyphs --bold --text 'A0!'
```

## Manual Character Set Notes

The manual's character set page helps anchor the high-code area:

| Code range | ROM observation |
| --- | --- |
| `0xC0..0xCA` / decimal `192..202` | Box drawing glyphs. |
| `0xCB..0xD1` / decimal `203..209` | Blank glyphs, matching the manual's unexpected blanks. |
| `0xD2..0xDF` | Nonblank symbols/forms. |
| `0xE0..0xFF` | Start of a bold duplicate run for `0x20..0x3F`. `0xE0` is bold space, so it is blank. |

This means there are two overlapping views of `0xE0..0xFF`:

```text
font memory view:      glyph slots 0xE0..0xFF overlap the first 32 bold glyphs
display-stream view:   raw bytes 0xE0..0xFF are renderer control opcodes
```

The `C000:5AD6` display-resource renderer treats bytes `0x20..0xDF` as
printable and sends bytes `0xE0..0xFF` to the control table at `C000:5DC8`.
So the manual's blank `224..255` range likely describes the standard character
set exposed to text, while the ROM storage at those glyph slots is reused as the
start of a second, bold font run selected by renderer state rather than by
emitting literal bytes `0xE0..0xFF`.

Box drawing examples:

| Code | File offset | Shape |
| ---: | ---: | --- |
| `0xC4` | `0x585D6` | Horizontal line. |
| `0xC5` | `0x585DE` | Cross/intersection. |
| `0xC6` | `0x585E6` | Vertical line. |

## Bold Font Run

Starting at glyph index `192` / file `0x586B6`, the ROM contains a bold version
of the printable ASCII run. The first 32 entries overlap character codes
`0xE0..0xFF` if interpreted as the same code page:

```text
bold glyph for thin code C = 0x586B6 + (C - 0x20) * 8
```

Examples:

| Thin code | Thin char | Bold file offset | Notes |
| ---: | --- | ---: | --- |
| `0x20` | space | `0x586B6` | Blank bold space. |
| `0x21` | `!` | `0x586BE` | Wider strokes than thin `!`. |
| `0x30` | `0` | `0x58736` | Bold digit zero. |
| `0x3F` | `?` | `0x587AE` | Bold question mark. |
| `0x40` | `@` | `0x587B6` | Bold run continues past `0xFF` as glyph index `224`. |
| `0x41` | `A` | `0x587BE` | Bold capital A. |
| `0x61` | `a` | `0x588BE` | Bold lowercase a. |
| `0x7E` | `~` | `0x589A6` | Bold tilde. |

So `0xE0..0xFF` are best understood as overlapping the start of a bold glyph
run in font memory, not as ordinary display-stream character bytes. In the main
resource/text renderer, literal bytes in that range are control opcodes.

Use:

```sh
tools/rom2.py glyphs --bold --text 'A0!?az'
tools/rom2.py glyphs --bold --count 95 > bold-20-7e.txt
```

## Renderer Font Selection

The display-resource renderer does not emit high bytes such as `0xE0` to select
the bold glyphs directly. Instead, controls such as `F8/F9` update renderer
state and call `C000:5FE3`, which looks up an active glyph base from the current
font family byte `[70F4]` plus style bits in `[7117]`.

The lookup table is rooted at `D7EF:0006` / file `0x57EF6`. For each family, the
four entries are selected by the low two style bits:

```text
entry index = 4 * [70F4] + [7117] - 4
```

Confirmed entries include:

| `[70F4]` | Style bits | Glyph base | Current read |
| ---: | ---: | ---: | --- |
| `2` | `0` | `0x580B6` | Main. |
| `2` | `1` | `0x586B6` | Main bold. |
| `2` | `2` | `0x58CB6` | Small. |
| `2` | `3` | `0x592B6` | Small bold. |
| `4` | `0` | `0x598B6` | Narrow. |
| `4` | `1` | `0x59EB6` | Narrow bold. |
| `4` | `2` | `0x5A4B6` | Narrow small. |
| `4` | `3` | `0x5AAB6` | Narrow small bold. |

The typing tutor title resource confirms this visually: the stream wraps only
the initials in `F8`/`F9`, and MAME shows those initials bold while the rest of
the word remains narrow.

## Bold Extended Glyphs

The bytes immediately after bold `~` are still 8-byte glyphs, not a separate
6-byte font table. The first entry after bold printable ASCII is:

```text
0x589AE = 0x586B6 + (0x7F - 0x20) * 8
```

The following entries look like bold extended/accented glyphs. Many use only
5-6 visible rows because accent marks consume the top rows and the bottom row is
blank, which can make this region look like a 6-row font when eyeballing hex.

Examples:

| Bold extended index | File offset | Notes |
| ---: | ---: | --- |
| `0x7F` | `0x589AE` | Accent-like mark. |
| `0x80` | `0x589B6` | Bold C-like glyph with descender/mark. |
| `0x81` | `0x589BE` | Bold accented/modified lowercase-looking glyph. |

To inspect this continuation:

```sh
tools/rom2.py glyphs --base 0x589ae --first-code 0x7f --count 32
```

## Small / Down-Shifted Glyph Run

A second printable run begins at file `0x58CB6`. It is still stored as 8 bytes
per glyph, but the visible strokes are shifted into the lower rows of the cell:

```text
small glyph for code C = 0x58CB6 + (C - 0x20) * 8
```

This is the first region that matches the "6-row-high" / subscript-looking
observation. It is not a 6-byte-packed font; it uses the same one-byte-per-row
format as the main and bold glyphs. Most printable characters leave the top
three rows blank and draw in the lower five rows. The raw bitmap is therefore
down-shifted, but the `FA` display-control path has been observed rendering
those small glyphs at the top of the text cell, producing a visible
small/superscript style.

Examples:

| Code | Character | File offset | Notes |
| ---: | --- | ---: | --- |
| `0x20` | space | `0x58CB6` | Blank. |
| `0x21` | `!` | `0x58CBE` | Down-shifted punctuation. |
| `0x30` | `0` | `0x58D36` | Small digit zero. |
| `0x41` | `A` | `0x58DBE` | Small capital A. |
| `0x61` | `a` | `0x58EBE` | Small lowercase a. |
| `0x7E` | `~` | `0x58FA6` | Small tilde. |

Use:

```sh
tools/rom2.py glyphs --small --text 'A0!?az'
tools/rom2.py glyphs --small --count 95 > small-20-7e.txt
```

## Small Extended And Small Bold Glyphs

The small run follows the same broad layout as the main font:

| Region | File offset | Interpretation |
| --- | ---: | --- |
| Small printable `0x20..0x7E` | `0x58CB6..0x58FAE` | Down-shifted printable ASCII. |
| Small extended `0x7F..0xDF` | `0x58FB6..0x592AE` | Down-shifted extended/accented/symbol glyphs. |
| Small bold printable | `0x592B6` | Bold duplicate of small `0x20..0x7E`. |

The small-bold base is exactly `0x600` bytes after the small base, matching the
main/bold relationship:

```text
0x592B6 = 0x58CB6 + 192 * 8
small bold glyph for small code C = 0x592B6 + (C - 0x20) * 8
```

Examples:

| Small code | Character | Small-bold file offset | Notes |
| ---: | --- | ---: | --- |
| `0x20` | space | `0x592B6` | Blank small-bold space. |
| `0x21` | `!` | `0x592BE` | Thicker down-shifted punctuation. |
| `0x30` | `0` | `0x59336` | Small-bold digit zero. |
| `0x41` | `A` | `0x593BE` | Small-bold capital A. |
| `0x61` | `a` | `0x594BE` | Small-bold lowercase a. |
| `0x7E` | `~` | `0x595A6` | Small-bold tilde. |

Use:

```sh
tools/rom2.py glyphs --small-bold --text 'A0!?az'
tools/rom2.py glyphs --small-bold --count 95 > small-bold-20-7e.txt
```

## Narrow Glyph Run

The next page-sized run begins at file `0x598B6`. It returns to full-height
printable glyphs, but the strokes are horizontally compressed compared with the
main font:

```text
narrow glyph for code C = 0x598B6 + (C - 0x20) * 8
```

This base is again `0x600` bytes after the previous printable font base:

```text
0x598B6 = 0x592B6 + 192 * 8
```

Examples:

| Code | Character | File offset | Notes |
| ---: | --- | ---: | --- |
| `0x20` | space | `0x598B6` | Blank. |
| `0x21` | `!` | `0x598BE` | Narrow punctuation. |
| `0x30` | `0` | `0x59936` | Narrow digit zero. |
| `0x41` | `A` | `0x599BE` | Narrow capital A. |
| `0x61` | `a` | `0x59ABE` | Narrow lowercase a. |
| `0x7E` | `~` | `0x59BA6` | Narrow tilde. |

Use:

```sh
tools/rom2.py glyphs --narrow --text 'A0!?az'
tools/rom2.py glyphs --narrow --count 95 > narrow-20-7e.txt
```

The narrow run then follows the same page layout as the preceding font styles:

| Region | File offset | Interpretation |
| --- | ---: | --- |
| Narrow printable `0x20..0x7E` | `0x598B6..0x59BAE` | Horizontally compressed printable ASCII. |
| Narrow extended `0x7F..0xDF` | `0x59BB6..0x59EAE` | Narrow extended/accented/symbol glyphs. |
| Narrow bold printable | `0x59EB6` | Bold duplicate of narrow `0x20..0x7E`. |

The narrow-bold base is one more `0x600`-byte page:

```text
0x59EB6 = 0x598B6 + 192 * 8
narrow bold glyph for code C = 0x59EB6 + (C - 0x20) * 8
```

Examples:

| Code | Character | Narrow-bold file offset | Notes |
| ---: | --- | ---: | --- |
| `0x20` | space | `0x59EB6` | Blank. |
| `0x21` | `!` | `0x59EBE` | Thicker narrow punctuation. |
| `0x30` | `0` | `0x59F36` | Narrow-bold digit zero. |
| `0x41` | `A` | `0x59FBE` | Narrow-bold capital A. |
| `0x61` | `a` | `0x5A0BE` | Narrow-bold lowercase a. |
| `0x7E` | `~` | `0x5A1A6` | Narrow-bold tilde. |

Use:

```sh
tools/rom2.py glyphs --narrow-bold --text 'A0!?az'
tools/rom2.py glyphs --narrow-bold --count 95 > narrow-bold-20-7e.txt
```

## Narrow Small Glyph Run

After the narrow-bold extended page, file `0x5A4B6` starts a narrow
down-shifted printable run. It combines the horizontal compression of the
narrow font with the lower-row placement of the small font:

```text
narrow small glyph for code C = 0x5A4B6 + (C - 0x20) * 8
```

Again, the base is one `0x600`-byte page after the previous printable font
base:

```text
0x5A4B6 = 0x59EB6 + 192 * 8
```

Examples:

| Code | Character | File offset | Notes |
| ---: | --- | ---: | --- |
| `0x20` | space | `0x5A4B6` | Blank. |
| `0x21` | `!` | `0x5A4BE` | Narrow down-shifted punctuation. |
| `0x30` | `0` | `0x5A536` | Narrow-small digit zero. |
| `0x41` | `A` | `0x5A5BE` | Narrow-small capital A. |
| `0x61` | `a` | `0x5A6BE` | Narrow-small lowercase a. |
| `0x7E` | `~` | `0x5A7A6` | Narrow-small tilde. |

Use:

```sh
tools/rom2.py glyphs --narrow-small --text 'A0!?az'
tools/rom2.py glyphs --narrow-small --count 95 > narrow-small-20-7e.txt
```

The narrow-small run repeats the same extended-then-bold structure:

| Region | File offset | Interpretation |
| --- | ---: | --- |
| Narrow-small printable `0x20..0x7E` | `0x5A4B6..0x5A7AE` | Narrow down-shifted printable ASCII. |
| Narrow-small extended `0x7F..0xDF` | `0x5A7B6..0x5AAAE` | Narrow down-shifted extended/accented/symbol glyphs. |
| Narrow-small-bold printable | `0x5AAB6` | Bold duplicate of narrow-small `0x20..0x7E`. |

The narrow-small-bold base is:

```text
0x5AAB6 = 0x5A4B6 + 192 * 8
narrow small bold glyph for code C = 0x5AAB6 + (C - 0x20) * 8
```

Examples:

| Code | Character | Narrow-small-bold file offset | Notes |
| ---: | --- | ---: | --- |
| `0x20` | space | `0x5AAB6` | Blank. |
| `0x21` | `!` | `0x5AABE` | Thicker narrow down-shifted punctuation. |
| `0x30` | `0` | `0x5AB36` | Narrow-small-bold digit zero. |
| `0x41` | `A` | `0x5ABBE` | Narrow-small-bold capital A. |
| `0x61` | `a` | `0x5ACBE` | Narrow-small-bold lowercase a. |
| `0x7E` | `~` | `0x5ADA6` | Narrow-small-bold tilde. |

Use either spelling:

```sh
tools/rom2.py glyphs --narrow-small-bold --text 'A0!?az'
tools/rom2.py glyphs --narrow-bold-small --count 95 > narrow-small-bold-20-7e.txt
```

## Sparse / Remapped Glyph Set

After the narrow-small-bold extended page, file `0x5B0B6` starts a different
kind of table. It is still 8 bytes per glyph, but it is not a complete printable
ASCII page starting at `0x20`. It is better treated as a sparse or remapped
glyph set until the consuming renderer/table is found.

```text
sparse glyph slot N = 0x5B0B6 + N * 8
```

The page begins with full-height vertical stroke masks, then mixes exact
main-font duplicates with unique symbols. That makes it look slightly taller
than the small/down-shifted pages: many entries use the top row, and the first
few masks use all 8 rows.

Confirmed exact byte-for-byte matches against the main `0x580B6` font include:

| Sparse slot | File offset | Matches main code | Notes |
| ---: | ---: | ---: | --- |
| `0x10..0x19` | `0x5B136..0x5B17E` | `0x30..0x39` | Digit run. |
| `0x3C..0x43` | `0x5B296..0x5B2CE` | `0x41..0x48` with gaps nearby | Uppercase fragment. |
| `0x46..0x4F` | `0x5B2E6..0x5B32E` | `0x4B..0x54` with gaps | Uppercase fragment. |
| `0x5D` | `0x5B39E` | `0x62` | Lowercase `b`. |
| `0x5F` | `0x5B3AE` | `0x64` | Lowercase `d`. |

Inspection commands:

```sh
tools/rom2.py glyphs --base 0x5b0b6 --first-code 0x00 --count 128
tools/rom2.py glyphs --base 0x5b0b6 --first-code 0x00 --code 0x10 --code 0x3c
```

## Sparse Bold Glyph Set

The sparse/remapped set has a bold companion at `0x5B6B6`, again exactly one
`0x600`-byte page later:

```text
0x5B6B6 = 0x5B0B6 + 192 * 8
sparse bold glyph slot N = 0x5B6B6 + N * 8
```

This page preserves the sparse slot ordering but uses bold-style strokes. In
the first 160 slots, 55 entries are exact byte-for-byte matches against the
main bold font at `0x586B6`. The same remapped alphabet fragments appear: for
example, sparse-bold slots `0x3C..0x43` match bold `0x41..0x48`, and
`0x46..0x4F` match bold `0x4B..0x54` with gaps.

The first few line/marker slots are not just doubled copies of the non-bold
sparse vertical masks, so keep them as separate sparse-symbol entries until the
code mapping is known.

Use:

```sh
tools/rom2.py glyphs --sparse --first-code 0x00 --count 128
tools/rom2.py glyphs --sparse-bold --first-code 0x00 --count 128
```

## Sparse Small Glyph Set

The next page at `0x5BCB6` is the small/down-shifted companion for the sparse
set:

```text
0x5BCB6 = 0x5B6B6 + 192 * 8
sparse small glyph slot N = 0x5BCB6 + N * 8
```

Like the sparse-bold page, it keeps the sparse/remapped slot ordering. In the
first 160 slots, 60 entries are exact byte-for-byte matches against the small
font at `0x58CB6`. The alphabet fragments are down-shifted; for example,
sparse-small slots `0x3C..0x43` match small `0x41..0x48`, and slot `0x5D`
matches small `0x62`.

The early line/marker slots remain full-height symbol entries, so this page is
not uniformly "small" in the same way a printable ASCII page is.

Use:

```sh
tools/rom2.py glyphs --sparse-small --first-code 0x00 --count 128
tools/rom2.py glyphs --sparse-small --first-code 0x00 --code 0x3c --code 0x5d
```

## Sparse Small Bold Glyph Set

The sparse-small page has a bold companion at `0x5C2B6`:

```text
0x5C2B6 = 0x5BCB6 + 192 * 8
sparse small bold glyph slot N = 0x5C2B6 + N * 8
```

This page keeps the same sparse/remapped slot ordering. In the first 160 slots,
56 entries are exact byte-for-byte matches against the small-bold font at
`0x592B6`. The remapped alphabet fragments again line up: sparse-small-bold
slots `0x3C..0x43` match small-bold `0x41..0x48`, and slot `0x5D` matches
small-bold `0x62`.

The early line/marker slots remain separate symbol entries and are not uniformly
down-shifted.

Use either spelling:

```sh
tools/rom2.py glyphs --sparse-small-bold --first-code 0x00 --count 128
tools/rom2.py glyphs --sparse-bold-small --first-code 0x00 --code 0x3c --code 0x5d
```

## Glyph Stream Tail

The sparse-small-bold page is the last full `0x600`-byte font page. MAME's
debug layout declares 2331 glyphs from `0x580B6`, which ends at `0x5C98E`:

```text
0x580B6 + 2331 * 8 = 0x5C98E
```

Twelve full 192-slot pages account for 2304 glyphs and end at `0x5C8B6`,
leaving a 27-slot tail:

```text
tail slot N = 0x5C8B6 + N * 8, for N = 0x00..0x1A
```

The tail mostly continues sparse-symbol/marker glyphs. Immediately after it,
at `0x5C98E`, the bytes no longer render as coherent glyph slots and begin
looking like code or packed tables instead.

Inspection commands:

```sh
tools/rom2.py glyphs --base 0x5c8b6 --first-code 0x00 --count 27
tools/rom2.py glyphs --base 0x5c8b6 --first-code 0x00 --count 40
```

## Candidate Width / Metadata Table

The `0xB6` bytes immediately before the glyph table, file `0x58000..0x580B5`,
are small values mostly in the `0x03..0x07` range. This strongly looks like a
width or glyph metadata table for the first 182 glyphs:

```text
0x580B6 - 0x58000 = 0xB6
```

The exact interpretation is not fully confirmed. It may be proportional advance,
renderer metadata, or printer-related width data rather than direct LCD cell
width. Keep it marked as candidate until a text rendering routine is traced.

## Additional Glyph Stream Notes

The MAME debug character layout declares 2331 8-byte glyphs starting at
`0x580B6`, so the visible font/debug range extends far beyond ASCII. Data around
`0x5C000` is still part of that 8-byte glyph stream, but the declared stream
ends at `0x5C98E`:

```text
file 0x5C000: 00 00 B0 C8 88 88 00 00 ...
```

These later glyphs include accented characters, symbols, and line/art forms.

Bitmap and UI resource notes are split out into [`bitmaps.md`](bitmaps.md). The confirmed
48x40 battery/error icons are separate from the 8-byte-per-glyph font stream.
